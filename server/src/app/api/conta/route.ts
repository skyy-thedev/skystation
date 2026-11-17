import { z } from "zod";
import { autenticarPerfil } from "@/lib/auth";
import { edicaoSchema, hashSenha, idDisponivel, senhaSchema, usuarioSchema } from "@/lib/conta";
import { db } from "@/lib/db";
import { corpo, Erro, json, rota } from "@/lib/http";

const campos = {
  id: true, usuario: true, apelido: true, avatar: true, bio: true, visibilidade: true, invisivel: true, codigo: true,
} as const;

/** GET /api/conta — a conta do perfil em uso no console (usuario null = ainda sem conta). */
export const GET = rota(async (req) => {
  const { perfil } = await autenticarPerfil(req);
  return json({ conta: await db.perfil.findUnique({ where: { id: perfil.id }, select: campos }) });
});

const criacao = z.object({ usuario: usuarioSchema, senha: senhaSchema });

/**
 * POST /api/conta — transforma o perfil em uso numa conta pessoal (ID + senha). A partir daí dá
 * para entrar no site e em qualquer console com o ID, e a conta não depende mais deste pendrive.
 */
export const POST = rota(async (req) => {
  const { perfil } = await autenticarPerfil(req);
  const { usuario, senha } = await corpo(req, criacao);
  if (perfil.usuario) throw new Erro(409, "ja_tem_conta", `Este perfil já é a conta ${perfil.usuario}.`);
  if (!(await idDisponivel(usuario))) throw new Erro(409, "id_em_uso", "Este ID já está em uso. Escolha outro.");
  try {
    const conta = await db.perfil.update({
      where: { id: perfil.id },
      data: { usuario, senhaHash: await hashSenha(senha) },
      select: campos,
    });
    return json({ conta }, 201);
  } catch (e) {
    if ((e as { code?: string }).code === "P2002") throw new Erro(409, "id_em_uso", "Este ID já está em uso. Escolha outro.");
    throw e;
  }
});

/** PATCH /api/conta — muda ícone, apelido, bio, visibilidade ou invisível pelo console. */
export const PATCH = rota(async (req) => {
  const { perfil } = await autenticarPerfil(req);
  const mudancas = await corpo(req, edicaoSchema);
  const conta = await db.perfil.update({ where: { id: perfil.id }, data: mudancas, select: campos });
  return json({ conta });
});
