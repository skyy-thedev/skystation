import { autenticarPerfil } from "@/lib/auth";
import { corpo, json, rota } from "@/lib/http";
import { gravarPresenca, presencaSchema } from "@/lib/rede";

/**
 * POST /api/presenca — "estou online / jogando X". No dia a dia o console manda a presença
 * junto com o /api/sync; esta rota serve para avisar na hora (abriu ou fechou um jogo).
 */
export const POST = rota(async (req) => {
  const { perfil } = await autenticarPerfil(req);
  await gravarPresenca(perfil.id, await corpo(req, presencaSchema));
  return json({ ok: true });
});
