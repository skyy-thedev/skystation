import { z } from "zod";
import { db } from "./db";
import { Erro } from "./http";

/** Sem sinal há mais que isto = offline. O console manda sinal a cada 30 s. */
export const OFFLINE_APOS_MS = 90_000;

export const sistemaSchema = z.string().regex(/^[a-z0-9]{1,12}$/, "sistema inválido (ex.: ps2, x360)");

export const presencaSchema = z.object({
  status: z.enum(["online", "jogando", "ausente"]),
  jogoId: z.string().max(200).nullish(),
  jogo: z.string().max(200).nullish(),
  sistema: sistemaSchema.nullish(),
});
export type PresencaEntrada = z.infer<typeof presencaSchema>;

/** Grava "estou aqui". O campo `desde` só muda quando o status ou o jogo mudam. */
export async function gravarPresenca(perfilId: string, p: PresencaEntrada) {
  const agora = new Date();
  const jogando = p.status === "jogando";
  const novo = {
    status: p.status,
    jogoId: jogando ? (p.jogoId ?? null) : null,
    jogo: jogando ? (p.jogo ?? null) : null,
    sistema: jogando ? (p.sistema ?? null) : null,
  };
  const atual = await db.presenca.findUnique({ where: { perfilId } });
  const mudou =
    !atual ||
    atual.status !== novo.status ||
    atual.jogoId !== novo.jogoId ||
    agora.getTime() - atual.vistoEm.getTime() > OFFLINE_APOS_MS; // voltou depois de ficar offline
  await db.presenca.upsert({
    where: { perfilId },
    create: { perfilId, ...novo, desde: agora, vistoEm: agora },
    update: { ...novo, vistoEm: agora, ...(mudou ? { desde: agora } : {}) },
  });
}

type PerfilComPresenca = {
  id: string;
  apelido: string;
  cor: string;
  avatar: string;
  usuario: string | null;
  invisivel: boolean;
  presenca: {
    status: string;
    jogoId: string | null;
    jogo: string | null;
    sistema: string | null;
    desde: Date;
    vistoEm: Date;
  } | null;
};

/** O que um amigo pode ver de um perfil. Invisível aparece como offline, sem jogo. */
export function vistoPorAmigos(p: PerfilComPresenca, agora = new Date()) {
  const base = { id: p.id, apelido: p.apelido, cor: p.cor, avatar: p.avatar, usuario: p.usuario };
  const pr = p.presenca;
  const offline = p.invisivel || !pr || agora.getTime() - pr.vistoEm.getTime() > OFFLINE_APOS_MS;
  if (offline) {
    return {
      ...base,
      status: "offline" as const,
      jogoId: null,
      jogo: null,
      sistema: null,
      desde: null,
      vistoEm: p.invisivel ? null : (pr?.vistoEm ?? null),
    };
  }
  return {
    ...base,
    status: pr.status,
    jogoId: pr.jogoId,
    jogo: pr.jogo,
    sistema: pr.sistema,
    desde: pr.desde,
    vistoEm: pr.vistoEm,
  };
}

/** A amizade (em qualquer direção) entre dois perfis, ou null. */
export function amizadeEntre(x: string, y: string) {
  return db.amizade.findFirst({
    where: { OR: [{ aId: x, bId: y }, { aId: y, bId: x }] },
  });
}

export async function exigirAmizade(eu: string, outro: string) {
  const a = await amizadeEntre(eu, outro);
  if (!a || a.status !== "aceita") {
    throw new Erro(403, "nao_e_amigo", "Vocês ainda não são amigos na SkyNetwork.");
  }
  return a;
}

/** Ids dos amigos aceitos de um perfil. */
export async function idsDosAmigos(perfilId: string) {
  const lista = await db.amizade.findMany({
    where: { status: "aceita", OR: [{ aId: perfilId }, { bId: perfilId }] },
    select: { aId: true, bId: true },
  });
  return lista.map((a) => (a.aId === perfilId ? a.bId : a.aId));
}
