#!/usr/bin/env node
// SkyStore (Fase 12): publicar apps e jogos assinados. Roda no PC do Sky (a chave privada nunca sai dele).
//
//   node scripts/loja.mjs chave                         cria o par de chaves (1x) e mostra a pública
//   node scripts/loja.mjs publica                       mostra a chave pública de novo
//   node scripts/loja.mjs item <slug> --tipo jogo --nome "Nome" [--resumo …] [--descricao …]
//                              [--autor …] [--capa https://…] [--oficial] [--publicar | --esconder]
//   node scripts/loja.mjs enviar <arquivo> <slug> <versao> [--notas "o que mudou"] [--publicar]
//   node scripts/loja.mjs publicar <slug> <versao>      |  despublicar <slug> <versao>
//   node scripts/loja.mjs lista
//
// Servidor: SKY_URL (padrão https://skyntwk.vercel.app). Login: SKY_USUARIO (o seu ID SkyNetwork, que
// precisa estar em SKY_ADMIN no servidor) e a senha (pergunta; ou SKY_SENHA). Chave privada:
// ~/.config/skystation-loja/chave-privada.pem (ou SKY_LOJA_CHAVE_PRIVADA).
import { createHash, createPrivateKey, createPublicKey, generateKeyPairSync, sign } from "node:crypto";
import { createReadStream, existsSync, mkdirSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import { createInterface } from "node:readline";

const BASE = (process.env.SKY_URL || "https://skyntwk.vercel.app").replace(/\/$/, "");
const CHAVE = process.env.SKY_LOJA_CHAVE_PRIVADA || join(homedir(), ".config/skystation-loja/chave-privada.pem");

function sair(msg) {
  console.error(msg);
  process.exit(1);
}

function opcoes(args) {
  const o = { _: [] };
  for (let i = 0; i < args.length; i++) {
    if (args[i].startsWith("--")) {
      const k = args[i].slice(2);
      if (i + 1 < args.length && !args[i + 1].startsWith("--")) o[k] = args[++i];
      else o[k] = true;
    } else o._.push(args[i]);
  }
  return o;
}

export function mensagemAssinada(slug, versao, sha256, tamanho) {
  return `skystation-loja-v1\n${slug}\n${versao}\n${sha256}\n${tamanho}`;
}

function publicaB64(privada) {
  const jwk = createPublicKey(privada).export({ format: "jwk" });
  return Buffer.from(jwk.x, "base64url").toString("base64");
}

function lerPrivada() {
  if (!existsSync(CHAVE)) sair(`Sem chave privada em ${CHAVE}. Rode: node scripts/loja.mjs chave`);
  return createPrivateKey(readFileSync(CHAVE));
}

async function sha256De(arquivo) {
  const h = createHash("sha256");
  for await (const parte of createReadStream(arquivo)) h.update(parte);
  return h.digest("hex");
}

function perguntar(texto) {
  return new Promise((ok) => {
    const rl = createInterface({ input: process.stdin, output: process.stderr });
    rl.question(texto, (r) => { rl.close(); ok(r); });
  });
}

let cookie = "";
async function api(metodo, caminho, corpo) {
  const r = await fetch(BASE + caminho, {
    method: metodo,
    headers: { ...(corpo ? { "Content-Type": "application/json" } : {}), ...(cookie ? { Cookie: cookie } : {}) },
    body: corpo ? JSON.stringify(corpo) : undefined,
  });
  const m = /sky_sessao=([^;]*)/.exec(r.headers.get("set-cookie") || "");
  if (m) cookie = `sky_sessao=${m[1]}`;
  let dados = null;
  try { dados = await r.json(); } catch {}
  if (!r.ok) sair(`${metodo} ${caminho}: ${r.status} ${dados?.mensagem || ""}`);
  return dados;
}

async function entrar() {
  const usuario = process.env.SKY_USUARIO || (await perguntar("ID SkyNetwork: "));
  const senha = process.env.SKY_SENHA || (await perguntar("Senha: "));
  await api("POST", "/api/web/entrar", { usuario, senha });
}

async function acharVersao(slug, versao) {
  const { itens } = await api("GET", "/api/admin/loja");
  const item = itens.find((i) => i.slug === slug);
  const v = item?.versoes.find((x) => x.versao === versao);
  if (!v) sair(`Não achei a versão ${versao} de ${slug}.`);
  return v;
}

const [cmd, ...resto] = process.argv.slice(2);
const o = opcoes(resto);

if (cmd === "chave") {
  if (existsSync(CHAVE)) sair(`Já existe uma chave em ${CHAVE} (apagar = os consoles param de aceitar os pacotes antigos).`);
  const { privateKey } = generateKeyPairSync("ed25519");
  mkdirSync(dirname(CHAVE), { recursive: true, mode: 0o700 });
  writeFileSync(CHAVE, privateKey.export({ format: "pem", type: "pkcs8" }), { mode: 0o600 });
  console.log(`Chave privada: ${CHAVE}  (guarde uma cópia num lugar seguro e NUNCA envie para o GitHub)`);
  console.log(`Chave pública (Vercel → SKY_LOJA_CHAVE_PUBLICA e console/bin/skyloja-chave.pub):\n${publicaB64(privateKey)}`);
} else if (cmd === "publica") {
  console.log(publicaB64(lerPrivada()));
} else if (cmd === "item") {
  const slug = o._[0];
  if (!slug || !o.tipo || !o.nome) sair("uso: item <slug> --tipo app|jogo|tema|emulador --nome \"Nome\" [...]");
  await entrar();
  const corpo = { slug, tipo: o.tipo, nome: o.nome };
  for (const k of ["resumo", "descricao", "autor", "capa"]) if (typeof o[k] === "string") corpo[k] = o[k];
  if (o.oficial) corpo.oficial = true;
  if (o.publicar) corpo.publicado = true;
  if (o.esconder) corpo.publicado = false;
  const { item } = await api("POST", "/api/admin/loja", corpo);
  console.log(`Item ${item.slug} salvo (${item.publicado ? "na vitrine" : "escondido"}).`);
} else if (cmd === "enviar") {
  const [arquivo, slug, versao] = o._;
  if (!arquivo || !slug || !versao) sair("uso: enviar <arquivo> <slug> <versao> [--notas …] [--publicar]");
  const privada = lerPrivada();
  const tamanho = statSync(arquivo).size;
  console.error("Calculando o sha256…");
  const sha256 = await sha256De(arquivo);
  const assinatura = sign(null, Buffer.from(mensagemAssinada(slug, versao, sha256, tamanho)), privada).toString("base64");
  await entrar();
  const ini = await api("POST", "/api/admin/loja/versoes", {
    slug, versao, sha256, tamanho, assinatura, ...(typeof o.notas === "string" ? { notas: o.notas } : {}),
  });
  console.error(`Enviando ${(tamanho / 1048576).toFixed(1)} MB…`);
  const put = await fetch(ini.url, {
    method: "PUT",
    headers: { "Content-Length": String(tamanho) },
    body: createReadStream(arquivo),
    duplex: "half",
  });
  if (!put.ok) sair(`Envio do arquivo falhou: ${put.status} ${await put.text()}`);
  const { versao: v } = await api("POST", "/api/admin/loja/versoes/confirmar", { id: ini.versaoId, publicar: !!o.publicar });
  console.log(`${slug} ${v.versao} enviada${v.publicada ? " e publicada" : " (ainda não publicada)"}.`);
} else if (cmd === "publicar" || cmd === "despublicar") {
  const [slug, versao] = o._;
  if (!slug || !versao) sair(`uso: ${cmd} <slug> <versao>`);
  await entrar();
  const v = await acharVersao(slug, versao);
  await api("PATCH", "/api/admin/loja/versoes", { id: v.id, publicada: cmd === "publicar" });
  console.log(`${slug} ${versao} ${cmd === "publicar" ? "publicada" : "fora do ar"}.`);
} else if (cmd === "lista") {
  await entrar();
  const { itens } = await api("GET", "/api/admin/loja");
  for (const i of itens) {
    console.log(`${i.publicado ? "●" : "○"} ${i.slug}  [${i.tipo}]  ${i.nome}  ·  ${i.downloads} downloads`);
    for (const v of i.versoes) console.log(`    ${v.versao}  ${v.publicada ? "publicada" : v.enviada ? "enviada" : "incompleta"}  ${(v.tamanho / 1048576).toFixed(1)} MB`);
  }
} else {
  sair("uso: node scripts/loja.mjs chave | publica | item | enviar | publicar | despublicar | lista  (detalhes no topo do arquivo)");
}
