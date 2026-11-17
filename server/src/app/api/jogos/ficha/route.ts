import { z } from "zod";
import { autenticar } from "@/lib/auth";
import { jogoDoCatalogo, JOGOS } from "@/lib/catalogo";
import { consulta, json, rota } from "@/lib/http";
import { infoJogo, limparNome, normalizar } from "@/lib/jogos";

const entrada = z.object({
  nome: z.string().trim().min(1).max(200),
  sistema: z.string().trim().toLowerCase().regex(/^[a-z0-9]{1,12}$/).optional(),
  ano: z.coerce.number().int().min(1970).max(2100).optional(),
});

/**
 * GET /api/jogos/ficha?nome=…&sistema=… — capa, arte, resumo, ano, desenvolvedora e nota de um jogo
 * (Fase 9.1: o console mostra a arte no fundo e a ficha ao parar num jogo). Só para consoles da rede:
 * as chaves da IGDB/RAWG ficam no servidor e o limite por minuto do console vale aqui também.
 * Se o jogo estiver no catálogo de testados, devolve também a situação (perfeito, jogável…).
 */
export const GET = rota(async (req) => {
  await autenticar(req);
  const { nome, sistema, ano } = consulta(req, entrada);
  // o catálogo sabe o ano certo (separa God of War 2005 do de 2018)
  const alvo = normalizar(limparNome(nome));
  const doCatalogo = JOGOS.find((j) => j.sistema === sistema && normalizar(j.nome) === alvo) ?? null;
  const ficha = await infoJogo(nome, sistema ?? "", ano ?? doCatalogo?.ano);
  const catalogo = doCatalogo ? jogoDoCatalogo(doCatalogo.sistema, doCatalogo.id) : null;
  return json({
    ficha: catalogo?.capa ? { ...ficha, capa: catalogo.capa } : ficha,
    catalogo: catalogo && { situacao: catalogo.situacao, nota: catalogo.nota ?? null },
  });
});
