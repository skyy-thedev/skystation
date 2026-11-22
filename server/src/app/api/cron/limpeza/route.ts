import type { NextRequest } from "next/server";
import { igual } from "@/lib/auth";
import { db } from "@/lib/db";
import { Erro, json, rota } from "@/lib/http";
import { apagar } from "@/lib/storage";

const DIA = 24 * 60 * 60 * 1000;

/**
 * GET /api/cron/limpeza — roda 1x por dia (vercel.json). Apaga mensagens com mais de 90 dias e
 * envios de save que começaram e nunca terminaram.
 */
export const GET = rota(async (req: NextRequest) => {
  const segredo = process.env.CRON_SECRET;
  const recebido = (req.headers.get("authorization") ?? "").replace(/^Bearer /, "");
  if (!segredo || !igual(recebido, segredo)) throw new Erro(401, "nao_autorizado", "Não autorizado.");

  const agora = Date.now();
  const mensagens = await db.mensagem.deleteMany({
    where: { enviadaEm: { lt: new Date(agora - 90 * DIA) } },
  });

  const sessoes = await db.sessao.deleteMany({ where: { expira: { lt: new Date(agora) } } });

  const pendentes = await db.saveVersao.findMany({
    where: { confirmada: false, criadaEm: { lt: new Date(agora - DIA) } },
    select: { id: true, chave: true },
    take: 500,
  });
  let arquivos = 0;
  if (pendentes.length) {
    const chaves = pendentes.map((v) => v.chave).filter(Boolean);
    if (process.env.S3_ENDPOINT) {
      await apagar(chaves);
      arquivos = chaves.length;
    }
    await db.saveVersao.deleteMany({ where: { id: { in: pendentes.map((v) => v.id) } } });
  }

  // 13.26: capturas que começaram a ser publicadas e nunca chegaram
  const postsPendentes = await db.post.findMany({
    where: { confirmado: false, criadoEm: { lt: new Date(agora - DIA) } },
    select: { id: true, chave: true },
    take: 500,
  });
  if (postsPendentes.length) {
    if (process.env.S3_ENDPOINT) await apagar(postsPendentes.map((p) => p.chave));
    await db.post.deleteMany({ where: { id: { in: postsPendentes.map((p) => p.id) } } });
  }

  return json({ ok: true, postsPendentesApagados: postsPendentes.length, mensagensApagadas: mensagens.count, sessoesVencidas: sessoes.count, enviosPendentesApagados: pendentes.length, arquivos });
});
