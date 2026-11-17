import { z } from "zod";
import { autenticar } from "@/lib/auth";
import { conferirLogin, senhaSchema } from "@/lib/conta";
import { db } from "@/lib/db";
import { corpo, json, rota } from "@/lib/http";

const entrada = z.object({
  localId: z.string().regex(/^[a-z0-9]{1,8}$/),
  usuario: z.string().min(1).max(40),
  senha: senhaSchema,
});

/**
 * POST /api/perfis/entrar — entra com uma conta (ID + senha) num perfil deste console.
 * O perfil local passa a ser aquela conta: amigos, mensagens, troféus e saves na nuvem.
 */
export const POST = rota(async (req) => {
  const console_ = await autenticar(req);
  const { localId, usuario, senha } = await corpo(req, entrada);
  const perfil = await conferirLogin(usuario, senha);
  if (perfil.consoleId === console_.id && perfil.localId === localId) {
    return json({ ok: true, perfil: { id: perfil.id, usuario: perfil.usuario, apelido: perfil.apelido, avatar: perfil.avatar } });
  }
  const chave = { consoleId_localId: { consoleId: console_.id, localId } };
  await db.vinculo.upsert({
    where: chave,
    create: { consoleId: console_.id, localId, perfilId: perfil.id },
    update: { perfilId: perfil.id },
  });
  return json({ ok: true, perfil: { id: perfil.id, usuario: perfil.usuario, apelido: perfil.apelido, avatar: perfil.avatar } });
});
