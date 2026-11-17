import { EMULADORES, jogoDoCatalogo } from "./catalogo";
import { db } from "./db";
import { infoJogo, SISTEMAS, type InfoJogo } from "./jogos";
import { OFFLINE_APOS_MS } from "./rede";

// Dados da página inicial e da página de cada jogo.
// Regra de privacidade: só entra a atividade de perfis que quem está vendo poderia abrir no site
// (o próprio, os públicos e os amigos com perfil "só amigos"). "Invisível" esconde o jogo atual.

export type Jogador = { usuario: string | null; apelido: string; avatar: string };
type Visivel = Jogador & { id: string; invisivel: boolean };

export type ItemJogo = {
  chave: string;
  jogoId: string;
  sistema: string;
  info: InfoJogo;
  href: string;
  legenda: string;
  jogadores: Jogador[];
  trofeu?: { nome: string; tipo: string };
};

/** Perfis cuja atividade `eu` pode ver. */
export async function perfisVisiveis(eu: { id: string } | null) {
  const amigos = new Set<string>();
  if (eu) {
    const lista = await db.amizade.findMany({
      where: { status: "aceita", OR: [{ aId: eu.id }, { bId: eu.id }] },
      select: { aId: true, bId: true },
    });
    for (const a of lista) amigos.add(a.aId === eu.id ? a.bId : a.aId);
  }
  const perfis = await db.perfil.findMany({
    where: {
      OR: [
        { visibilidade: "publico" },
        ...(eu ? [{ id: eu.id }, { visibilidade: "amigos", id: { in: [...amigos] } }] : []),
      ],
    },
    select: { id: true, usuario: true, apelido: true, avatar: true, invisivel: true },
  });
  return new Map<string, Visivel>(perfis.map((p) => [p.id, p]));
}

const publico = (p: Visivel): Jogador => ({ usuario: p.usuario, apelido: p.apelido, avatar: p.avatar });

export function hrefJogo(sistema: string, jogoId: string) {
  return `/jogo/${encodeURIComponent(sistema || "outro")}/${encodeURIComponent(jogoId)}`;
}

/** "ps2-gow2" → "ps2" quando o registro não traz o sistema. */
function sistemaDoId(jogoId: string) {
  const prefixo = /^([a-z0-9]+)[-_]/.exec(jogoId)?.[1];
  return prefixo && SISTEMAS[prefixo] ? prefixo : "";
}

function haQuanto(d: Date) {
  const min = Math.round((Date.now() - d.getTime()) / 60000);
  if (min < 60) return min <= 1 ? "agora há pouco" : `há ${min} min`;
  const h = Math.round(min / 60);
  if (h < 24) return `há ${h} h`;
  const dias = Math.round(h / 24);
  return dias === 1 ? "ontem" : dias < 30 ? `há ${dias} dias` : d.toLocaleDateString("pt-BR", { day: "2-digit", month: "short", timeZone: "America/Sao_Paulo" });
}

function nomes(js: Jogador[]) {
  if (js.length === 1) return js[0].apelido;
  if (js.length === 2) return `${js[0].apelido} e ${js[1].apelido}`;
  return `${js[0].apelido} e mais ${js.length - 1}`;
}

/** Busca as fichas de vários jogos de uma vez (sem repetir o mesmo jogo). */
async function fichas(lista: { titulo: string; sistema: string }[]) {
  const unicos = new Map<string, Promise<InfoJogo>>();
  for (const j of lista) {
    const k = `${j.sistema}|${j.titulo}`;
    if (!unicos.has(k)) unicos.set(k, infoJogo(j.titulo, j.sistema));
  }
  const prontos = new Map<string, InfoJogo>();
  await Promise.all([...unicos].map(async ([k, p]) => prontos.set(k, await p)));
  return (titulo: string, sistema: string) => prontos.get(`${sistema}|${titulo}`)!;
}

