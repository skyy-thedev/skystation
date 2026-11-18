import { z } from "zod";
import { autenticar } from "@/lib/auth";
import { db } from "@/lib/db";
import { corpo, Erro, json, rota } from "@/lib/http";
import { ultimaPublicada, versaoJson, versaoSchema } from "@/lib/loja";
import { urlDownload } from "@/lib/storage";

type Ctx = { params: Promise<{ slug: string }> };
const entrada = z.object({ versao: versaoSchema.optional() });

/**
 * POST /api/loja/:slug/baixar — só consoles registrados. Devolve o endereço temporário do pacote,
 * o sha256 e a assinatura: o console baixa, confere os dois e só então instala.
 */
export const POST = rota<Ctx>(async (req, { params }) => {
  await autenticar(req);
  const { slug } = await params;
  const e = await corpo(req, entrada);
  const item = await db.lojaItem.findUnique({
    where: { slug },
    include: { versoes: { where: { publicada: true, enviada: true } } },
  });
  if (!item || !item.publicado) throw new Erro(404, "item_desconhecido", "Item não encontrado na SkyStore.");
  const v = e.versao ? item.versoes.find((x) => x.versao === e.versao) : ultimaPublicada(item.versoes);
  if (!v) throw new Erro(404, "versao_desconhecida", "Essa versão não está disponível.");
  await db.lojaItem.update({ where: { id: item.id }, data: { downloads: { increment: 1 } } });
  return json({
    slug: item.slug,
    tipo: item.tipo,
    nome: item.nome,
    ...versaoJson(v),
    url: await urlDownload(v.chave),
  });
});
