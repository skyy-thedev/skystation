import { z } from "zod";
import { autenticarPerfil } from "@/lib/auth";
import { db } from "@/lib/db";
import { consulta, corpo, json, rota } from "@/lib/http";
import { exigirAmizade } from "@/lib/rede";

const entrada = z.object({
  trofeus: z
    .array(
      z.object({
        jogoId: z.string().min(1).max(200).default("skystation"),
        jogo: z.string().max(200).optional(),
        trofeu: z.string().min(1).max(80),
        nome: z.string().max(120).optional(),
        tipo: z.enum(["bronze", "prata", "ouro", "platina"]),
        ganhoEm: z.iso.datetime().optional(),
      }),
    )
    .min(1)
    .max(100),
});

/**
 * POST /api/trofeus — registra troféus ganhos. Pode mandar a lista inteira sempre: os que o
 * servidor já conhece são ignorados (e não geram aviso de novo para os amigos).
 */
export const POST = rota(async (req) => {
  const { perfil } = await autenticarPerfil(req);
  const { trofeus } = await corpo(req, entrada);
  const r = await db.trofeuGanho.createMany({
    data: trofeus.map((t) => ({
      perfilId: perfil.id,
      jogoId: t.jogoId,
      jogo: t.jogo,
      trofeu: t.trofeu,
      nome: t.nome,
      tipo: t.tipo,
      ganhoEm: t.ganhoEm ? new Date(t.ganhoEm) : undefined,
    })),
    skipDuplicates: true,
  });
  return json({ ok: true, novos: r.count });
});

const filtro = z.object({ perfil: z.string().min(1).max(60).optional() });

/** GET /api/trofeus[?perfil=<id de um amigo>] — os meus troféus ou os de um amigo (para comparar). */
export const GET = rota(async (req) => {
  const { perfil } = await autenticarPerfil(req);
  const e = consulta(req, filtro);
  const alvo = e.perfil && e.perfil !== perfil.id ? e.perfil : perfil.id;
  if (alvo !== perfil.id) await exigirAmizade(perfil.id, alvo);
  const lista = await db.trofeuGanho.findMany({
    where: { perfilId: alvo },
    orderBy: { ganhoEm: "desc" },
    select: { jogoId: true, jogo: true, trofeu: true, nome: true, tipo: true, ganhoEm: true },
  });
  return json({ perfilId: alvo, trofeus: lista });
});
