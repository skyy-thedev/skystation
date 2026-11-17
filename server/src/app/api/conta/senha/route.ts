import { z } from "zod";
import { autenticarPerfil } from "@/lib/auth";
import { hashSenha, senhaSchema } from "@/lib/conta";
import { db } from "@/lib/db";
import { corpo, Erro, json, rota } from "@/lib/http";

/**
 * POST /api/conta/senha — define uma senha nova pelo console onde a conta está em uso.
 * É o "esqueci a senha": não há e-mail; quem tem o console (e o perfil nele) troca a senha.
 * Encerra as sessões abertas no site.
 */
export const POST = rota(async (req) => {
  const { perfil } = await autenticarPerfil(req);
  const { senha } = await corpo(req, z.object({ senha: senhaSchema }));
  if (!perfil.usuario) throw new Erro(400, "sem_conta", "Este perfil ainda não tem conta.");
  await db.$transaction([
    db.perfil.update({
      where: { id: perfil.id },
      data: { senhaHash: await hashSenha(senha), falhasLogin: 0, bloqueadoAte: null },
    }),
    db.sessao.deleteMany({ where: { perfilId: perfil.id } }),
  ]);
  return json({ ok: true });
});
