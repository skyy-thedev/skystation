import { randomBytes, scrypt as scryptCb, timingSafeEqual } from "node:crypto";
import { promisify } from "node:util";
import { z } from "zod";
import avataresJson from "./avatares.json";
import { hashToken } from "./auth";
import { db } from "./db";
import { Erro } from "./http";
import { OFFLINE_APOS_MS } from "./rede";

// Contas pessoais da SkyNetwork (Fase 10.5): ID + senha, ícone, bio e visibilidade do perfil.

const scrypt = promisify(scryptCb) as (senha: string, sal: Buffer, tam: number, opts: object) => Promise<Buffer>;
const PARAMS = { N: 16384, r: 8, p: 1, maxmem: 64 * 1024 * 1024 };

export const AVATARES = avataresJson as { id: string; nome: string; cor: string }[];
const IDS_AVATAR = AVATARES.map((a) => a.id) as [string, ...string[]];

export const usuarioSchema = z
  .string()
  .trim()
  .toLowerCase()
  .regex(/^[a-z0-9_]{3,16}$/, "o ID tem de 3 a 16 letras minúsculas, números ou _");
export const senhaSchema = z.string().min(6, "a senha precisa de pelo menos 6 caracteres").max(100);
export const avatarSchema = z.enum(IDS_AVATAR);
export const visibilidadeSchema = z.enum(["publico", "amigos", "privado"]);

/** Campos do perfil que a pessoa pode mudar (pelo site ou pelo console). */
export const edicaoSchema = z.object({
  apelido: z.string().trim().min(1).max(24).optional(),
  avatar: avatarSchema.optional(),
  bio: z.string().trim().max(140).optional(),
  visibilidade: visibilidadeSchema.optional(),
  invisivel: z.boolean().optional(),
});

// IDs que não podem ser usados (rotas do site e nomes que confundem)
const RESERVADOS = new Set(["admin", "api", "conta", "entrar", "sair", "skystation", "skynetwork", "suporte", "u"]);

export async function hashSenha(senha: string) {
  const sal = randomBytes(16);
  const h = await scrypt(senha, sal, 32, PARAMS);
  return `scrypt$${PARAMS.N}$${sal.toString("base64")}$${h.toString("base64")}`;
}

async function senhaConfere(senha: string, guardado: string | null) {
  // sem senha guardada, compara com um hash qualquer: a resposta leva o mesmo tempo
  const [, n, salB64, hB64] = (guardado ?? "scrypt$16384$AAAAAAAAAAAAAAAAAAAAAA==$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=").split("$");
  const esperado = Buffer.from(hB64 ?? "", "base64");
  const h = await scrypt(senha, Buffer.from(salB64 ?? "", "base64"), esperado.length || 32, { ...PARAMS, N: Number(n) || PARAMS.N });
  return guardado !== null && esperado.length === h.length && timingSafeEqual(esperado, h);
}

export async function idDisponivel(usuario: string) {
  if (RESERVADOS.has(usuario)) return false;
  return !(await db.perfil.findUnique({ where: { usuario }, select: { id: true } }));
}

/**
 * Confirma a senha de quem JÁ está logado (para ações sérias, como excluir a conta). Não passa pelo
 * bloqueio de tentativas: quem tem a sessão já provou que é o dono uma vez.
 */
export async function confirmarSenha(perfil: { senhaHash: string | null }, senha: string) {
  if (!(await senhaConfere(senha, perfil.senhaHash))) throw new Erro(401, "senha_errada", "Senha incorreta.");
}

/** Confere ID e senha. 5 erros seguidos bloqueiam a conta por 15 minutos. */
export async function conferirLogin(usuarioBruto: string, senha: string) {
  const usuario = usuarioBruto.trim().toLowerCase();
  const perfil = await db.perfil.findUnique({ where: { usuario } });
  if (perfil?.bloqueadoAte && perfil.bloqueadoAte > new Date()) {
    const min = Math.ceil((perfil.bloqueadoAte.getTime() - Date.now()) / 60000);
    throw new Erro(429, "conta_bloqueada", `Muitas tentativas erradas. Tente de novo em ${min} min.`);
  }
  const ok = await senhaConfere(senha, perfil?.senhaHash ?? null);
  if (!perfil || !ok) {
    if (perfil) {
      const falhas = perfil.falhasLogin + 1;
      await db.perfil.update({
        where: { id: perfil.id },
        data: falhas >= 5
          ? { falhasLogin: 0, bloqueadoAte: new Date(Date.now() + 15 * 60 * 1000) }
          : { falhasLogin: falhas },
      });
    }
    throw new Erro(401, "login_invalido", "ID ou senha incorretos.");
  }
  if (perfil.falhasLogin || perfil.bloqueadoAte) {
    await db.perfil.update({ where: { id: perfil.id }, data: { falhasLogin: 0, bloqueadoAte: null } });
  }
  return perfil;
}

