import { z } from "zod";
import { autenticarPerfil } from "@/lib/auth";
import { db } from "@/lib/db";
import { consulta, corpo, json, rota } from "@/lib/http";
import { exigirAmizade, sistemaSchema } from "@/lib/rede";

const envio = z.object({
  paraId: z.string().min(1).max(60),
  tipo: z.enum(["texto", "convite"]).default("texto"),
  texto: z.string().trim().min(1).max(280),
  // só nos convites
  jogoId: z.string().max(200).optional(),
  jogo: z.string().max(200).optional(),
  sistema: sistemaSchema.optional(),
});

/** POST /api/mensagens — envia uma mensagem (ou um convite para jogar) a um amigo. */
export const POST = rota(async (req) => {
  const { perfil } = await autenticarPerfil(req);
  const e = await corpo(req, envio);
  await exigirAmizade(perfil.id, e.paraId);
  const convite = e.tipo === "convite";
  const m = await db.mensagem.create({
    data: {
      deId: perfil.id,
      paraId: e.paraId,
      tipo: e.tipo,
      texto: e.texto,
      jogoId: convite ? e.jogoId : undefined,
      jogo: convite ? e.jogo : undefined,
      sistema: convite ? e.sistema : undefined,
    },
    select: { id: true, enviadaEm: true },
  });
  return json(m, 201);
});

const historico = z.object({
  com: z.string().min(1).max(60),
  antes: z.iso.datetime().optional(),
});

/** GET /api/mensagens?com=<perfilId>[&antes=<data>] — a conversa com um amigo, 50 por vez, da mais nova para a mais antiga. */
export const GET = rota(async (req) => {
  const { perfil } = await autenticarPerfil(req);
  const e = consulta(req, historico);
  const mensagens = await db.mensagem.findMany({
    where: {
      OR: [
        { deId: perfil.id, paraId: e.com },
        { deId: e.com, paraId: perfil.id },
      ],
      ...(e.antes ? { enviadaEm: { lt: new Date(e.antes) } } : {}),
    },
    orderBy: { enviadaEm: "desc" },
    take: 50,
  });
  return json({
    mensagens: mensagens.map((m) => ({
      id: m.id,
      minha: m.deId === perfil.id,
      tipo: m.tipo,
      texto: m.texto,
      jogoId: m.jogoId,
      jogo: m.jogo,
      sistema: m.sistema,
      enviadaEm: m.enviadaEm,
      lida: m.lidaEm !== null,
    })),
  });
});
