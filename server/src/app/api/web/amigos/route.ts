import { NextRequest } from "next/server";
import { z } from "zod";
import { db } from "@/lib/db";
import { corpo, Erro, json, rota } from "@/lib/http";
import { amizadeEntre } from "@/lib/rede";
import { sessaoWeb } from "@/lib/web";

/** POST /api/web/amigos — pede amizade pelo ID SkyNetwork ou pelo código de 6 letras. */
export const POST = rota(async (req: NextRequest) => {
  const p = await sessaoWeb(req);
  const { quem } = await corpo(req, z.object({ quem: z.string().trim().min(3).max(40) }));
  const q = quem.replace(/^@/, "");
  const outro = await db.perfil.findFirst({
    where: { OR: [{ usuario: q.toLowerCase() }, { codigo: q.toUpperCase() }] },
    select: { id: true, apelido: true },
  });
  if (!outro) throw new Erro(404, "nao_encontrado", "Nenhum jogador com esse ID ou código.");
  if (outro.id === p.id) throw new Erro(400, "voce_mesmo", "Esse é você.");
  const existente = await amizadeEntre(p.id, outro.id);
  if (existente?.status === "aceita") return json({ status: "aceita", apelido: outro.apelido });
  if (existente && existente.aId === outro.id) {
    await db.amizade.update({ where: { id: existente.id }, data: { status: "aceita" } });
    return json({ status: "aceita", apelido: outro.apelido });
  }
  if (!existente) await db.amizade.create({ data: { aId: p.id, bId: outro.id } });
  return json({ status: "pendente", apelido: outro.apelido }, 201);
});
