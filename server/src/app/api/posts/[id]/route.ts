import { autenticarPerfil } from "@/lib/auth";
import { db } from "@/lib/db";
import { Erro, json, rota } from "@/lib/http";
import { apagar } from "@/lib/storage";

type Ctx = { params: Promise<{ id: string }> };

/** DELETE /api/posts/:id — 13.26: apaga uma captura publicada (só o dono). */
export const DELETE = rota<Ctx>(async (req, { params }) => {
  const { perfil } = await autenticarPerfil(req);
  const { id } = await params;
  const p = await db.post.findUnique({ where: { id }, select: { perfilId: true, chave: true } });
  if (!p || p.perfilId !== perfil.id) throw new Erro(404, "post_desconhecido", "Captura não encontrada.");
  await db.post.delete({ where: { id } });
  await apagar([p.chave]).catch(() => undefined);   // sem o arquivo, o post já sumiu de qualquer jeito
  return json({ ok: true });
});
