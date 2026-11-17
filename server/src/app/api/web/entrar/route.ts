import { NextRequest } from "next/server";
import { z } from "zod";
import { COOKIE, conferirLogin, criarSessao, opcoesCookie } from "@/lib/conta";
import { corpo, json, rota } from "@/lib/http";

/** POST /api/web/entrar — login no site com ID SkyNetwork + senha. */
export const POST = rota(async (req: NextRequest) => {
  const { usuario, senha } = await corpo(req, z.object({ usuario: z.string().min(1).max(40), senha: z.string().min(1).max(100) }));
  const perfil = await conferirLogin(usuario, senha);
  const { token, expira } = await criarSessao(perfil.id);
  const r = json({ ok: true, usuario: perfil.usuario });
  r.cookies.set(COOKIE, token, opcoesCookie(expira));
  return r;
});
