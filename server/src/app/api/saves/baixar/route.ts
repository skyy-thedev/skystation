import { z } from "zod";
import { autenticarPerfil } from "@/lib/auth";
import { consulta, json, rota } from "@/lib/http";
import { acharVersao, jogoSchema, resumoVersao } from "@/lib/saves";
import { urlDownload } from "@/lib/storage";

const entrada = jogoSchema.extend({ versao: z.coerce.number().int().positive().optional() });

/**
 * GET /api/saves/baixar?sistema=ps2&jogoId=…[&versao=3] — devolve um endereço temporário para
 * baixar o save (a versão atual, ou uma das guardadas).
 */
export const GET = rota(async (req) => {
  const { perfil } = await autenticarPerfil(req);
  const e = consulta(req, entrada);
  const { versao } = await acharVersao(perfil.id, e.sistema, e.jogoId, e.versao);
  return json({
    ...resumoVersao(versao),
    url: await urlDownload(versao.chave),
    expiraEmSegundos: 300,
  });
});
