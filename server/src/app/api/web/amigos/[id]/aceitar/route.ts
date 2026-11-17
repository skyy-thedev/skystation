import { NextRequest } from "next/server";
import { db } from "@/lib/db";
import { Erro, json, rota } from "@/lib/http";
import { sessaoWeb } from "@/lib/web";

type Ctx = { params: Promise<{ id: string }> };

/** POST /api/web/amigos/:amizadeId/aceitar */
export const POST = rota<Ctx>(async (req: NextRequest, { params }) => {
  const p = await sessaoWeb(req);
  const { id } = await params;
  const r = await db.amizade.updateMany({ where: { id, bId: p.id }, data: { status: "aceita" } });
  if (!r.count) throw new Erro(404, "pedido_desconhecido", "Pedido não encontrado.");
  return json({ ok: true });
});
