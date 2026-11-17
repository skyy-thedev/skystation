import { autenticarPerfil } from "@/lib/auth";
import { db } from "@/lib/db";
import { Erro, json, rota } from "@/lib/http";

type Ctx = { params: Promise<{ id: string }> };

/** POST /api/amigos/:amizadeId/aceitar — só quem RECEBEU o pedido pode aceitar. */
export const POST = rota<Ctx>(async (req, { params }) => {
  const { perfil } = await autenticarPerfil(req);
  const { id } = await params;
  const r = await db.amizade.updateMany({
    where: { id, bId: perfil.id },
    data: { status: "aceita" },
  });
  if (!r.count) throw new Erro(404, "pedido_desconhecido", "Pedido de amizade não encontrado.");
  return json({ ok: true, status: "aceita" });
});
