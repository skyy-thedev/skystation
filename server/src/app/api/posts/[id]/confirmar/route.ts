import { autenticarPerfil } from "@/lib/auth";
import { db } from "@/lib/db";
import { Erro, json, rota } from "@/lib/http";
import { tamanhoDe } from "@/lib/storage";

type Ctx = { params: Promise<{ id: string }> };

/** POST /api/posts/:id/confirmar — 13.26: a imagem chegou? Então a captura aparece para os amigos. */
export const POST = rota<Ctx>(async (req, { params }) => {
  const { perfil } = await autenticarPerfil(req);
  const { id } = await params;
  const p = await db.post.findUnique({ where: { id }, select: { perfilId: true, chave: true, tamanho: true } });
  if (!p || p.perfilId !== perfil.id) throw new Erro(404, "post_desconhecido", "Captura não encontrada.");
  const tam = await tamanhoDe(p.chave);
  if (tam === null) throw new Erro(409, "sem_arquivo", "A imagem ainda não chegou ao armazenamento.");
  if (tam !== p.tamanho) throw new Erro(409, "tamanho_diferente", "A imagem chegou incompleta: tente de novo.");
  await db.post.update({ where: { id }, data: { confirmado: true } });
  return json({ ok: true });
});
