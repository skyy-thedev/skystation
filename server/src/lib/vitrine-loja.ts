import { db } from "./db";
import { compararVersoes, ultimaPublicada } from "./loja";

// SkyStore no site (Fase 12, etapa 3): a mesma regra da API — só itens publicados que têm uma versão
// enviada e publicada aparecem. Nada de URL de download aqui: baixar é só pelo console (que confere
// a assinatura).

export const NOMES_TIPO: Record<string, string> = { app: "App", jogo: "Jogo", tema: "Tema", emulador: "Emulador" };
export const CORES_TIPO: Record<string, string> = { app: "#2b6cb0", jogo: "#9b2c2c", tema: "#6b46c1", emulador: "#2f855a" };

export function tamanhoLegivel(b: number) {
  return b >= 1e9 ? `${(b / 1e9).toFixed(1).replace(".", ",")} GB` : `${Math.max(1, Math.round(b / 1e6))} MB`;
}

export async function itensDaLoja() {
  const itens = await db.lojaItem.findMany({
    where: { publicado: true },
    include: { versoes: { where: { publicada: true, enviada: true } } },
    orderBy: [{ oficial: "desc" }, { atualizadoEm: "desc" }],
  });
  return itens
    .map(({ versoes, ...i }) => {
      const v = ultimaPublicada(versoes);
      return v ? { ...i, versao: v.versao, tamanho: Number(v.tamanho), publicadaEm: v.criadaEm } : null;
    })
    .filter((x): x is NonNullable<typeof x> => x !== null);
}

export async function itemDaLoja(slug: string) {
  const item = await db.lojaItem.findUnique({
    where: { slug },
    include: { versoes: { where: { publicada: true, enviada: true } } },
  });
  if (!item || !item.publicado || !item.versoes.length) return null;
  const { versoes, ...resto } = item;
  return {
    ...resto,
    versoes: versoes
      .sort((a, b) => compararVersoes(b.versao, a.versao))
      .map((v) => ({ versao: v.versao, notas: v.notas, tamanho: Number(v.tamanho), criadaEm: v.criadaEm })),
  };
}
