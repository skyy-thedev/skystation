#!/usr/bin/env node
// Fotos do site num navegador de verdade (Chromium): cria um jogador de mentira, abre as páginas e
// imprime cada PNG em base64 no log, entre marcadores (=== FOTO nome === ... === FIM ===).
//   SKY_URL=http://localhost:3000 SKY_CONVITE=... node scripts/fotos.mjs
import { chromium } from "playwright";
import { randomBytes } from "node:crypto";

const BASE = (process.env.SKY_URL || "http://localhost:3000").replace(/\/$/, "");
const CONVITE = process.env.SKY_CONVITE;
const api = async (metodo, caminho, corpo, cab = {}) => {
  const r = await fetch(BASE + caminho, {
    method: metodo,
    headers: { ...(corpo ? { "Content-Type": "application/json" } : {}), ...cab },
    body: corpo ? JSON.stringify(corpo) : undefined,
  });
  return { status: r.status, dados: await r.json().catch(() => null), cookie: r.headers.get("set-cookie") };
};

const s = randomBytes(2).toString("hex");
const id = `sky_${s}`, idAmigo = `bart_${s}`;
const tokens = [];
const browser = await chromium.launch(process.env.CHROME_PATH ? { executablePath: process.env.CHROME_PATH } : {});
try {
  const c1 = await api("POST", "/api/consoles", { nome: "Fotos 1", convite: CONVITE });
  const c2 = await api("POST", "/api/consoles", { nome: "Fotos 2", convite: CONVITE });
  tokens.push(c1.dados.token, c2.dados.token);
  const A = { Authorization: `Bearer ${c1.dados.token}`, "X-Perfil": "p1" };
  const B = { Authorization: `Bearer ${c2.dados.token}`, "X-Perfil": "p1" };
  await api("PUT", "/api/perfis", { perfis: [{ localId: "p1", apelido: "Sky" }] }, { Authorization: A.Authorization });
  await api("PUT", "/api/perfis", { perfis: [{ localId: "p1", apelido: "Bart" }] }, { Authorization: B.Authorization });
  await api("POST", "/api/conta", { usuario: id, senha: "senha-fotos" }, A);
  await api("POST", "/api/conta", { usuario: idAmigo, senha: "senha-fotos" }, B);
  await api("PATCH", "/api/conta", { avatar: "cometa", bio: "Jogando PS2 todo dia. Platinando God of War.", visibilidade: "publico" }, A);
  await api("PATCH", "/api/conta", { avatar: "raposa" }, B);
  const codB = (await api("POST", "/api/sync", {}, B)).dados.eu.codigo;
  const ped = await api("POST", "/api/amigos", { codigo: codB }, A);
  await api("POST", `/api/amigos/${ped.dados.amizadeId}/aceitar`, undefined, B);
  await api("POST", "/api/presenca", { status: "jogando", jogoId: "ps2-gow2", jogo: "God of War II", sistema: "ps2" }, A);
  await api("POST", "/api/trofeus", { trofeus: [
    { trofeu: "maratonista", nome: "Maratonista", tipo: "ouro" },
    { trofeu: "primeira", nome: "Primeira partida", tipo: "bronze" },
    { trofeu: "colecionador", nome: "Colecionador", tipo: "prata" },
    { jogoId: "ps2-gow2", jogo: "God of War II", trofeu: "titan", nome: "Modo Titã", tipo: "platina" },
    { jogoId: "ps2-sotc", jogo: "Shadow of the Colossus (USA)", trofeu: "colosso1", nome: "Primeiro colosso", tipo: "bronze" },
    { jogoId: "ps1-crash", jogo: "Crash Bandicoot", trofeu: "gemas", nome: "Todas as gemas", tipo: "ouro" },
    { jogoId: "n64-sm64", jogo: "Super Mario 64", trofeu: "estrelas", nome: "120 estrelas", tipo: "platina" },
  ] }, A);
  // o amigo jogando outro jogo e com troféus próprios (página inicial com várias capas)
  await api("POST", "/api/presenca", { status: "jogando", jogoId: "x360-halo3", jogo: "Halo 3", sistema: "x360" }, B);
  await api("POST", "/api/trofeus", { trofeus: [
    { jogoId: "x360-halo3", jogo: "Halo 3", trofeu: "lenda", nome: "Lendário", tipo: "ouro" },
    { jogoId: "ps1-ff7", jogo: "Final Fantasy VII (Disc 1)", trofeu: "materia", nome: "Mestre das matérias", tipo: "prata" },
  ] }, B);

  async function foto(nome, caminho, { largura = 1280, altura = 860, logado = false } = {}) {
    const ctx = await browser.newContext({ viewport: { width: largura, height: altura }, deviceScaleFactor: 1 });
    if (logado) {
      const r = await ctx.request.post(BASE + "/api/web/entrar", { data: { usuario: id, senha: "senha-fotos" } });
      if (!r.ok()) throw new Error("login falhou " + r.status());
      // o cookie é Secure; no teste local (http) ele vai à mão
      const m = /sky_sessao=([^;]+)/.exec(r.headers()["set-cookie"] || "");
      await ctx.addCookies([{ name: "sky_sessao", value: m[1], url: BASE }]);
    }
    const pg = await ctx.newPage();
    const resp = await pg.goto(BASE + caminho, { waitUntil: "networkidle" });
    const png = await pg.screenshot({ fullPage: true });
    console.log(`=== FOTO ${nome} (${resp.status()}) ===`);
    console.log(png.toString("base64"));
    console.log("=== FIM ===");
    await ctx.close();
  }
  await foto("inicio", "/");
  await foto("inicio-logado", "/", { logado: true });
  await foto("inicio-celular", "/", { largura: 390, altura: 844, logado: true });
  await foto("jogo", "/jogo/ps2/ps2-gow2", { logado: true });
  await foto("jogo-catalogo", "/jogo/ps2/ps2-god-of-war-2");
  await foto("entrar", "/entrar", { altura: 700 });
  await foto("criar-conta", "/criar-conta");
  await foto("perfil", `/u/${id}`, { logado: true });
  await foto("perfil-celular", `/u/${id}`, { largura: 390, altura: 844 });
  await foto("conta", "/conta", { logado: true });
  await api("PATCH", "/api/conta", { visibilidade: "privado" }, A);
  await foto("perfil-privado", `/u/${id}`, { altura: 500 });
} finally {
  await browser.close();
  for (const [usuario, tok] of [[id, tokens[0]], [idAmigo, tokens[1]]]) {
    const l = await api("POST", "/api/web/entrar", { usuario, senha: "senha-fotos" });
    const c = /sky_sessao=([^;]+)/.exec(l.cookie || "");
    if (c) await api("DELETE", "/api/web/eu", { senha: "senha-fotos" }, { Cookie: `sky_sessao=${c[1]}` });
    if (tok) await api("DELETE", "/api/eu", undefined, { Authorization: `Bearer ${tok}` });
  }
}
