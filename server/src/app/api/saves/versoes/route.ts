import { autenticarPerfil } from "@/lib/auth";
import { db } from "@/lib/db";
import { consulta, Erro, json, rota } from "@/lib/http";
import { jogoSchema, resumoVersao } from "@/lib/saves";

/** GET /api/saves/versoes?sistema=ps2&jogoId=… — as versões guardadas de um save (para voltar atrás). */
export const GET = rota(async (req) => {
  const { perfil } = await autenticarPerfil(req);
  const e = consulta(req, jogoSchema);
  const save = await db.save.findUnique({
    where: { perfilId_sistema_jogoId: { perfilId: perfil.id, sistema: e.sistema, jogoId: e.jogoId } },
    include: {
      versoes: {
        where: { confirmada: true },
        orderBy: { numero: "desc" },
        include: { console: { select: { nome: true } } },
      },
    },
  });
  if (!save || !save.versoes.length) throw new Erro(404, "sem_save", "Não há save deste jogo na nuvem.");
  return json({
    versaoAtual: save.versaoAtual,
    versoes: save.versoes.map(resumoVersao),
  });
});