export async function vitrine(eu: { id: string } | null, { comFichas = true } = {}) {
  const vis = await perfisVisiveis(eu);
  const ids = [...vis.keys()];
  const agora = Date.now();
  const inicioMes = new Date(new Date().toLocaleString("en-US", { timeZone: "America/Sao_Paulo" }));
  inicioMes.setDate(1);
  inicioMes.setHours(0, 0, 0, 0);
  // o "1º do mês" acima está no relógio de Brasília; volta para UTC (+3 h)
  const inicioMesUtc = new Date(inicioMes.getTime() + 3 * 60 * 60 * 1000);

  const [presencas, saves, trofeus, novos, platinasMes, trofeusMes] = await Promise.all([
    db.presenca.findMany({
      where: { perfilId: { in: ids }, status: "jogando", vistoEm: { gte: new Date(agora - OFFLINE_APOS_MS) } },
      orderBy: { desde: "desc" },
    }),
    db.save.findMany({
      where: { perfilId: { in: ids } },
      orderBy: { atualizadoEm: "desc" },
      take: 60,
      select: { perfilId: true, sistema: true, jogoId: true, titulo: true, atualizadoEm: true },
    }),
    db.trofeuGanho.findMany({
      where: { perfilId: { in: ids } },
      orderBy: { ganhoEm: "desc" },
      take: 40,
      select: { perfilId: true, jogoId: true, jogo: true, trofeu: true, nome: true, tipo: true, ganhoEm: true },
    }),
    db.perfil.count({ where: { usuario: { not: null }, criadoEm: { gte: inicioMesUtc } } }),
    db.trofeuGanho.findMany({
      where: { perfilId: { in: ids }, tipo: "platina", ganhoEm: { gte: inicioMesUtc } },
      orderBy: { ganhoEm: "desc" },
      select: { perfilId: true, jogo: true, jogoId: true, nome: true },
    }),
    db.trofeuGanho.groupBy({
      by: ["perfilId"],
      where: { perfilId: { in: ids }, ganhoEm: { gte: inicioMesUtc } },
      _count: { _all: true },
      orderBy: { _count: { perfilId: "desc" } },
      take: 1,
    }),
  ]);

  // sistema de cada jogo, pelo que já se sabe dos saves e da presença
  const sistemaDe = new Map<string, string>();
  for (const s of saves) sistemaDe.set(s.jogoId, s.sistema);
  for (const p of presencas) if (p.jogoId && p.sistema) sistemaDe.set(p.jogoId, p.sistema);
  const sis = (jogoId: string) => sistemaDe.get(jogoId) ?? sistemaDoId(jogoId);

  // --- jogando agora (agrupado por jogo)
  const agoraMap = new Map<string, { jogoId: string; titulo: string; sistema: string; jogadores: Jogador[] }>();
  for (const p of presencas) {
    const perfil = vis.get(p.perfilId);
    if (!perfil || !p.jogoId || (perfil.invisivel && perfil.id !== eu?.id)) continue;
    const k = `${p.sistema ?? ""}|${p.jogoId}`;
    const item = agoraMap.get(k) ?? { jogoId: p.jogoId, titulo: p.jogo || p.jogoId, sistema: p.sistema ?? sis(p.jogoId), jogadores: [] };
    item.jogadores.push(publico(perfil));
    agoraMap.set(k, item);
  }
  const jogandoBruto = [...agoraMap.values()].sort((a, b) => b.jogadores.length - a.jogadores.length);

  // --- jogados recentemente (saves + troféus de jogos)
  const recMap = new Map<string, { jogoId: string; titulo: string; sistema: string; quando: Date; jogadores: Map<string, Jogador> }>();
  const anotar = (perfilId: string, jogoId: string, titulo: string, sistema: string, quando: Date) => {
    const perfil = vis.get(perfilId);
    if (!perfil || jogoId === "skystation") return;
    const k = `${sistema}|${jogoId}`;
    const item = recMap.get(k) ?? { jogoId, titulo, sistema, quando, jogadores: new Map() };
    if (quando > item.quando) item.quando = quando;
    item.jogadores.set(perfilId, publico(perfil));
    recMap.set(k, item);
  };
  for (const s of saves) anotar(s.perfilId, s.jogoId, s.titulo || s.jogoId, s.sistema, s.atualizadoEm);
  for (const t of trofeus) anotar(t.perfilId, t.jogoId, t.jogo || t.jogoId, sis(t.jogoId), t.ganhoEm);
  const recentesBruto = [...recMap.values()].sort((a, b) => b.quando.getTime() - a.quando.getTime()).slice(0, 12);

  const trofeusBruto = trofeus.filter((t) => vis.has(t.perfilId)).slice(0, 12);

  const semFicha = (titulo: string): InfoJogo => ({ nome: titulo, capa: null, arte: null, resumo: null, ano: null, generos: [], fonte: null, link: null });
  const ficha = !comFichas ? semFicha : await fichas([
    ...jogandoBruto.map((j) => ({ titulo: j.titulo, sistema: j.sistema })),
    ...recentesBruto.map((j) => ({ titulo: j.titulo, sistema: j.sistema })),
    ...trofeusBruto.filter((t) => t.jogoId !== "skystation").map((t) => ({ titulo: t.jogo || t.jogoId, sistema: sis(t.jogoId) })),
  ]);

  const jogando: ItemJogo[] = jogandoBruto.map((j) => ({
    chave: `agora-${j.sistema}-${j.jogoId}`,
    jogoId: j.jogoId,
    sistema: j.sistema,
    info: ficha(j.titulo, j.sistema),
    href: hrefJogo(j.sistema, j.jogoId),
    legenda: `${nomes(j.jogadores)} ${j.jogadores.length > 1 ? "estão jogando" : "está jogando"}`,
    jogadores: j.jogadores,
  }));
  const recentes: ItemJogo[] = recentesBruto.map((j) => {
    const jogadores = [...j.jogadores.values()];
    return {
      chave: `rec-${j.sistema}-${j.jogoId}`,
      jogoId: j.jogoId,
      sistema: j.sistema,
      info: ficha(j.titulo, j.sistema),
      href: hrefJogo(j.sistema, j.jogoId),
      legenda: `${nomes(jogadores)} · ${haQuanto(j.quando)}`,
      jogadores,
    };
  });
  const trofeusRecentes: ItemJogo[] = trofeusBruto.map((t) => {
    const perfil = publico(vis.get(t.perfilId)!);
    const doConsole = t.jogoId === "skystation";
    const sistema = doConsole ? "sky" : sis(t.jogoId);
    return {
      chave: `trof-${t.perfilId}-${t.jogoId}-${t.trofeu}`,
      jogoId: t.jogoId,
      sistema,
      info: doConsole
        ? { nome: "SkyStation", capa: null, arte: null, resumo: null, ano: null, generos: [], fonte: null, link: null }
        : ficha(t.jogo || t.jogoId, sistema),
      href: doConsole ? (perfil.usuario ? `/u/${perfil.usuario}` : "/") : hrefJogo(sistema, t.jogoId),
      legenda: `${perfil.apelido} · ${haQuanto(t.ganhoEm)}`,
      jogadores: [perfil],
      trofeu: { nome: t.nome || t.trofeu, tipo: t.tipo },
    };
  });

  // --- destaque do banner: o jogo com mais gente agora; senão, o último jogado
  const destaque = jogando[0]
    ? { ...jogando[0], selo: "Jogando agora" }
    : recentes[0]
      ? { ...recentes[0], selo: "Jogado recentemente" }
      : null;

  const cacadorPerfil = trofeusMes[0] ? vis.get(trofeusMes[0].perfilId) : null;
  const mes = {
    nome: new Date().toLocaleDateString("pt-BR", { month: "long", timeZone: "America/Sao_Paulo" }),
    platinas: platinasMes.length,
    ultimaPlatina: platinasMes[0]
      ? { jogo: platinasMes[0].jogo || platinasMes[0].jogoId, de: vis.get(platinasMes[0].perfilId)?.apelido ?? "" }
      : null,
    novosMembros: novos,
    cacador: cacadorPerfil ? { ...publico(cacadorPerfil), total: trofeusMes[0]._count._all } : null,
  };

  return { destaque, jogando, recentes, trofeus: trofeusRecentes, mes };
}

