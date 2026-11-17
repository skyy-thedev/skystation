import dados from "./catalogo.json";
import { infoJogo, type InfoJogo } from "./jogos";

// Catálogo do SkyStation: o que já foi testado e funciona (catalogo.json).

export type Situacao = "perfeito" | "jogavel" | "com-falhas";
export type JogoCatalogo = { id: string; nome: string; sistema: string; situacao: Situacao; nota?: string };
export type Emulador = { sistema: string; nome: string; emulador: string; situacao: string; destaques: string };

export const JOGOS = dados.jogos as JogoCatalogo[];
export const EMULADORES = dados.emuladores as Emulador[];
export const EM_BREVE = dados.emBreve as { sistema: string; nome: string; emulador: string }[];

export const SITUACOES: Record<Situacao, { rotulo: string; cor: string }> = {
  perfeito: { rotulo: "Perfeito", cor: "#54f0b8" },
  jogavel: { rotulo: "Jogável", cor: "#4fd1ff" },
  "com-falhas": { rotulo: "Com falhas", cor: "#ffcd46" },
};

export function jogoDoCatalogo(sistema: string, id: string) {
  return JOGOS.find((j) => j.id === id && (j.sistema === sistema || sistema === "outro")) ?? null;
}

export function hrefCatalogo(j: JogoCatalogo) {
  return `/jogo/${j.sistema}/${j.id}`;
}

export type JogoComFicha = JogoCatalogo & { info: InfoJogo };

/** Todos os jogos do catálogo com capa e ficha (buscadas em paralelo; ficam no cache). */
export async function catalogoComFichas(): Promise<JogoComFicha[]> {
  return Promise.all(JOGOS.map(async (j) => ({ ...j, info: await infoJogo(j.nome, j.sistema) })));
}

/** O destaque do banner muda a cada dia; prefere jogos com arte larga. */
export function destaqueDoDia(lista: JogoComFicha[]) {
  if (!lista.length) return null;
  const dia = Math.floor((Date.now() - 3 * 3600_000) / 86_400_000);
  const comArte = lista.filter((j) => j.info.arte);
  const base = comArte.length ? comArte : lista;
  return base[dia % base.length];
}
