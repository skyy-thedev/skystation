import { z } from "zod";
import { autenticar, novoCodigo } from "@/lib/auth";
import { db } from "@/lib/db";
import { corpo, Erro, json, rota } from "@/lib/http";

const entrada = z.object({
  perfis: z
    .array(
      z.object({
        localId: z.string().regex(/^[a-z0-9]{1,8}$/),
        apelido: z.string().trim().min(1).max(24),
        cor: z.string().regex(/^#[0-9a-fA-F]{6}$/).optional(),
        invisivel: z.boolean().optional(),
      }),
    )
    .min(1)
    .max(4),
});

/**
 * PUT /api/perfis — o console envia os perfis locais (do sky-perfis). Cria os novos e atualiza
 * apelido/cor/invisível dos que já existem. Perfis que sumiram do console NÃO são apagados
 * (os saves na nuvem continuam lá).
 */
export const PUT = rota(async (req) => {
  const console_ = await autenticar(req);
  const { perfis } = await corpo(req, entrada);

  for (const p of perfis) {
    const chave = { consoleId_localId: { consoleId: console_.id, localId: p.localId } };
    const mudancas = {
      apelido: p.apelido,
      ...(p.cor ? { cor: p.cor } : {}),
      ...(p.invisivel !== undefined ? { invisivel: p.invisivel } : {}),
    };
    const existe = await db.perfil.findUnique({ where: chave, select: { id: true } });
    if (existe) {
      await db.perfil.update({ where: chave, data: mudancas });
      continue;
    }
    // Código de amigo: sorteia de novo se, por azar, já existir (o banco garante que é único).
    for (let tentativa = 0; ; tentativa++) {
      try {
        await db.perfil.create({
          data: { consoleId: console_.id, localId: p.localId, codigo: novoCodigo(), ...mudancas },
        });
        break;
      } catch (e) {
        if ((e as { code?: string }).code !== "P2002" || tentativa >= 4) {
          throw tentativa >= 4 ? new Erro(500, "sem_codigo", "Não consegui gerar o código de amigo.") : e;
        }
      }
    }
  }

  const lista = await db.perfil.findMany({
    where: { consoleId: console_.id },
    orderBy: { localId: "asc" },
    select: { id: true, localId: true, apelido: true, cor: true, invisivel: true, codigo: true },
  });
  return json({ perfis: lista });
});
