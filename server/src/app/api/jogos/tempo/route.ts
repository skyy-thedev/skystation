import { z } from "zod";
import { autenticarPerfil } from "@/lib/auth";
import { db } from "@/lib/db";
import { corpo, json, rota } from "@/lib/http";

const entrada = z.object({
  jogos: z
    .array(
      z.object({
        jogoId: z.string().trim().min(1).max(200),
        titulo: z.string().trim().min(1).max(200),
        sistema: z.string().regex(/^[a-z0-9]{1,12}$/).optional(),
        segundos: z.number().int().min(0).max(100_000_000),
        partidas: z.number().int().min(0).max(1_000_000),
        ultimaVez: z.number().int().positive(), // segundos desde 1970 (como no tempo.json)
      }),
    )
    .max(500),
});

/**
 * POST /api/jogos/tempo — 13.26: o console manda o tempo de jogo de cada jogo do perfil (tempo.json).
 * Os amigos veem "jogou recentemente" e quanto tempo. Só sobe: nunca diminui o que já está no servidor.
 */
export const POST = rota(async (req) => {
  const { perfil } = await autenticarPerfil(req);
  const e = await corpo(req, entrada);
  const atuais = await db.jogoJogado.findMany({ where: { perfilId: perfil.id }, select: { jogoId: true, segundos: true, partidas: true, ultimaVez: true } });
  const por = new Map(atuais.map((j) => [j.jogoId, j]));
  let mudou = 0;
  for (const j of e.jogos) {
    const quando = new Date(j.ultimaVez * 1000);
    const a = por.get(j.jogoId);
    if (a && a.segundos >= j.segundos && a.partidas >= j.partidas && a.ultimaVez >= quando) continue;
    await db.jogoJogado.upsert({
      where: { perfilId_jogoId: { perfilId: perfil.id, jogoId: j.jogoId } },
      create: { perfilId: perfil.id, jogoId: j.jogoId, titulo: j.titulo, sistema: j.sistema, segundos: j.segundos,
        partidas: j.partidas, ultimaVez: quando },
      update: { titulo: j.titulo, sistema: j.sistema, segundos: Math.max(a?.segundos ?? 0, j.segundos),
        partidas: Math.max(a?.partidas ?? 0, j.partidas), ultimaVez: a && a.ultimaVez > quando ? a.ultimaVez : quando },
    });
    mudou++;
  }
  return json({ ok: true, atualizados: mudou });
});
