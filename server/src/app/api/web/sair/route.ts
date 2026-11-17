import { NextRequest } from "next/server";
import { COOKIE, encerrarSessao } from "@/lib/conta";
import { json, rota } from "@/lib/http";

/** POST /api/web/sair — encerra a sessão do site. */
export const POST = rota(async (req: NextRequest) => {
  await encerrarSessao(req.cookies.get(COOKIE)?.value);
  const r = json({ ok: true });
  r.cookies.delete(COOKIE);
  return r;
});
