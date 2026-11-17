import { unstable_cache } from "next/cache";

// Capa, arte e ficha dos jogos, buscadas na internet e guardadas no cache do Next (7 dias).
//
// Fontes, nesta ordem:
//   1. IGDB (base de jogos da Twitch): capa, arte larga para o banner, ano, gêneros e resumo em inglês.
//      Só entra se IGDB_CLIENT_ID e IGDB_CLIENT_SECRET estiverem configurados (app grátis em dev.twitch.tv).
//   2. Wikipédia em português: resumo em português e a imagem da página (quase sempre a capa).
//   3. Wikipédia em inglês: o mesmo, quando não há página em português.
// Sem nada encontrado, o site mostra uma capa gerada (cor do sistema + nome).

export const SISTEMAS: Record<string, string> = {
  ps1: "PS1", ps2: "PS2", ps3: "PS3", psp: "PSP", vita: "PS Vita", x360: "Xbox 360", snes: "SNES", n64: "N64",
  gc: "GameCube", wii: "Wii", nds: "DS", "3ds": "3DS", gba: "GBA", gb: "Game Boy", nes: "NES", md: "Mega Drive",
};

/** Cor de cada sistema (capa gerada e etiqueta). */
export const CORES_SISTEMA: Record<string, string> = {
  ps1: "#8a96ad", ps2: "#2d5bd7", ps3: "#1d1f2b", psp: "#3a3f55", vita: "#1f6fd1", x360: "#3b9b2c",
  snes: "#6c5bb5", n64: "#d13a3a", gc: "#5b3fa8", wii: "#9aa7b8", nds: "#5d6b7e", "3ds": "#c8323b",
  gba: "#4b3d9e", gb: "#7d8b4a", nes: "#b23a3a", md: "#1b1b1b",
};

// nomes que a Wikipédia e a IGDB usam para cada sistema (ajudam a achar o jogo certo)
const PLATAFORMA: Record<string, { igdb: number; wiki: string }> = {
  ps1: { igdb: 7, wiki: "PlayStation" }, ps2: { igdb: 8, wiki: "PlayStation 2" }, ps3: { igdb: 9, wiki: "PlayStation 3" },
  psp: { igdb: 38, wiki: "PlayStation Portable" }, vita: { igdb: 46, wiki: "PlayStation Vita" },
  x360: { igdb: 12, wiki: "Xbox 360" }, snes: { igdb: 19, wiki: "Super Nintendo" }, n64: { igdb: 4, wiki: "Nintendo 64" },
  gc: { igdb: 21, wiki: "GameCube" }, wii: { igdb: 5, wiki: "Wii" }, nds: { igdb: 20, wiki: "Nintendo DS" },
  "3ds": { igdb: 37, wiki: "Nintendo 3DS" }, gba: { igdb: 24, wiki: "Game Boy Advance" }, gb: { igdb: 33, wiki: "Game Boy" },
  nes: { igdb: 18, wiki: "Nintendo Entertainment System" }, md: { igdb: 29, wiki: "Mega Drive" },
};

export type InfoJogo = {
  nome: string; // nome limpo (sem região, disco…)
  capa: string | null; // imagem em pé
  arte: string | null; // imagem larga para o banner (se não houver, o banner usa a capa desfocada)
  resumo: string | null;
  ano: number | null;
  generos: string[];
  fonte: "igdb" | "wikipedia" | null;
  link: string | null; // página de onde veio o resumo
};

export function nomeSistema(s: string | null | undefined) {
  return s ? SISTEMAS[s] ?? s.toUpperCase() : "";
}

/** "God of War II (USA) [!] (Disc 1).iso" → "God of War II" */
export function limparNome(bruto: string) {
  return bruto
    .replace(/\.(iso|bin|cue|chd|cso|pbp|zip|7z|xex|z64|n64|sfc|smc|nds|gba|md|nes|rvz|wbfs)$/i, "")
    .replace(/[([][^)\]]*[)\]]/g, " ") // (USA), [!], (Disc 1), (v1.01)…
    .replace(/[_]+/g, " ")
    .replace(/\s+-\s*$/g, "")
    .replace(/\s+/g, " ")
    .trim();
}

const UA = "SkyNetwork/1.0 (site do SkyStation; https://skyntwk.vercel.app)";
const TEMPO = 5000;

