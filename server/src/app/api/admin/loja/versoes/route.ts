import { NextRequest } from "next/server";
import { z } from "zod";
import { db } from "@/lib/db";
import { corpo, Erro, json, rota } from "@/lib/http";
import {
  assinaturaValida, mensagemAssinada, sessaoAdmin, slugSchema, tamanhoMaximoLoja, versaoJson, versaoSchema,
} from "@/lib/loja";
import { apagar, urlEnvio } from "@/lib/storage";

const nova = z.object({
  slug: slugSchema,
  versao: versaoSchema,
  notas: z.string().trim().max(2000).optional(),
  sha256: z.string().regex(/^[0-9a-f]{64}$/),
  tamanho: z.number().int().positive(),
  assinatura: z.string().max(200),
});

/**
 * POST /api/admin/loja/versoes — passo 1 da publicação (o scripts/loja.mjs faz tudo): registra a
 * versão já assinada e devolve o endereço para enviar o arquivo direto ao armazenamento.
 */
export const POST = rota(async (req: NextRequest) => {
  await sessaoAdmin(req);
  const e = await corpo(req, nova);
  if (e.tamanho > tamanhoMaximoLoja()) {
    throw new Erro(413, "pacote_grande", `O pacote passa do limite de ${process.env.SKY_LOJA_MAX_MB || 4096} MB.`);
  }
  if (!assinaturaValida(mensagemAssinada(e.slug, e.versao, e.sha256, e.tamanho), e.assinatura)) {
    throw new Erro(400, "assinatura_invalida", "A assinatura não confere com a chave pública da SkyStore.");
  }
  const item = await db.lojaItem.findUnique({ where: { slug: e.slug } });
  if (!item) throw new Erro(404, "item_desconhecido", "Crie o item antes de enviar uma versão.");
  const existente = await db.lojaVersao.findUnique({ where: { itemId_versao: { itemId: item.id, versao: e.versao } } });
  if (existente?.enviada) throw new Erro(409, "versao_existe", "Essa versão já foi enviada. Use um número novo.");
  if (existente) await db.lojaVersao.delete({ where: { id: existente.id } }); // envio anterior que não terminou
  const v = await db.lojaVersao.create({
    data: {
      itemId: item.id, versao: e.versao, notas: e.notas ?? "", sha256: e.sha256, tamanho: BigInt(e.tamanho),
      assinatura: e.assinatura, chave: "",
    },
  });
  const chave = `loja/${item.slug}/${v.id}`;
  await db.lojaVersao.update({ where: { id: v.id }, data: { chave } });
  return json({ versaoId: v.id, metodo: "PUT", url: await urlEnvio(chave), expiraEmSegundos: 900 }, 201);
});

const mudanca = z.object({ id: z.string().min(1).max(40), publicada: z.boolean() });

/** PATCH /api/admin/loja/versoes — publica ou tira do ar uma versão. */
export const PATCH = rota(async (req: NextRequest) => {
  await sessaoAdmin(req);
  const e = await corpo(req, mudanca);
  const v = await db.lojaVersao.findUnique({ where: { id: e.id } });
  if (!v) throw new Erro(404, "versao_desconhecida", "Versão não encontrada.");
  if (e.publicada && !v.enviada) throw new Erro(409, "nao_enviada", "O arquivo dessa versão ainda não chegou.");
  const nova_ = await db.lojaVersao.update({ where: { id: v.id }, data: { publicada: e.publicada } });
  return json({ versao: versaoJson(nova_) });
});

/** DELETE /api/admin/loja/versoes — apaga uma versão e o arquivo dela. */
export const DELETE = rota(async (req: NextRequest) => {
  await sessaoAdmin(req);
  const { id } = await corpo(req, z.object({ id: z.string().min(1).max(40) }));
  const v = await db.lojaVersao.findUnique({ where: { id } });
  if (!v) throw new Erro(404, "versao_desconhecida", "Versão não encontrada.");
  await db.lojaVersao.delete({ where: { id } });
  await apagar([v.chave]).catch(() => {}); // o arquivo pode nem ter chegado
  return json({ ok: true });
});
