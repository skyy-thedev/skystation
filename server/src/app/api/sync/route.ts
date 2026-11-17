import { z } from "zod";
import { autenticarPerfil } from "@/lib/auth";
import { db } from "@/lib/db";
import { corpo, json, rota } from "@/lib/http";
import { gravarPresenca, presencaSchema, vistoPorAmigos } from "@/lib/rede";

const entrada = z.object({
  presenca: presencaSchema.optional(),
  /** O campo `agora` da resposta anterior. Sem ele, vem o estado inicial. */
  desde: z.iso.datetime().optional(),
});

const perfilPublico = { id: true, apelido: true, cor: true, avatar: true, usuario: true } as const;
const comPresenca = { ...perfilPublico, invisivel: true, presenca: true } as const;

/**
 * POST /api/sync — a única chamada que o console repete (a cada 30 s): envia a própria presença
 * e recebe tudo o que mudou. Uma requisição em vez de quatro = menos bateria, menos Wi-Fi e
 * folga no plano gratuito.
 *
 * As listas `mensagens` e `trofeus` podem repetir itens da chamada anterior (há uma sobra de
 * 5 s de propósito, para nada se perder): o console ignora os ids que já viu.
 */
export const POST = rota(async (req) => {
  const { perfil } = await autenticarPerfil(req);
  const e = await corpo(req, entrada);
  const agora = new Date();
  if (e.presenca) await gravarPresenca(perfil.id, e.presenca);

  const desde = e.desde ? new Date(new Date(e.desde).getTime() - 5000) : null;

  const amizades = await db.amizade.findMany({
    where: { OR: [{ aId: perfil.id }, { bId: perfil.id }] },
    include: { a: { select: comPresenca }, b: { select: comPresenca } },
    orderBy: { criadaEm: "asc" },
  });
  const aceitas = amizades.filter((a) => a.status === "aceita");
  const idsAmigos = aceitas.map((a) => (a.aId === perfil.id ? a.bId : a.aId));

  const [mensagens, naoLidas, trofeus] = await Promise.all([
    db.mensagem.findMany({
      where: { paraId: perfil.id, ...(desde ? { enviadaEm: { gt: desde } } : { lidaEm: null }) },
      orderBy: { enviadaEm: "asc" },
      take: 100,
      include: { de: { select: perfilPublico } },
    }),
    db.mensagem.count({ where: { paraId: perfil.id, lidaEm: null } }),
    idsAmigos.length
      ? db.trofeuGanho.findMany({
          where: { perfilId: { in: idsAmigos }, ...(desde ? { criadoEm: { gt: desde } } : {}) },
          orderBy: { criadoEm: "desc" },
          take: desde ? 100 : 20,
          include: { perfil: { select: perfilPublico } },
        })
      : [],
  ]);

  return json({
    agora,
    eu: {
      id: perfil.id,
      apelido: perfil.apelido,
      cor: perfil.cor,
      codigo: perfil.codigo,
      invisivel: perfil.invisivel,
      usuario: perfil.usuario,
      avatar: perfil.avatar,
    },
    amigos: aceitas.map((a) => ({
      amizadeId: a.id,
      ...vistoPorAmigos(a.aId === perfil.id ? a.b : a.a, agora),
    })),
    pedidosRecebidos: amizades
      .filter((a) => a.status === "pendente" && a.bId === perfil.id)
      .map((a) => ({ amizadeId: a.id, de: { id: a.a.id, apelido: a.a.apelido, cor: a.a.cor }, criadaEm: a.criadaEm })),
    pedidosEnviados: amizades
      .filter((a) => a.status === "pendente" && a.aId === perfil.id)
      .map((a) => ({ amizadeId: a.id, para: { id: a.b.id, apelido: a.b.apelido, cor: a.b.cor }, criadaEm: a.criadaEm })),
    mensagens: mensagens.map((m) => ({
      id: m.id,
      de: m.de,
      tipo: m.tipo,
      texto: m.texto,
      jogoId: m.jogoId,
      jogo: m.jogo,
      sistema: m.sistema,
      sala: m.sala,
      enviadaEm: m.enviadaEm,
      lida: m.lidaEm !== null,
    })),
    naoLidas,
    trofeus: trofeus.map((t) => ({
      id: t.id,
      de: t.perfil,
      jogoId: t.jogoId,
      jogo: t.jogo,
      trofeu: t.trofeu,
      nome: t.nome,
      tipo: t.tipo,
      ganhoEm: t.ganhoEm,
    })),
  });
});
