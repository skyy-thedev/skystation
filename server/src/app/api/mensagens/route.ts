import { z } from "zod";
import { autenticarPerfil } from "@/lib/auth";
import { db } from "@/lib/db";
import { consulta, corpo, Erro, json, rota } from "@/lib/http";
import { exigirAmizade, sistemaSchema } from "@/lib/rede";

// sala de netplay do RetroArch (convite "netplay"): onde o amigo se conecta
const salaSchema = z.object({
  ip: z.string().trim().min(3).max(100).regex(/^[A-Za-z0-9.:-]+$/),
  porta: z.number().int().min(1).max(65535),
  sessao: z.string().trim().max(64).regex(/^[A-Za-z0-9+/=_-]*$/).default(""),
  senha: z.string().max(32).default(""),
  crc: z.string().max(16).regex(/^[0-9A-Fa-f]*$/).optional(),
  core: z.string().max(80).optional(),
  // DEADZONE online: outros endereços do mesmo anfitrião (IPv6, rede local, UPnP); o amigo tenta todos
  alternativos: z.array(z.string().trim().min(3).max(100).regex(/^[A-Za-z0-9.:-]+$/)).max(8).optional(),
});

const envio = z.object({
  paraId: z.string().min(1).max(60),
  tipo: z.enum(["texto", "convite", "netplay"]).default("texto"),
  texto: z.string().trim().min(1).max(280),
  // só nos convites
  jogoId: z.string().max(200).optional(),
  jogo: z.string().max(200).optional(),
  sistema: sistemaSchema.optional(),
  sala: salaSchema.optional(),
});

/** POST /api/mensagens — envia uma mensagem (ou um convite para jogar) a um amigo. */
export const POST = rota(async (req) => {
  const { perfil } = await autenticarPerfil(req);
  const e = await corpo(req, envio);
  await exigirAmizade(perfil.id, e.paraId);
  const convite = e.tipo === "convite" || e.tipo === "netplay";
  if (e.tipo === "netplay" && !e.sala) throw new Erro(400, "sem_sala", "Convite de netplay sem os dados da sala.");
  const m = await db.mensagem.create({
    data: {
      deId: perfil.id,
      paraId: e.paraId,
      tipo: e.tipo,
      texto: e.texto,
      jogoId: convite ? e.jogoId : undefined,
      jogo: convite ? e.jogo : undefined,
      sistema: convite ? e.sistema : undefined,
      sala: e.tipo === "netplay" ? e.sala : undefined,
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
