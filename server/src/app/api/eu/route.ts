import { autenticar, perfisDoConsole } from "@/lib/auth";
import { db } from "@/lib/db";
import { json, rota } from "@/lib/http";
import { apagar } from "@/lib/storage";

/** GET /api/eu — confere o token e lista os perfis deste console. */
export const GET = rota(async (req) => {
  const console_ = await autenticar(req);
  return json({ console: console_, perfis: await perfisDoConsole(console_.id) });
});

/**
 * DELETE /api/eu — remove este console da rede. Perfis SEM conta vão junto (com amizades, mensagens
 * e saves); contas pessoais continuam existindo (entram de novo em outro console com ID e senha).
 */
export const DELETE = rota(async (req) => {
  const console_ = await autenticar(req);
  const semConta = { consoleId: console_.id, usuario: null };
  const versoes = await db.saveVersao.findMany({
    where: { save: { perfil: semConta } },
    select: { chave: true },
  });
  await db.perfil.deleteMany({ where: semConta });
  await db.console.delete({ where: { id: console_.id } });
  // Os arquivos vão por último e uma falha aqui não derruba a resposta: sem o registro no
  // banco, ninguém mais consegue um endereço para baixá-los.
  await apagar(versoes.map((v) => v.chave)).catch(() => {});
  return json({ ok: true });
});
