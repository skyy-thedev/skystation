import { z } from "zod";
import { autenticarPerfil } from "@/lib/auth";
import { db } from "@/lib/db";
import { corpo, json, rota } from "@/lib/http";

const entrada = z
  .object({
    /** marca como lidas todas as mensagens deste amigo… */
    deId: z.string().min(1).max(60).optional(),
    /** …ou só estas */
    ids: z.array(z.string().min(1).max(60)).max(200).optional(),
  })
  .refine((v) => v.deId || v.ids?.length, "informe deId ou ids");

/** POST /api/mensagens/lidas — marca mensagens recebidas como lidas. */
export const POST = rota(async (req) => {
  const { perfil } = await autenticarPerfil(req);
  const e = await corpo(req, entrada);
  const r = await db.mensagem.updateMany({
    where: {
      paraId: perfil.id,
      lidaEm: null,
      ...(e.deId ? { deId: e.deId } : {}),
      ...(e.ids?.length ? { id: { in: e.ids } } : {}),
    },
    data: { lidaEm: new Date() },
  });
  return json({ ok: true, marcadas: r.count });
});
