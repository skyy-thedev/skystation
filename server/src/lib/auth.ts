import { createHash, randomBytes, timingSafeEqual } from "node:crypto";
import type { NextRequest } from "next/server";
import { db } from "./db";
import { Erro } from "./http";

/** Requisições por minuto que um console pode fazer (o uso normal é 2 a 4). */
const LIMITE_POR_MINUTO = 120;

export function novoToken() {
  return "sky_" + randomBytes(32).toString("base64url");
}

export function hashToken(token: string) {
  return createHash("sha256").update(token).digest("hex");
}

/** Compara textos sem vazar, pelo tempo de resposta, quantos caracteres estavam certos. */
export function igual(a: string, b: string) {
  const ha = createHash("sha256").update(a).digest();
  const hb = createHash("sha256").update(b).digest();
  return timingSafeEqual(ha, hb);
}

const ALFABETO = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // sem 0/O e 1/I: não confunde na TV

export function novoCodigo() {
  const bytes = randomBytes(6);
  let s = "";
  for (const b of bytes) s += ALFABETO[b % ALFABETO.length];
  return s;
}

type ConsoleAuth = { id: string; nome: string; janelaContagem: number };

/**
 * Confere o token (Authorization: Bearer …) e conta a requisição no limite por minuto,
 * tudo em UMA ida ao banco.
 */
export async function autenticar(req: NextRequest) {
  const cabecalho = req.headers.get("authorization") ?? "";
  const token = cabecalho.startsWith("Bearer ") ? cabecalho.slice(7).trim() : "";
  if (!token) throw new Erro(401, "sem_token", "Faltou o token do console.");

  const linhas = await db.$queryRaw<ConsoleAuth[]>`
    UPDATE "Console" SET
      "janelaContagem" = CASE
        WHEN "janelaInicio" < (now() AT TIME ZONE 'utc') - interval '60 seconds' THEN 1
        ELSE "janelaContagem" + 1 END,
      "janelaInicio" = CASE
        WHEN "janelaInicio" < (now() AT TIME ZONE 'utc') - interval '60 seconds' THEN (now() AT TIME ZONE 'utc')
        ELSE "janelaInicio" END,
      "vistoEm" = (now() AT TIME ZONE 'utc')
    WHERE "tokenHash" = ${hashToken(token)}
    RETURNING "id", "nome", "janelaContagem"`;

  const console_ = linhas[0];
  if (!console_) throw new Erro(401, "token_invalido", "Token do console inválido.");
  if (console_.janelaContagem > LIMITE_POR_MINUTO) {
    throw new Erro(429, "muitas_requisicoes", "Muitas requisições. Tente de novo em um minuto.");
  }
  return { id: console_.id, nome: console_.nome };
}

/** Console + perfil (cabeçalho X-Perfil: p1, p2…). */
export async function autenticarPerfil(req: NextRequest) {
  const console_ = await autenticar(req);
  const localId = (req.headers.get("x-perfil") ?? "").trim();
  if (!localId) throw new Erro(400, "sem_perfil", "Faltou o cabeçalho X-Perfil.");
  const perfil = await db.perfil.findUnique({
    where: { consoleId_localId: { consoleId: console_.id, localId } },
  });
  if (!perfil) {
    throw new Erro(404, "perfil_desconhecido", "Este perfil ainda não foi enviado ao servidor (PUT /api/perfis).");
  }
  return { console: console_, perfil };
}
