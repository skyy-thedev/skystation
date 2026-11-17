import { z } from "zod";
import { autenticarPerfil } from "@/lib/auth";
import { db } from "@/lib/db";
import { corpo, Erro, json, rota } from "@/lib/http";
import { jogoSchema, resumoVersao } from "@/lib/saves";
import { tamanhoMaximo, urlEnvio } from "@/lib/storage";

const entrada = jogoSchema.extend({
  titulo: z.string().max(200).optional(),
  hash: z.string().regex(/^[0-9a-f]{64}$/, "hash deve ser um sha256 em hexadecimal"),
  tamanho: z.number().int().positive(),
  /** A versão da nuvem em que o save local se baseia (0 = este console nunca sincronizou o jogo). */
  baseVersao: z.number().int().min(0),
  /** true = "usar o save deste console" depois de um conflito. */
  forcar: z.boolean().optional(),
});

/**
 * POST /api/saves/enviar — passo 1 do envio. Responde uma destas:
 *   { estado: "igual" }    a nuvem já tem exatamente este save; nada a fazer
 *   { estado: "enviar", url, versaoId }   faça PUT do arquivo em `url` e depois /api/saves/confirmar
 *   409 conflito           a nuvem mudou desde a última sincronização deste console
 */
export const POST = rota(async (req) => {
  const { console: console_, perfil } = await autenticarPerfil(req);
  const e = await corpo(req, entrada);
  if (e.tamanho > tamanhoMaximo()) {
    throw new Erro(413, "save_grande", `O save passa do limite de ${process.env.SKY_SAVE_MAX_MB || 64} MB.`);
  }

  const chaveSave = { perfilId_sistema_jogoId: { perfilId: perfil.id, sistema: e.sistema, jogoId: e.jogoId } };
  const save = await db.save.upsert({
    where: chaveSave,
    create: { perfilId: perfil.id, sistema: e.sistema, jogoId: e.jogoId, titulo: e.titulo },
    update: e.titulo ? { titulo: e.titulo } : {},
  });

  const atual =
    save.versaoAtual > 0
      ? await db.saveVersao.findFirst({
          where: { saveId: save.id, numero: save.versaoAtual, confirmada: true },
          include: { console: { select: { nome: true } } },
        })
      : null;

  if (atual && atual.hash === e.hash) {
    return json({ estado: "igual", versao: atual.numero });
  }
  // Conflito: o console partiu de uma versão que não é mais a atual, ou seja, outro console
  // enviou um save diferente nesse meio-tempo. Não sobrescreve: devolve o que há na nuvem e o
  // jogador escolhe (baixar a da nuvem, ou reenviar com forcar: true).
  if (atual && !e.forcar && save.versaoAtual !== e.baseVersao) {
    throw new Erro(409, "conflito", "O save na nuvem mudou desde a última sincronização deste console.", {
      nuvem: resumoVersao(atual),
    });
  }

  const ultima = await db.saveVersao.aggregate({ where: { saveId: save.id }, _max: { numero: true } });
  const numero = (ultima._max.numero ?? 0) + 1;
  let versao;
  try {
    versao = await db.saveVersao.create({
      data: {
        saveId: save.id,
        numero,
        hash: e.hash,
        tamanho: e.tamanho,
        chave: "", // preenchida logo abaixo: a chave usa o id desta linha
        consoleId: console_.id,
      },
    });
  } catch (err) {
    if ((err as { code?: string }).code === "P2002") {
      throw new Erro(409, "envio_simultaneo", "Outro envio deste save começou agora. Tente de novo.");
    }
    throw err;
  }
  const chave = `saves/${save.id}/${versao.id}`;
  await db.saveVersao.update({ where: { id: versao.id }, data: { chave } });

  return json({
    estado: "enviar",
    versaoId: versao.id,
    versao: numero,
    metodo: "PUT",
    url: await urlEnvio(chave),
    expiraEmSegundos: 900,
  });
});
