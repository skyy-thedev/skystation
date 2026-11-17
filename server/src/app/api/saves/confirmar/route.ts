import { z } from "zod";
import { autenticarPerfil } from "@/lib/auth";
import { db } from "@/lib/db";
import { corpo, Erro, json, rota } from "@/lib/http";
import { VERSOES_GUARDADAS } from "@/lib/saves";
import { apagar, tamanhoDe } from "@/lib/storage";

const entrada = z.object({ versaoId: z.string().min(1).max(60) });

/**
 * POST /api/saves/confirmar — passo 2 do envio. Confere se o arquivo chegou inteiro ao
 * armazenamento e só então a versão passa a valer. Um envio interrompido nunca vira o save atual.
 */
export const POST = rota(async (req) => {
  const { perfil } = await autenticarPerfil(req);
  const { versaoId } = await corpo(req, entrada);

  const versao = await db.saveVersao.findFirst({
    where: { id: versaoId, save: { perfilId: perfil.id } },
    include: { save: true },
  });
  if (!versao) throw new Erro(404, "versao_desconhecida", "Envio não encontrado.");
  if (versao.confirmada) return json({ ok: true, versao: versao.numero });

  const tamanho = await tamanhoDe(versao.chave);
  if (tamanho === null) {
    throw new Erro(409, "arquivo_ausente", "O arquivo ainda não chegou ao armazenamento.");
  }
  if (tamanho !== versao.tamanho) {
    await apagar([versao.chave]);
    await db.saveVersao.delete({ where: { id: versao.id } });
    throw new Erro(400, "tamanho_diferente", "O arquivo chegou com tamanho diferente do informado. Envie de novo.");
  }

  await db.$transaction([
    db.saveVersao.update({ where: { id: versao.id }, data: { confirmada: true } }),
    // updateMany com "lt": se uma versão mais nova já foi confirmada, ela continua sendo a atual.
    db.save.updateMany({
      where: { id: versao.saveId, versaoAtual: { lt: versao.numero } },
      data: { versaoAtual: versao.numero, atualizadoEm: new Date() },
    }),
  ]);

  // Guarda só as últimas versões confirmadas.
  const antigas = await db.saveVersao.findMany({
    where: { saveId: versao.saveId, confirmada: true },
    orderBy: { numero: "desc" },
    skip: VERSOES_GUARDADAS,
    select: { id: true, chave: true },
  });
  if (antigas.length) {
    await db.saveVersao.deleteMany({ where: { id: { in: antigas.map((v) => v.id) } } });
    await apagar(antigas.map((v) => v.chave)).catch((e) => console.error("[saves] apagar antigas", e));
  }

  return json({ ok: true, versao: versao.numero });
});
