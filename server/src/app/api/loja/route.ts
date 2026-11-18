import { db } from "@/lib/db";
import { json, rota } from "@/lib/http";
import { ultimaPublicada, versaoJson } from "@/lib/loja";

/** GET /api/loja — a vitrine da SkyStore: itens publicados que têm uma versão pronta para baixar. */
export const GET = rota(async () => {
  const itens = await db.lojaItem.findMany({
    where: { publicado: true },
    include: { versoes: { where: { publicada: true, enviada: true } } },
    orderBy: [{ oficial: "desc" }, { atualizadoEm: "desc" }],
  });
  return json({
    itens: itens
      .map((i) => {
        const v = ultimaPublicada(i.versoes);
        if (!v) return null;
        const { versoes: _v, ...item } = i;
        return { ...item, versao: versaoJson(v) };
      })
      .filter(Boolean),
  });
});