// ---------------------------------------------------------------- sessões do site

export const COOKIE = "sky_sessao";
const DURACAO_MS = 30 * 24 * 60 * 60 * 1000;

export async function criarSessao(perfilId: string) {
  const token = randomBytes(32).toString("base64url");
  const expira = new Date(Date.now() + DURACAO_MS);
  await db.sessao.create({ data: { perfilId, tokenHash: hashToken(token), expira } });
  return { token, expira };
}

export function opcoesCookie(expira: Date) {
  return {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax" as const,
    path: "/",
    expires: expira,
  };
}

/** O perfil da sessão do site (pelo valor do cookie), ou null. */
export async function perfilDaSessao(token: string | undefined | null) {
  if (!token) return null;
  const s = await db.sessao.findUnique({ where: { tokenHash: hashToken(token) }, include: { perfil: true } });
  if (!s || s.expira < new Date()) return null;
  return s.perfil;
}

export async function encerrarSessao(token: string | undefined | null) {
  if (token) await db.sessao.deleteMany({ where: { tokenHash: hashToken(token) } });
}

// ---------------------------------------------------------------- perfil no site

type PerfilBase = {
  id: string;
  usuario: string | null;
  apelido: string;
  avatar: string;
  bio: string;
  visibilidade: string;
  invisivel: boolean;
  criadoEm: Date;
};

async function saoAmigos(x: string, y: string) {
  const a = await db.amizade.findFirst({
    where: { status: "aceita", OR: [{ aId: x, bId: y }, { aId: y, bId: x }] },
    select: { id: true },
  });
  return Boolean(a);
}

/**
 * O que `quemVe` (perfil logado no site, ou null) pode ver do perfil com este ID.
 * publico: todos veem tudo | amigos: só amigos veem os detalhes | privado: só o dono.
 * "Invisível" esconde o que está jogando agora para todos menos o dono.
 */
export async function perfilVisto(usuario: string, quemVe: { id: string } | null) {
  const p = await db.perfil.findUnique({
    where: { usuario: usuario.toLowerCase() },
    select: {
      id: true, usuario: true, apelido: true, avatar: true, bio: true, visibilidade: true, invisivel: true,
      criadoEm: true, presenca: true,
    },
  });
  if (!p) return null;
  const dono = quemVe?.id === p.id;
  const amigo = !dono && quemVe ? await saoAmigos(quemVe.id, p.id) : false;
  const completo = dono || p.visibilidade === "publico" || (p.visibilidade === "amigos" && amigo);
  const base = { usuario: p.usuario, apelido: p.apelido, avatar: p.avatar, dono, amigo, visibilidade: p.visibilidade };
  if (!completo) {
    return { ...base, completo: false as const };
  }

  const pr = p.presenca;
  const online = pr && Date.now() - pr.vistoEm.getTime() <= OFFLINE_APOS_MS && (dono || !p.invisivel);
  const [trofeus, amizades] = await Promise.all([
    db.trofeuGanho.findMany({
      where: { perfilId: p.id },
      orderBy: { ganhoEm: "desc" },
      select: { jogo: true, jogoId: true, nome: true, trofeu: true, tipo: true, ganhoEm: true },
    }),
    db.amizade.findMany({
      where: { status: "aceita", OR: [{ aId: p.id }, { bId: p.id }] },
      include: { a: { select: { id: true, usuario: true, apelido: true, avatar: true } },
                 b: { select: { id: true, usuario: true, apelido: true, avatar: true } } },
    }),
  ]);
  const contagem = { bronze: 0, prata: 0, ouro: 0, platina: 0 } as Record<string, number>;
  for (const t of trofeus) contagem[t.tipo] = (contagem[t.tipo] ?? 0) + 1;
  return {
    ...base,
    completo: true as const,
    bio: p.bio,
    membroDesde: p.criadoEm,
    status: online ? pr!.status : "offline",
    jogo: online && pr!.status === "jogando" ? pr!.jogo : null,
    sistema: online && pr!.status === "jogando" ? pr!.sistema : null,
    invisivel: dono ? p.invisivel : undefined,
    trofeus: { total: trofeus.length, porTipo: contagem, recentes: trofeus.slice(0, 12) },
    amigos: amizades.map((a) => {
      const o = a.aId === p.id ? a.b : a.a;
      return { usuario: o.usuario, apelido: o.apelido, avatar: o.avatar };
    }),
  };
}

export type PerfilVisto = NonNullable<Awaited<ReturnType<typeof perfilVisto>>>;
export type { PerfilBase };
