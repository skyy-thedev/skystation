import { db } from "@/lib/db";
import { Erro, json, rota } from "@/lib/http";
import { podeVer, quemPede } from "@/lib/social";

type Ctx = { params: Promise<{ id: string }> };

async function preparar(req: Parameters<typeof quemPede>[0], id: string) {
  const quem = await quemPede(req);
  if (!quem) throw new Erro(401, "sem_sessao", "Entre na sua conta SkyNetwork.");
  const p = await db.post.findUnique({ where: { id }, select: { perfilId: true, confirmado: true } });
  if (!p || !p.confirmado || !(await podeVer(p.perfilId, quem.id))) {
    throw new Erro(404, "post_desconhecido", "Captura não encontrada.");
  }
  return quem;
}

/** POST /api/posts/:id/curtir — 13.26: curtir (console ou site). DELETE desfaz. */
export const POST = rota<Ctx>(async (req, { params }) => {
  const { id } = await params;
  const quem = await preparar(req, id);
  await db.curtida.upsert({
    where: { postId_perfilId: { postId: id, perfilId: quem.id } },
    create: { postId: id, perfilId: quem.id },
    update: {},
  });
  return json({ ok: true, curtidas: await db.curtida.count({ where: { postId: id } }) });
});

export const DELETE = rota<Ctx>(async (req, { params }) => {
  const { id } = await params;
  const quem = await preparar(req, id);
  await db.curtida.deleteMany({ where: { postId: id, perfilId: quem.id } });
  return json({ ok: true, curtidas: await db.curtida.count({ where: { postId: id } }) });
});
