import { NextRequest } from "next/server";
import { z } from "zod";
import { igual, novoCodigo } from "@/lib/auth";
import {
  avatarSchema, COOKIE, criarSessao, hashSenha, idDisponivel, opcoesCookie, senhaSchema, usuarioSchema,
} from "@/lib/conta";
import { db } from "@/lib/db";
import { corpo, Erro, json, rota } from "@/lib/http";

const entrada = z.object({
  usuario: usuarioSchema,
  senha: senhaSchema,
  apelido: z.string().trim().min(1).max(24),
  avatar: avatarSchema.optional(),
  convite: z.string().min(1).max(200),
});

/**
 * POST /api/web/registrar — cria uma conta pelo site (sem console ainda). Pede o mesmo código de
 * convite dos consoles. Depois, em qualquer SkyStation: SkyNetwork → "Entrar com minha conta".
 */
export const POST = rota(async (req: NextRequest) => {
  const e = await corpo(req, entrada);
  const esperado = process.env.SKY_CONVITE;
  if (!esperado || !igual(e.convite.trim().toLowerCase(), esperado.trim().toLowerCase())) {
    throw new Erro(403, "convite_invalido", "Código de convite incorreto.");
  }
  if (!(await idDisponivel(e.usuario))) throw new Erro(409, "id_em_uso", "Este ID já está em uso. Escolha outro.");
  const senhaHash = await hashSenha(e.senha);
  let perfil;
  for (let tentativa = 0; ; tentativa++) {
    try {
      perfil = await db.perfil.create({
        data: { usuario: e.usuario, senhaHash, apelido: e.apelido, avatar: e.avatar ?? "estrela", codigo: novoCodigo() },
      });
      break;
    } catch (err) {
      const alvo = String((err as { meta?: { target?: unknown } }).meta?.target ?? "");
      if ((err as { code?: string }).code === "P2002" && alvo.includes("usuario")) {
        throw new Erro(409, "id_em_uso", "Este ID já está em uso. Escolha outro.");
      }
      if ((err as { code?: string }).code !== "P2002" || tentativa >= 4) throw err;
    }
  }
  const { token, expira } = await criarSessao(perfil.id);
  const r = json({ ok: true, usuario: perfil.usuario }, 201);
  r.cookies.set(COOKIE, token, opcoesCookie(expira));
  return r;
});
