import { autenticar } from "@/lib/auth";
import { db } from "@/lib/db";
import { json, rota } from "@/lib/http";
import { apagar } from "@/lib/storage";

const campos = { id: true, localId: true, apelido: true, cor: true, invisivel: true, codigo: true } as const;

/** GET /api/eu — confere o token e lista os perfis deste console. */
export const GET = rota(async (req) => {
  const console_ = await autenticar(req);
  const perfis = await db.perfil.findMany({
    where: { consoleId: console_.id },
    orderBy: { localId: "asc" },
    select: campos,
  });
  return json({ console: console_, perfis });
});

/** DELETE /api/eu — remove este console da rede, com perfis, amizades, mensagens e saves. */
export const DELETE = rota(async (req) => {
  const console_ = await autenticar(req);
  const versoes = await db.saveVersao.findMany({
    where: { save: { perfil: { consoleId: console_.id } } },
    select: { chave: true },
  });
  await db.console.delete({ where: { id: console_.id } });
  // Os arquivos vão por último e uma falha aqui não derruba a resposta: sem o registro no
  // banco, ninguém mais consegue um endereço para baixá-los.
  await apagar(versoes.map((v) => v.chave)).catch(() => {});
  return json({ ok: true });
});
