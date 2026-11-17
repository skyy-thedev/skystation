import { NextRequest } from "next/server";
import { z } from "zod";
import { COOKIE, conferirLogin, hashSenha, senhaSchema } from "@/lib/conta";
import { db } from "@/lib/db";
import { hashToken } from "@/lib/auth";
import { corpo, json, rota } from "@/lib/http";
import { sessaoWeb } from "@/lib/web";

/** POST /api/web/senha — troca a senha (pede a atual). Encerra as outras sessões do site. */
export const POST = rota(async (req: NextRequest) => {
  const p = await sessaoWeb(req);
  const { atual, nova } = await corpo(req, z.object({ atual: z.string().min(1).max(100), nova: senhaSchema }));
  await conferirLogin(p.usuario!, atual);
  const minha = hashToken(req.cookies.get(COOKIE)?.value ?? "");
  await db.$transaction([
    db.perfil.update({ where: { id: p.id }, data: { senhaHash: await hashSenha(nova) } }),
    db.sessao.deleteMany({ where: { perfilId: p.id, NOT: { tokenHash: minha } } }),
  ]);
  return json({ ok: true });
});
