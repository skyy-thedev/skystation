import { z } from "zod";
import { db } from "./db";
import { Erro } from "./http";
import { sistemaSchema } from "./rede";

/** Quantas versões confirmadas de cada save ficam guardadas. */
export const VERSOES_GUARDADAS = 5;

export const jogoSchema = z.object({
  sistema: sistemaSchema,
  jogoId: z.string().min(1).max(200),
});

export function resumoVersao(v: {
  numero: number;
  hash: string;
  tamanho: number;
  criadaEm: Date;
  console: { nome: string } | null;
}) {
  return {
    versao: v.numero,
    hash: v.hash,
    tamanho: v.tamanho,
    enviadoEm: v.criadaEm,
    console: v.console?.nome ?? null,
  };
}

/** O save de um jogo com a versão pedida (ou a atual). Erro 404 se não houver. */
export async function acharVersao(perfilId: string, sistema: string, jogoId: string, versao?: number) {
  const save = await db.save.findUnique({
    where: { perfilId_sistema_jogoId: { perfilId, sistema, jogoId } },
  });
  const numero = versao ?? save?.versaoAtual ?? 0;
  const v =
    save && numero > 0
      ? await db.saveVersao.findFirst({
          where: { saveId: save.id, numero, confirmada: true },
          include: { console: { select: { nome: true } } },
        })
      : null;
  if (!save || !v) throw new Erro(404, "sem_save", "Não há save deste jogo na nuvem.");
  return { save, versao: v };
}
