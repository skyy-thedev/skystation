import type { NextRequest } from "next/server";
import { autenticarPerfil } from "./auth";
import { COOKIE, perfilDaSessao } from "./conta";
import { db } from "./db";
import { Erro } from "./http";
import { urlDownload } from "./storage";

// 13.26: social da SkyNetwork — atividade dos amigos, capturas publicadas (posts), curtidas e comentários.
// Quem vê um post: o dono, os amigos e, se o perfil do dono for público, qualquer um (inclusive no site).

export const POSTS_POR_DIA = 30;
export const POST_MAX_BYTES = 8 * 1024 * 1024;

const autorSelect = { id: true, apelido: true, avatar: true, usuario: true, cor: true } as const;

/** Quem está pedindo: um console (Authorization + X-Perfil) ou alguém logado no site (cookie). null = ninguém. */
export async function quemPede(req: NextRequest) {
  if (req.headers.get("authorization")) {
    const { perfil } = await autenticarPerfil(req);
    return perfil;
  }
  if (req.method !== "GET") {   // pelo site, mudanças só vindas do próprio site (como em sessaoWeb)
    const origem = req.headers.get("origin");
    if (origem && new URL(origem).host !== req.headers.get("host")) {
      throw new Erro(403, "origem", "Pedido de outro site recusado.");
    }
  }
  return perfilDaSessao(req.cookies.get(COOKIE)?.value);
}

export async function idsAmigos(perfilId: string) {
  const amizades = await db.amizade.findMany({
    where: { status: "aceita", OR: [{ aId: perfilId }, { bId: perfilId }] },
    select: { aId: true, bId: true },
  });
  return amizades.map((a) => (a.aId === perfilId ? a.bId : a.aId));
}

/** O que `quemVe` pode ver do perfil `donoId`: tudo (dono, amigo ou perfil público) ou nada. */
export async function podeVer(donoId: string, quemVeId: string | null) {
  if (quemVeId === donoId) return true;
  const dono = await db.perfil.findUnique({ where: { id: donoId }, select: { visibilidade: true } });
  if (!dono) return false;
  if (dono.visibilidade === "publico") return true;
  if (!quemVeId || dono.visibilidade === "privado") return false;
  const amizade = await db.amizade.findFirst({
    where: { status: "aceita", OR: [{ aId: donoId, bId: quemVeId }, { aId: quemVeId, bId: donoId }] },
    select: { id: true },
  });
  return Boolean(amizade);
}

type PostDb = {
  id: string; legenda: string; jogoId: string | null; jogo: string | null; sistema: string | null; chave: string;
  criadoEm: Date; perfil: { id: string; apelido: string; avatar: string; usuario: string | null; cor: string };
  _count: { curtidas: number; comentarios: number };
};

export const postInclude = {
  perfil: { select: autorSelect },
  _count: { select: { curtidas: true, comentarios: true } },
} as const;

/** Monta os posts para a resposta. `comUrl`: endereço temporário da imagem (o console baixa direto do R2). */
export async function postsParaCliente(posts: PostDb[], quemVeId: string | null, comUrl = false) {
  const ids = posts.map((p) => p.id);
  const [minhas, comentarios] = await Promise.all([
    quemVeId && ids.length
      ? db.curtida.findMany({ where: { perfilId: quemVeId, postId: { in: ids } }, select: { postId: true } })
      : [],
    ids.length
      ? db.comentario.findMany({
          where: { postId: { in: ids } },
          orderBy: { criadoEm: "desc" },
          take: ids.length * 3,
          include: { perfil: { select: autorSelect } },
        })
      : [],
  ]);
  const curti = new Set(minhas.map((c) => c.postId));
  return Promise.all(
    posts.map(async (p) => ({
      id: p.id,
      autor: p.perfil,
      legenda: p.legenda,
      jogoId: p.jogoId,
      jogo: p.jogo,
      sistema: p.sistema,
      criadoEm: p.criadoEm,
      curtidas: p._count.curtidas,
      comentarios: p._count.comentarios,
      curti: curti.has(p.id),
      ultimosComentarios: comentarios
        .filter((c) => c.postId === p.id)
        .slice(0, 2)
        .reverse()
        .map((c) => ({ id: c.id, autor: c.perfil, texto: c.texto, criadoEm: c.criadoEm })),
      imagem: `/api/posts/${p.id}/imagem`,
      ...(comUrl ? { url: await urlDownload(p.chave) } : {}),
    })),
  );
}

/** Perfil "por dentro": jogos jogados, troféus e capturas (página do amigo no console e perfil no site). */
export async function atividadeDoPerfil(perfilId: string, quemVeId: string | null, comUrl = false) {
  const [jogos, trofeus, posts] = await Promise.all([
    db.jogoJogado.findMany({
      where: { perfilId },
      orderBy: { ultimaVez: "desc" },
      take: 40,
      select: { jogoId: true, titulo: true, sistema: true, segundos: true, partidas: true, ultimaVez: true },
    }),
    db.trofeuGanho.findMany({
      where: { perfilId },
      orderBy: { ganhoEm: "desc" },
      select: { jogoId: true, jogo: true, trofeu: true, nome: true, tipo: true, ganhoEm: true },
    }),
    db.post.findMany({
      where: { perfilId, confirmado: true },
      orderBy: { criadoEm: "desc" },
      take: 24,
      include: postInclude,
    }),
  ]);
  return { jogos, trofeus, posts: await postsParaCliente(posts, quemVeId, comUrl) };
}