async function json(url: string, init: RequestInit = {}) {
  const r = await fetch(url, {
    ...init,
    headers: { "User-Agent": UA, Accept: "application/json", ...(init.headers ?? {}) },
    signal: AbortSignal.timeout(TEMPO),
    cache: "no-store", // quem guarda é o unstable_cache, com o resultado já montado
  });
  if (!r.ok) throw new Error(`${url} → ${r.status}`);
  return r.json();
}

// ---------------------------------------------------------------- IGDB

let tokenIgdb: { valor: string; expira: number } | null = null;

async function tokenTwitch() {
  const id = process.env.IGDB_CLIENT_ID, segredo = process.env.IGDB_CLIENT_SECRET;
  if (!id || !segredo) return null;
  if (tokenIgdb && tokenIgdb.expira > Date.now() + 60_000) return { id, token: tokenIgdb.valor };
  const q = new URLSearchParams({ client_id: id, client_secret: segredo, grant_type: "client_credentials" });
  const d = await json(`https://id.twitch.tv/oauth2/token?${q}`, { method: "POST" });
  tokenIgdb = { valor: d.access_token, expira: Date.now() + (d.expires_in ?? 3600) * 1000 };
  return { id, token: tokenIgdb.valor };
}

type JogoIgdb = {
  name: string; summary?: string; first_release_date?: number; url?: string;
  genres?: { name: string }[]; cover?: { image_id: string }; artworks?: { image_id: string }[];
  screenshots?: { image_id: string }[];
};

