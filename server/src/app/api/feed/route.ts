import { z } from "zod";
import { autenticarPerfil } from "@/lib/auth";
import { db } from "@/lib/db";
import { consulta, json, rota } from "@/lib/http";
import { idsAmigos, postInclude, postsParaCliente } from "@/lib/social";

const params = z.object({ antes: z.iso.datetime().optional() });
const autor = { select: { id: true, apelido: true, avatar: true, usuario: true, cor: true } } as const;

/**
 * GET /api/feed[?antes=<data>] — 13.26: a aba Atividade do console. Capturas publicadas por você e pelos
 * amigos (20 por vez, da mais nova), e o que os amigos jogaram e ganharam por último.
 */
export const GET = rota(async (req) => {
  const { perfil } = await autenticarPerfil(req);
  const e = consulta(req, params);
  const amigos = await idsAmigos(perfil.id);
  const quem = [perfil.id, ...amigos];
  const [posts, jogos, trofeus] = await Promise.all([
    db.post.findMany({
      where: { perfilId: { in: quem }, confirmado: true, ...(e.antes ? { criadoEm: { lt: new Date(e.antes) } } : {}) },
      orderBy: { criadoEm: "desc" },
      take: 20,
      include: postInclude,
    }),
    e.antes || !amigos.length
      ? []
      : db.jogoJogado.findMany({
          where: { perfilId: { in: amigos } },
          orderBy: { ultimaVez: "desc" },
          take: 20,
          include: { perfil: autor },
        }),
    e.antes || !amigos.length
      ? []
      : db.trofeuGanho.findMany({
          where: { perfilId: { in: amigos } },
          orderBy: { ganhoEm: "desc" },
          take: 20,
          include: { perfil: autor },
        }),
  ]);
  return json({
    posts: await postsParaCliente(posts, perfil.id, true),
    jogos: jogos.map((j) => ({ autor: j.perfil, jogoId: j.jogoId, titulo: j.titulo, sistema: j.sistema,
      segundos: j.segundos, ultimaVez: j.ultimaVez })),
    trofeus: trofeus.map((t) => ({ autor: t.perfil, nome: t.nome || t.trofeu, tipo: t.tipo, jogo: t.jogo,
      ganhoEm: t.ganhoEm })),
  });
});