/** Página de um jogo: ficha + quem joga + troféus ganhos nele (só dos perfis visíveis). */
export async function paginaJogo(sistema: string, jogoId: string, eu: { id: string } | null) {
  const catalogo = jogoDoCatalogo(sistema, jogoId);
  const [save, pres, trof] = catalogo ? [null, null, null] : await Promise.all([
    db.save.findFirst({ where: { jogoId, ...(sistema !== "outro" ? { sistema } : {}) }, select: { titulo: true }, orderBy: { atualizadoEm: "desc" } }),
    db.presenca.findFirst({ where: { jogoId }, select: { jogo: true } }),
    db.trofeuGanho.findFirst({ where: { jogoId }, select: { jogo: true } }),
  ]);
  const titulo = catalogo?.nome || save?.titulo || pres?.jogo || trof?.jogo;
  if (!titulo) return null;

  const vis = await perfisVisiveis(eu);
  const ids = [...vis.keys()];
  const [info, saves, presencas, trofeus] = await Promise.all([
    infoJogo(titulo, sistema === "outro" ? "" : sistema),
    db.save.findMany({ where: { jogoId, perfilId: { in: ids } }, select: { perfilId: true, atualizadoEm: true } }),
    db.presenca.findMany({
      where: { jogoId, perfilId: { in: ids }, status: "jogando", vistoEm: { gte: new Date(Date.now() - OFFLINE_APOS_MS) } },
      select: { perfilId: true },
    }),
    db.trofeuGanho.findMany({
      where: { jogoId, perfilId: { in: ids } },
      orderBy: { ganhoEm: "desc" },
      select: { perfilId: true, trofeu: true, nome: true, tipo: true, ganhoEm: true },
    }),
  ]);
  const agora = new Set(
    presencas.map((p) => p.perfilId).filter((id) => !vis.get(id)!.invisivel || id === eu?.id),
  );
  const ultima = new Map<string, Date>();
  for (const s of saves) ultima.set(s.perfilId, s.atualizadoEm);
  for (const t of trofeus) if (!ultima.has(t.perfilId) || ultima.get(t.perfilId)! < t.ganhoEm) ultima.set(t.perfilId, t.ganhoEm);
  for (const id of agora) ultima.set(id, new Date());
  const jogadores = [...ultima]
    .sort((a, b) => b[1].getTime() - a[1].getTime())
    .map(([id, quando]) => ({
      ...publico(vis.get(id)!),
      legenda: agora.has(id) ? "Jogando agora" : `Jogou ${haQuanto(quando)}`,
      agora: agora.has(id),
      trofeus: trofeus.filter((t) => t.perfilId === id).length,
    }));
  return {
    info,
    catalogo,
    emulador: EMULADORES.find((e) => e.sistema === (catalogo?.sistema ?? sistema)) ?? null,
    sistema: sistema === "outro" ? "" : sistema,
    jogadores,
    trofeus: trofeus.map((t) => ({ ...t, de: publico(vis.get(t.perfilId)!) })),
  };
}
