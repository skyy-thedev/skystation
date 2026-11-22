import { NextResponse } from "next/server";
import { db } from "@/lib/db";
import { Erro, rota } from "@/lib/http";
import { podeVer, quemPede } from "@/lib/social";
import { urlDownload } from "@/lib/storage";

type Ctx = { params: Promise<{ id: string }> };

/**
 * GET /api/posts/:id/imagem — 13.26: a imagem de uma captura (para o site: <img src>). Confere quem pode ver
 * e redireciona para um endereço temporário do armazenamento; a imagem não passa pelo servidor.
 */
export const GET = rota<Ctx>(async (req, { params }) => {
  const { id } = await params;
  const p = await db.post.findUnique({ where: { id }, select: { perfilId: true, chave: true, confirmado: true } });
  if (!p || !p.confirmado) throw new Erro(404, "post_desconhecido", "Captura não encontrada.");
  const quem = await quemPede(req);
  if (!(await podeVer(p.perfilId, quem?.id ?? null))) throw new Erro(403, "privado", "Captura visível só para amigos.");
  return NextResponse.redirect(await urlDownload(p.chave), { status: 302, headers: { "Cache-Control": "private, max-age=240" } });
});
