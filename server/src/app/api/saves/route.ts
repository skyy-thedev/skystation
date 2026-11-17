import { autenticarPerfil } from "@/lib/auth";
import { db } from "@/lib/db";
import { consulta, Erro, json, rota } from "@/lib/http";
import { jogoSchema, resumoVersao } from "@/lib/saves";
import { apagar } from "@/lib/storage";

/**
 * GET /api/saves — todos os saves deste perfil na nuvem, com a versão atual de cada um.
 * O console compara com o que tem no disco para saber o que baixar e o que enviar.
 */
export const GET = rota(async (req) => {
  const { perfil } = await autenticarPerfil(req);
  const saves = await db.save.findMany({
    where: { perfilId: perfil.id, versaoAtual: { gt: 0 } },
    orderBy: { atualizadoEm: "desc" },
    include: {
      versoes: {
        where: { confirmada: true },
        orderBy: { numero: "desc" },
        include: { console: { select: { nome: true } } },
      },
    },
  });
  return json({
    saves: saves.flatMap((s) => {
      const atual = s.versoes.find((v) => v.numero === s.versaoAtual);
      if (!atual) return [];
      return [
        {
          sistema: s.sistema,
          jogoId: s.jogoId,
          titulo: s.titulo,
          ...resumoVersao(atual),
          versoesGuardadas: s.versoes.length,
        },
      ];
    }),
  });
});

/** DELETE /api/saves?sistema=ps2&jogoId=… — apaga o save deste jogo da nuvem (todas as versões). */
export const DELETE = rota(async (req) => {
  const { perfil } = await autenticarPerfil(req);
  const e = consulta(req, jogoSchema);
  const save = await db.save.findUnique({
    where: { perfilId_sistema_jogoId: { perfilId: perfil.id, sistema: e.sistema, jogoId: e.jogoId } },
    include: { versoes: { select: { chave: true } } },
  });
  if (!save) throw new Erro(404, "sem_save", "Não há save deste jogo na nuvem.");
  await db.save.delete({ where: { id: save.id } });
  await apagar(save.versoes.map((v) => v.chave).filter(Boolean)).catch((err) =>
    console.error("[saves] apagar", err),
  );
  return json({ ok: true });
});
