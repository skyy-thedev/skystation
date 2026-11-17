import { NextRequest } from "next/server";
import { COOKIE, perfilDaSessao, perfilVisto } from "@/lib/conta";
import { Erro, json, rota } from "@/lib/http";

type Ctx = { params: Promise<{ usuario: string }> };

/** GET /api/web/perfil/:usuario — o perfil como quem pede pode vê-lo (público, só amigos ou privado). */
export const GET = rota<Ctx>(async (req: NextRequest, { params }) => {
  const { usuario } = await params;
  const quem = await perfilDaSessao(req.cookies.get(COOKIE)?.value);
  const p = await perfilVisto(usuario, quem);
  if (!p) throw new Erro(404, "nao_encontrado", "Perfil não encontrado.");
  return json(p);
});
