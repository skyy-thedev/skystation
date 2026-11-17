import { z } from "zod";
import { hashToken, igual, novoToken } from "@/lib/auth";
import { db } from "@/lib/db";
import { corpo, Erro, json, rota } from "@/lib/http";

const entrada = z.object({
  nome: z.string().trim().min(1).max(40),
  convite: z.string().min(1).max(200),
});

/**
 * POST /api/consoles — registra um console novo e devolve o token (só desta vez: o servidor
 * guarda apenas o hash). Exige o código de convite (SKY_CONVITE), para ninguém de fora entrar.
 */
export const POST = rota(async (req) => {
  const { nome, convite } = await corpo(req, entrada);
  const esperado = process.env.SKY_CONVITE;
  if (!esperado) throw new Erro(503, "sem_convite", "O servidor está sem código de convite (SKY_CONVITE).");
  if (!igual(convite, esperado)) throw new Erro(403, "convite_invalido", "Código de convite incorreto.");

  const maximo = Number(process.env.SKY_MAX_CONSOLES || 8);
  if ((await db.console.count()) >= maximo) {
    throw new Erro(403, "rede_cheia", `A rede já tem o máximo de ${maximo} consoles.`);
  }

  const token = novoToken();
  const console_ = await db.console.create({
    data: { nome, tokenHash: hashToken(token) },
    select: { id: true, nome: true },
  });
  return json({ console: console_, token }, 201);
});
