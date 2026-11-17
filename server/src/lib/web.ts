import type { NextRequest } from "next/server";
import { COOKIE, perfilDaSessao } from "./conta";
import { Erro } from "./http";

/** Perfil logado no site (cookie), ou erro 401. Mudanças exigem vir do próprio site (Origin). */
export async function sessaoWeb(req: NextRequest) {
  if (req.method !== "GET") {
    const origem = req.headers.get("origin");
    if (origem && new URL(origem).host !== req.headers.get("host")) {
      throw new Erro(403, "origem", "Pedido de outro site recusado.");
    }
  }
  const perfil = await perfilDaSessao(req.cookies.get(COOKIE)?.value);
  if (!perfil || !perfil.usuario) throw new Erro(401, "sem_sessao", "Entre na sua conta SkyNetwork.");
  return perfil;
}
