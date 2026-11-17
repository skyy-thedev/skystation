import { NextRequest } from "next/server";
import { db } from "@/lib/db";
import { Erro, json, rota } from "@/lib/http";
import { sessaoWeb } from "@/lib/web";

type Ctx = { params: Promise<{ id: string }> };

/** DELETE /api/web/amigos/:amizadeId — recusa, cancela ou desfaz. */
export const DELETE = rota<Ctx>(async (req: NextRequest, { params }) => {
  const p = await sessaoWeb(req);
  const { id } = await params;
  const r = await db.amizade.deleteMany({ where: { id, OR: [{ aId: p.id }, { bId: p.id }] } });
  if (!r.count) throw new Erro(404, "amizade_desconhecida", "Amizade não encontrada.");
  return json({ ok: true });
});