async function buscarIgdb(nome: string, sistema: string): Promise<Partial<InfoJogo> | null> {
  const t = await tokenTwitch();
  if (!t) return null;
  const busca = nome.replace(/"/g, "");
  const campos = "fields name,summary,first_release_date,url,genres.name,cover.image_id,artworks.image_id,screenshots.image_id;";
  const plat = PLATAFORMA[sistema]?.igdb;
  const pedir = (onde: string) =>
    json("https://api.igdb.com/v4/games", {
      method: "POST",
      headers: { "Client-ID": t.id, Authorization: `Bearer ${t.token}`, "Content-Type": "text/plain" },
      body: `search "${busca}"; ${campos} ${onde} limit 5;`,
    }) as Promise<JogoIgdb[]>;
  let lista = plat ? await pedir(`where platforms = (${plat});`) : [];
  if (!lista.length) lista = await pedir("");
  // prefere o nome idêntico; senão, o primeiro da busca
  const alvo = normalizar(nome);
  const j = lista.find((x) => normalizar(x.name) === alvo) ?? lista[0];
  if (!j) return null;
  const img = (id: string | undefined, tam: string) => (id ? `https://images.igdb.com/igdb/image/upload/${tam}/${id}.jpg` : null);
  return {
    nome: j.name,
    capa: img(j.cover?.image_id, "t_cover_big_2x"),
    arte: img(j.artworks?.[0]?.image_id ?? j.screenshots?.[0]?.image_id, "t_1080p"),
    resumo: j.summary ?? null,
    ano: j.first_release_date ? new Date(j.first_release_date * 1000).getUTCFullYear() : null,
    generos: (j.genres ?? []).map((g) => g.name).slice(0, 3),
    link: j.url ?? null,
    fonte: "igdb",
  };
}

// ---------------------------------------------------------------- Wikipédia

const PALAVRAS_JOGO = /jogo|videogame|video game|vídeo game|eletrônico|electronic game/i;

async function buscarWikipedia(nome: string, sistema: string, lingua: "pt" | "en"): Promise<Partial<InfoJogo> | null> {
  const base = `https://${lingua}.wikipedia.org`;
  const plataforma = PLATAFORMA[sistema]?.wiki ?? "";
  const termo = `${nome} ${lingua === "pt" ? "jogo eletrônico" : "video game"} ${plataforma}`.trim();
  const q = new URLSearchParams({ action: "query", list: "search", srsearch: termo, srlimit: "5", format: "json", origin: "*" });
  const achados: { title: string }[] = (await json(`${base}/w/api.php?${q}`)).query?.search ?? [];
  const alvo = normalizar(nome);
  // títulos parecidos com o nome vêm primeiro ("God of War II" antes de "God of War (série)")
  const ordem = [...achados].sort((a, b) => parecenca(b.title, alvo) - parecenca(a.title, alvo));
  for (const { title } of ordem.slice(0, 3)) {
    if (parecenca(title, alvo) === 0) continue;
    const r = await json(`${base}/api/rest_v1/page/summary/${encodeURIComponent(title.replace(/ /g, "_"))}`).catch(() => null);
    if (!r || r.type === "disambiguation") continue;
    const texto = `${r.description ?? ""} ${r.extract ?? ""}`;
    if (!PALAVRAS_JOGO.test(texto)) continue;
    const ano = /\b(19[7-9]\d|20[0-4]\d)\b/.exec(r.extract ?? "")?.[1];
    return {
      capa: r.originalimage?.source ?? r.thumbnail?.source ?? null,
      resumo: resumir(r.extract ?? ""),
      ano: ano ? Number(ano) : null,
      link: r.content_urls?.desktop?.page ?? `${base}/wiki/${encodeURIComponent(title)}`,
      fonte: "wikipedia",
    };
  }
  return null;
}

/** As 3 primeiras frases (o resumo da Wikipédia às vezes tem um parágrafo enorme). */
function resumir(t: string) {
  const frases = t.replace(/\s+/g, " ").trim().match(/[^.!?]+[.!?]+(\s|$)/g) ?? [t];
  return frases.slice(0, 3).join("").trim() || null;
}

export function normalizar(s: string) {
  return s
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .replace(/\(.*?\)/g, " ")
    .replace(/[^a-z0-9]+/g, " ")
    .trim();
}

/** 0 = nada a ver; quanto maior, mais parecido o título da página com o nome do jogo. */
function parecenca(titulo: string, alvo: string) {
  const t = normalizar(titulo);
  if (t === alvo) return 3;
  if (t.startsWith(alvo) || alvo.startsWith(t)) return 2;
  const palavras = alvo.split(" ").filter((p) => p.length > 2);
  const comuns = palavras.filter((p) => t.includes(p)).length;
  return palavras.length && comuns / palavras.length >= 0.6 ? 1 : 0;
}

// ---------------------------------------------------------------- junta tudo

async function montar(nome: string, sistema: string): Promise<InfoJogo> {
  let falhas = 0;
  const seguro = <T,>(p: Promise<T>) => p.catch(() => { falhas++; return null; });
  const [igdb, pt] = await Promise.all([seguro(buscarIgdb(nome, sistema)), seguro(buscarWikipedia(nome, sistema, "pt"))]);
  const en = !pt && !igdb?.resumo ? await seguro(buscarWikipedia(nome, sistema, "en")) : null;
  // tudo deu erro de rede: não guarda o "nada" no cache por 7 dias (tenta de novo na próxima visita)
  if (!igdb && !pt && !en && falhas >= 2) throw new Error("sem acesso às fontes de jogos");
  const wiki = pt ?? en;
  return {
    nome: igdb?.nome ?? nome,
    capa: igdb?.capa ?? wiki?.capa ?? null,
    arte: igdb?.arte ?? null,
    // resumo em português primeiro
    resumo: pt?.resumo ?? igdb?.resumo ?? en?.resumo ?? null,
    ano: igdb?.ano ?? wiki?.ano ?? null,
    generos: igdb?.generos ?? [],
    fonte: pt ? "wikipedia" : igdb ? "igdb" : en ? "wikipedia" : null,
    link: pt?.link ?? igdb?.link ?? en?.link ?? null,
  };
}

const emCache = unstable_cache(montar, ["sky-jogo-v1"], { revalidate: 7 * 24 * 60 * 60, tags: ["jogos"] });

const VAZIO = (nome: string): InfoJogo => ({
  nome, capa: null, arte: null, resumo: null, ano: null, generos: [], fonte: null, link: null,
});

/** Ficha do jogo pelo título que o console mandou. Nunca falha: sem internet, volta só o nome. */
export async function infoJogo(titulo: string | null | undefined, sistema: string | null | undefined): Promise<InfoJogo> {
  const nome = limparNome(titulo ?? "");
  if (!nome) return VAZIO(titulo ?? "");
  if (process.env.SKY_SEM_BUSCA_JOGOS === "1") return VAZIO(nome);
  try {
    return await emCache(nome, sistema ?? "");
  } catch {
    return VAZIO(nome);
  }
}
