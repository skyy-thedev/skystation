import { z } from "zod";
import { autenticarPerfil } from "@/lib/auth";
import { db } from "@/lib/db";
import { corpo, Erro, json, rota } from "@/lib/http";
import { amizadeEntre } from "@/lib/rede";

const entrada = z.object({
  codigo: z.string().trim().toUpperCase().regex(/^[A-Z0-9]{6}$/, "o código tem 6 letras ou números"),
});

/**
 * POST /api/amigos — pede amizade pelo código de 6 letras do outro jogador.
 * Se o outro já tinha pedido a minha amizade, os dois viram amigos na hora.
 */
export const POST = rota(async (req) => {
  const { perfil } = await autenticarPerfil(req);
  const { codigo } = await corpo(req, entrada);

  const outro = await db.perfil.findUnique({
    where: { codigo },
    select: { id: true, apelido: true, cor: true, avatar: true },
  });
  if (!outro) throw new Erro(404, "codigo_desconhecido", "Nenhum jogador com este código.");
  if (outro.id === perfil.id) throw new Erro(400, "voce_mesmo", "Este é o seu próprio código.");

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
