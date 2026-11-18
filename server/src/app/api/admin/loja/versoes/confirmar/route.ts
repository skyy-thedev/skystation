import { NextRequest } from "next/server";
import { z } from "zod";
import { db } from "@/lib/db";
import { corpo, Erro, json, rota } from "@/lib/http";
import { sessaoAdmin, versaoJson } from "@/lib/loja";
import { tamanhoDe } from "@/lib/storage";

const entrada = z.object({ id: z.string().min(1).max(40), publicar: z.boolean().optional() });

/** POST /api/admin/loja/versoes/confirmar — passo 2: o arquivo chegou com o tamanho combinado? */
export const POST = rota(async (req: NextRequest) => {
  await sessaoAdmin(req);
  const e = await corpo(req, entrada);
  const v = await db.lojaVersao.findUnique({ where: { id: e.id } });
  if (!v) throw new Erro(404, "versao_desconhecida", "Versão não encontrada.");
  const tam = await tamanhoDe(v.chave);
  if (tam === null) throw new Erro(409, "sem_arquivo", "O arquivo ainda não chegou ao armazenamento.");
  if (BigInt(tam) !== v.tamanho) throw new Erro(409, "tamanho_diferente", `Chegaram ${tam} bytes, eram ${v.tamanho}.`);
  const nova = await db.lojaVersao.update({
    where: { id: v.id },
    data: { enviada: true, ...(e.publicar ? { publicada: true } : {}) },
  });
  return json({ versao: versaoJson(nova) });
});
