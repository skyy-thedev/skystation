import { autenticarPerfil } from "@/lib/auth";
import { db } from "@/lib/db";
import { Erro, json, rota } from "@/lib/http";
import { atividadeDoPerfil, podeVer } from "@/lib/social";

type Ctx = { params: Promise<{ id: string }> };

/** GET /api/jogadores/:perfilId — 13.26: a página de um jogador no console (ou "eu"): jogos, troféus e capturas. */
export const GET = rota<Ctx>(async (req, { params }) => {
  const { perfil } = await autenticarPerfil(req);
  const { id } = await params;
  const alvo = id === "eu" ? perfil.id : id;
  if (!(await podeVer(alvo, perfil.id))) throw new Erro(403, "privado", "Só os amigos dessa pessoa veem o perfil dela.");
  const p = await db.perfil.findUnique({
    where: { id: alvo },
    select: { id: true, apelido: true, avatar: true, usuario: true, cor: true, bio: true, criadoEm: true },
  });
  if (!p) throw new Erro(404, "jogador_desconhecido", "Jogador não encontrado.");
  return json({ perfil: p, ...(await atividadeDoPerfil(alvo, perfil.id, true)) });
});
