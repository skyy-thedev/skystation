import { z } from "zod";
import { autenticar, hashToken } from "@/lib/auth";
import { db } from "@/lib/db";
import { consulta, corpo, Erro, json, rota } from "@/lib/http";

const local = z.string().regex(/^[a-z0-9]{1,8}$/);
const entrada = z.object({
  localId: local,
  codigo: z.string().trim().toUpperCase().regex(/^[A-Z0-9]{8}$/, "o código tem 8 letras ou números"),
});

/**
 * POST /api/perfis/vincular — "neste console, o perfil local <localId> é o jogador do código".
 * A partir daí os saves na nuvem, os amigos e as mensagens são os daquele jogador.
 */
export const POST = rota(async (req) => {
  const console_ = await autenticar(req);
  const { localId, codigo } = await corpo(req, entrada);

  const perfil = await db.perfil.findFirst({
    where: { vinculoHash: hashToken(codigo), vinculoExpira: { gt: new Date() } },
    select: { id: true, apelido: true, cor: true, codigo: true, consoleId: true, localId: true },
  });
  if (!perfil) throw new Erro(404, "codigo_invalido", "Código incorreto ou vencido. Gere outro no console de origem.");
  if (perfil.consoleId === console_.id) {
    throw new Erro(400, "mesmo_console", "Este perfil já é deste console.");
  }

  const chave = { consoleId_localId: { consoleId: console_.id, localId } };
  await db.$transaction([
    db.vinculo.upsert({
      where: chave,
      create: { consoleId: console_.id, localId, perfilId: perfil.id },
      update: { perfilId: perfil.id },
    }),
    db.perfil.update({ where: { id: perfil.id }, data: { vinculoHash: null, vinculoExpira: null } }), // uso único
  ]);
  return json({ ok: true, perfil: { id: perfil.id, apelido: perfil.apelido, cor: perfil.cor, codigo: perfil.codigo } });
});

/** DELETE /api/perfis/vincular?localId=p1 — desfaz o vínculo (os saves continuam na nuvem, com o dono). */
export const DELETE = rota(async (req) => {
  const console_ = await autenticar(req);
  const { localId } = consulta(req, z.object({ localId: local }));
  const r = await db.vinculo.deleteMany({ where: { consoleId: console_.id, localId } });
  if (!r.count) throw new Erro(404, "sem_vinculo", "Este perfil não está vinculado.");
  return json({ ok: true });
});
