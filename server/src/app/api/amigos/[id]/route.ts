import { autenticarPerfil } from "@/lib/auth";
import { db } from "@/lib/db";
import { Erro, json, rota } from "@/lib/http";

type Ctx = { params: Promise<{ id: string }> };

/** DELETE /api/amigos/:amizadeId — recusa um pedido, cancela o que enviei ou desfaz a amizade. */
export const DELETE = rota<Ctx>(async (req, { params }) => {
  const { perfil } = await autenticarPerfil(req);
  const { id } = await params;
  const r = await db.amizade.deleteMany({
    where: { id, OR: [{ aId: perfil.id }, { bId: perfil.id }] },
  });
  if (!r.count) throw new Erro(404, "amizade_desconhecida", "Amizade não encontrada.");
  return json({ ok: true });
});
