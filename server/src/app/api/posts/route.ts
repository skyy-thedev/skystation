import { z } from "zod";
import { autenticarPerfil } from "@/lib/auth";
import { db } from "@/lib/db";
import { corpo, Erro, json, rota } from "@/lib/http";
import { POST_MAX_BYTES, POSTS_POR_DIA } from "@/lib/social";
import { urlEnvio } from "@/lib/storage";

const entrada = z.object({
  legenda: z.string().trim().max(280).default(""),
  jogoId: z.string().trim().max(200).optional(),
  jogo: z.string().trim().max(200).optional(),
  sistema: z.string().regex(/^[a-z0-9]{1,12}$/).optional(),
  tipo: z.enum(["image/jpeg", "image/png"]).default("image/jpeg"),
  tamanho: z.number().int().positive().max(POST_MAX_BYTES, "a imagem passa de 8 MB"),
});

/**
 * POST /api/posts — 13.26: publicar uma captura, passo 1. Responde { id, url }: o console faz PUT da imagem
 * em `url` (direto no armazenamento) e depois POST /api/posts/:id/confirmar.
 */
export const POST = rota(async (req) => {
  const { perfil } = await autenticarPerfil(req);
  const e = await corpo(req, entrada);
  const hoje = await db.post.count({ where: { perfilId: perfil.id, criadoEm: { gt: new Date(Date.now() - 86_400_000) } } });
  if (hoje >= POSTS_POR_DIA) throw new Erro(429, "muitos_posts", `Limite de ${POSTS_POR_DIA} capturas por dia.`);
  const id = crypto.randomUUID();
  const ext = e.tipo === "image/png" ? "png" : "jpg";
  const chave = `posts/${perfil.id}/${id}.${ext}`;
  const p = await db.post.create({
    data: { perfilId: perfil.id, legenda: e.legenda, jogoId: e.jogoId, jogo: e.jogo, sistema: e.sistema, chave,
      tipo: e.tipo, tamanho: e.tamanho },
    select: { id: true },
  });
  return json({ id: p.id, metodo: "PUT", url: await urlEnvio(chave), expiraEmSegundos: 900 }, 201);
});
