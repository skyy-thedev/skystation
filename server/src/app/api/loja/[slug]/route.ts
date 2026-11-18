import { db } from "@/lib/db";
import { Erro, json, rota } from "@/lib/http";
import { compararVersoes, versaoJson } from "@/lib/loja";

type Ctx = { params: Promise<{ slug: string }> };

/** GET /api/loja/:slug — um item da SkyStore com o histórico de versões publicadas. */
export const GET = rota<Ctx>(async (_req, { params }) => {
  const { slug } = await params;
  const item = await db.lojaItem.findUnique({
    where: { slug },
    include: { versoes: { where: { publicada: true, enviada: true } } },
  });
  if (!item || !item.publicado || !item.versoes.length) throw new Erro(404, "item_desconhecido", "Item não encontrado na SkyStore.");
  const { versoes, ...resto } = item;
  return json({
    item: resto,
    versoes: versoes.sort((a, b) => compararVersoes(b.versao, a.versao)).map(versaoJson),
  });
});
