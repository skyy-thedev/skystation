import { NextRequest } from "next/server";
import { json, rota } from "@/lib/http";

/**
 * GET /api/rede/ip — devolve o IP público de quem perguntou (como a internet enxerga o console).
 * O coop online do DEADZONE manda esse endereço no convite, junto com os da rede local e IPv6:
 * o amigo tenta todos e fica com o primeiro que responder. Sem login: não revela nada além do
 * próprio endereço de quem pergunta.
 */
export const GET = rota(async (req: NextRequest) => {
  const encaminhado = req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? "";
  const ip = encaminhado || req.headers.get("x-real-ip")?.trim() || "";
  return json({ ip: /^[A-Fa-f0-9.:]{3,64}$/.test(ip) ? ip : "" });
});
