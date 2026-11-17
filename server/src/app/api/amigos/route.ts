import { z } from "zod";
import { autenticarPerfil } from "@/lib/auth";
import { db } from "@/lib/db";
import { corpo, Erro, json, rota } from "@/lib/http";
import { amizadeEntre } from "@/lib/rede";

// consoles antigos mandam { codigo }; os novos mandam { quem } = ID SkyNetwork ou código de amigo
const entrada = z.union([
  z.object({ codigo: z.string().trim().toUpperCase().regex(/^[A-Z0-9]{6}$/, "o código tem 6 letras ou números") }),
  z.object({ quem: z.string().trim().min(3).max(40) }),
]);

/**
 * POST /api/amigos — pede amizade pelo ID SkyNetwork (conta pessoal) ou pelo código de 6 letras.
 * Se o outro já tinha pedido a minha amizade, os dois viram amigos na hora.
 */
export const POST = rota(async (req) => {
  const { perfil } = await autenticarPerfil(req);
  const e = await corpo(req, entrada);
  const q = "codigo" in e ? e.codigo : e.quem.replace(/^@/, "");
  const select = { id: true, apelido: true, cor: true, avatar: true };
  // o ID SkyNetwork vence: um ID de 6 letras igual a um código de outra pessoa acha a conta
  const outro =
    ("quem" in e ? await db.perfil.findFirst({ where: { usuario: q.toLowerCase() }, select }) : null) ??
    (/^[A-Za-z0-9]{6}$/.test(q) ? await db.perfil.findUnique({ where: { codigo: q.toUpperCase() }, select }) : null);
  if (!outro) throw new Erro(404, "codigo_desconhecido", "Nenhum jogador com esse ID SkyNetwork ou código.");
  if (outro.id === perfil.id) throw new Erro(400, "voce_mesmo", "Esse é você.");

  const existente = await amizadeEntre(perfil.id, outro.id);
  if (existente?.status === "aceita") {
    return json({ amizadeId: existente.id, status: "aceita", amigo: outro });
  }
  if (existente && existente.aId === outro.id) {
    const aceita = await db.amizade.update({ where: { id: existente.id }, data: { status: "aceita" } });
    return json({ amizadeId: aceita.id, status: "aceita", amigo: outro });
  }
  if (existente) return json({ amizadeId: existente.id, status: "pendente", amigo: outro });

  const nova = await db.amizade.create({ data: { aId: perfil.id, bId: outro.id } });
  return json({ amizadeId: nova.id, status: "pendente", amigo: outro }, 201);
});
