import { NextRequest } from "next/server";
import { z } from "zod";
import { db } from "@/lib/db";
import { corpo, Erro, json, rota } from "@/lib/http";
import { compararVersoes, sessaoAdmin, slugSchema, TIPOS, versaoJson } from "@/lib/loja";
import { apagar } from "@/lib/storage";

/** GET /api/admin/loja — todos os itens (publicados ou não) com todas as versões. */
export const GET = rota(async (req: NextRequest) => {
  await sessaoAdmin(req);
  const itens = await db.lojaItem.findMany({ include: { versoes: true }, orderBy: { criadoEm: "desc" } });
  return json({
    itens: itens.map(({ versoes, ...i }) => ({
      ...i,
      versoes: versoes.sort((a, b) => compararVersoes(b.versao, a.versao)).map(versaoJson),
    })),
  });
});

const entrada = z.object({
  slug: slugSchema,
  tipo: z.enum(TIPOS),
  nome: z.string().trim().min(1).max(80),
  resumo: z.string().trim().max(160).optional(),
  descricao: z.string().trim().max(4000).optional(),
  autor: z.string().trim().min(1).max(80).optional(),
  oficial: z.boolean().optional(),
  capa: z.union([z.url({ protocol: /^https$/ }).max(500), z.literal("")]).optional(),
  publicado: z.boolean().optional(),
});

/** POST /api/admin/loja — cria ou atualiza um item (pelo slug). */
export const POST = rota(async (req: NextRequest) => {
  await sessaoAdmin(req);
  const { slug, capa, ...e } = await corpo(req, entrada);
  const dados = { ...e, ...(capa !== undefined ? { capa: capa || null } : {}) };
  const item = await db.lojaItem.upsert({ where: { slug }, create: { slug, ...dados }, update: dados });
  return json({ item });
});

/** DELETE /api/admin/loja — apaga o item, todas as versões e os arquivos delas. */
export const DELETE = rota(async (req: NextRequest) => {
  await sessaoAdmin(req);
  const { slug } = await corpo(req, z.object({ slug: slugSchema }));
  const item = await db.lojaItem.findUnique({ where: { slug }, include: { versoes: { select: { chave: true } } } });
  if (!item) throw new Erro(404, "item_desconhecido", "Item não encontrado.");
  await db.lojaItem.delete({ where: { id: item.id } });
  await apagar(item.versoes.map((v) => v.chave)).catch(() => {});
  return json({ ok: true });
});
