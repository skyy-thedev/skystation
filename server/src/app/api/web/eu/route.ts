import { NextRequest } from "next/server";
import { z } from "zod";
import { COOKIE, confirmarSenha, edicaoSchema } from "@/lib/conta";
import { minhaConta } from "@/lib/conta-web";
import { db } from "@/lib/db";
import { corpo, json, rota } from "@/lib/http";
import { apagar } from "@/lib/storage";
import { sessaoWeb } from "@/lib/web";

/** GET /api/web/eu — a conta logada no site, com amigos e pedidos. */
export const GET = rota(async (req: NextRequest) => {
  const p = await sessaoWeb(req);
  return json(await minhaConta(p.id));
});

/** PATCH /api/web/eu — muda apelido, ícone, bio, visibilidade, invisível. */
export const PATCH = rota(async (req: NextRequest) => {
  const p = await sessaoWeb(req);
  await db.perfil.update({ where: { id: p.id }, data: await corpo(req, edicaoSchema) });
  return json(await minhaConta(p.id));
});

/**
 * DELETE /api/web/eu — exclui a conta (pede a senha): perfil, amizades, mensagens, troféus e saves
 * na nuvem. Os saves que estão nos consoles continuam lá.
 */
export const DELETE = rota(async (req: NextRequest) => {
  const p = await sessaoWeb(req);
  const { senha } = await corpo(req, z.object({ senha: z.string().min(1).max(100) }));
  await confirmarSenha(p, senha);
  const versoes = await db.saveVersao.findMany({ where: { save: { perfilId: p.id } }, select: { chave: true } });
  await db.perfil.delete({ where: { id: p.id } });
  if (process.env.S3_ENDPOINT) {
    await apagar(versoes.map((v) => v.chave).filter(Boolean)).catch((e) => console.error("[conta] apagar saves", e));
  }
  const r = json({ ok: true });
  r.cookies.delete(COOKIE);
  return r;
});
