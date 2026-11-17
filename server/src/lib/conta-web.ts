import { db } from "./db";

const publico = { id: true, usuario: true, apelido: true, avatar: true } as const;

/** A conta logada no site, com amigos e pedidos (página Conta e GET /api/web/eu). */
export async function minhaConta(id: string) {
  const [eu, amizades] = await Promise.all([
    db.perfil.findUniqueOrThrow({
      where: { id },
      select: { id: true, usuario: true, apelido: true, avatar: true, bio: true, visibilidade: true, invisivel: true, codigo: true },
    }),
    db.amizade.findMany({
      where: { OR: [{ aId: id }, { bId: id }] },
      include: { a: { select: publico }, b: { select: publico } },
      orderBy: { criadaEm: "asc" },
    }),
  ]);
  return {
    eu,
    amigos: amizades.filter((a) => a.status === "aceita").map((a) => ({ amizadeId: a.id, ...(a.aId === id ? a.b : a.a) })),
    pedidos: amizades.filter((a) => a.status === "pendente" && a.bId === id).map((a) => ({ amizadeId: a.id, ...a.a })),
    enviados: amizades.filter((a) => a.status === "pendente" && a.aId === id).map((a) => ({ amizadeId: a.id, ...a.b })),
  };
}
