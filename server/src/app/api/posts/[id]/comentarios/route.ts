import { z } from "zod";
import { db } from "@/lib/db";
import { corpo, Erro, json, rota } from "@/lib/http";
import { podeVer, quemPede } from "@/lib/social";

type Ctx = { params: Promise<{ id: string }> };
const entrada = z.object({ texto: z.string().trim().min(1).max(280) });
const autor = { select: { id: true, apelido: true, avatar: true, usuario: true, cor: true } } as const;

async function post(id: string, quemId: string | null) {
  const p = await db.post.findUnique({ where: { id }, select: { perfilId: true, confirmado: true } });
  if (!p || !p.confirmado || !(await podeVer(p.perfilId, quemId))) {
    throw new Erro(404, "post_desconhecido", "Captura não encontrada.");
  }
  return p;
}

/** GET /api/posts/:id/comentarios — 13.26: os comentários de uma captura (até 100, do mais antigo). */
export const GET = rota<Ctx>(async (req, { params }) => {
  const { id } = await params;
  const quem = await quemPede(req);
  await post(id, quem?.id ?? null);
  const lista = await db.comentario.findMany({
    where: { postId: id },
    orderBy: { criadoEm: "asc" },
    take: 100,
    include: { perfil: autor },
  });
  return json({ comentarios: lista.map((c) => ({ id: c.id, autor: c.perfil, texto: c.texto, criadoEm: c.criadoEm })) });
});

/** POST /api/posts/:id/comentarios — comentar (console ou site; só quem vê a captura). */
export const POST = rota<Ctx>(async (req, { params }) => {
  const { id } = await params;
  const quem = await quemPede(req);
  if (!quem) throw new Erro(401, "sem_sessao", "Entre na sua conta SkyNetwork.");
  await post(id, quem.id);
  const e = await corpo(req, entrada);
  const c = await db.comentario.create({ data: { postId: id, perfilId: quem.id, texto: e.texto }, select: { id: true } });
  return json({ ok: true, id: c.id }, 201);
});
