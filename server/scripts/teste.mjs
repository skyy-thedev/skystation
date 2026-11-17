#!/usr/bin/env node
// Teste de ponta a ponta: finge ser dois consoles e passa por todas as rotas.
//   1) suba o servidor (npm run dev)   2) npm run teste
// Usa SKY_URL (padrão http://localhost:3000) e SKY_CONVITE (ou o do .env).
import "dotenv/config";
import { createHash, randomBytes } from "node:crypto";

const BASE = (process.env.SKY_URL || "http://localhost:3000").replace(/\/$/, "");
const CONVITE = process.env.SKY_CONVITE;
let passos = 0;

function ok(cond, msg) {
  if (!cond) throw new Error("FALHOU: " + msg);
  passos++;
  console.log("  ok  " + msg);
}

async function api(metodo, caminho, { token, perfil, corpo } = {}) {
  const r = await fetch(BASE + caminho, {
    method: metodo,
    headers: {
      ...(corpo !== undefined ? { "Content-Type": "application/json" } : {}),
      ...(token ? { Authorization: "Bearer " + token } : {}),
      ...(perfil ? { "X-Perfil": perfil } : {}),
    },
    body: corpo !== undefined ? JSON.stringify(corpo) : undefined,
  });
  let dados = null;
  try {
    dados = await r.json();
  } catch {}
  return { status: r.status, dados };
}

const tokens = [];
try {
  console.log("Servidor: " + BASE);
  const saude = await api("GET", "/api/saude");
  ok(saude.status === 200 && saude.dados.ok, "servidor e banco no ar");

  // ---------------------------------------------------------------- registro
  ok((await api("POST", "/api/consoles", { corpo: { nome: "X", convite: "errado" } })).status === 403, "convite errado é recusado");
  ok((await api("GET", "/api/eu")).status === 401, "sem token = 401");
  ok((await api("GET", "/api/eu", { token: "sky_inventado" })).status === 401, "token inventado = 401");

  const ra = await api("POST", "/api/consoles", { corpo: { nome: "Teste A", convite: CONVITE } });
  ok(ra.status === 201 && ra.dados.token, "console A registrado");
  const rb = await api("POST", "/api/consoles", { corpo: { nome: "Teste B", convite: CONVITE } });
  ok(rb.status === 201, "console B registrado");
  const A = { token: ra.dados.token, perfil: "p1" };
  const B = { token: rb.dados.token, perfil: "p1" };
  tokens.push(A.token, B.token);

  ok((await api("POST", "/api/sync", { ...A, corpo: {} })).status === 404, "perfil ainda não enviado = 404");
  const pa = await api("PUT", "/api/perfis", { token: A.token, corpo: { perfis: [{ localId: "p1", apelido: "Sky", cor: "#4fd1ff" }, { localId: "p2", apelido: "Visita" }] } });
  ok(pa.status === 200 && pa.dados.perfis.length === 2 && /^[A-Z0-9]{6}$/.test(pa.dados.perfis[0].codigo), "perfis de A criados, com código de amigo");
  const pb = await api("PUT", "/api/perfis", { token: B.token, corpo: { perfis: [{ localId: "p1", apelido: "Bart" }] } });
  const codA = pa.dados.perfis[0].codigo, idA = pa.dados.perfis[0].id;
  const codB = pb.dados.perfis[0].codigo, idB = pb.dados.perfis[0].id;
  const pa2 = await api("PUT", "/api/perfis", { token: A.token, corpo: { perfis: [{ localId: "p1", apelido: "Sky 2" }] } });
  ok(pa2.dados.perfis[0].apelido === "Sky 2" && pa2.dados.perfis[0].codigo === codA && pa2.dados.perfis.length === 2, "renomear mantém o código e os outros perfis");
  ok((await api("PUT", "/api/perfis", { token: A.token, corpo: { perfis: [] } })).status === 400, "dados inválidos = 400");

  // ---------------------------------------------------------------- amigos
  ok((await api("POST", "/api/amigos", { ...A, corpo: { codigo: codA } })).status === 400, "não dá para adicionar a si mesmo");
  ok((await api("POST", "/api/amigos", { ...A, corpo: { codigo: "ZZZZZZ" } })).status === 404, "código inexistente = 404");
  ok((await api("POST", "/api/mensagens", { ...A, corpo: { paraId: idB, texto: "oi" } })).status === 403, "mensagem para quem não é amigo = 403");
  const ped = await api("POST", "/api/amigos", { ...A, corpo: { codigo: codB.toLowerCase() } });
  ok(ped.status === 201 && ped.dados.status === "pendente", "A pede amizade a B (código em minúsculas vale)");
  ok((await api("POST", `/api/amigos/${ped.dados.amizadeId}/aceitar`, { ...A })).status === 404, "quem pediu não pode aceitar o próprio pedido");
  let sb = await api("POST", "/api/sync", { ...B, corpo: {} });
  ok(sb.dados.pedidosRecebidos.length === 1 && sb.dados.pedidosRecebidos[0].de.apelido === "Sky 2", "B vê o pedido no sync");
  ok((await api("POST", `/api/amigos/${ped.dados.amizadeId}/aceitar`, { ...B })).status === 200, "B aceita");

  // ---------------------------------------------------------------- presença
  await api("POST", "/api/presenca", { ...A, corpo: { status: "jogando", jogoId: "ps2-gow2", jogo: "God of War II", sistema: "ps2" } });
  sb = await api("POST", "/api/sync", { ...B, corpo: { presenca: { status: "online" } } });
  ok(sb.dados.amigos.length === 1 && sb.dados.amigos[0].status === "jogando" && sb.dados.amigos[0].jogo === "God of War II", "B vê A jogando God of War II");
  let sa = await api("POST", "/api/sync", { ...A, corpo: {} });
  ok(sa.dados.amigos[0].status === "online" && sa.dados.amigos[0].jogo === null, "A vê B online");
  await api("PUT", "/api/perfis", { token: A.token, corpo: { perfis: [{ localId: "p1", apelido: "Sky 2", invisivel: true }] } });
  sb = await api("POST", "/api/sync", { ...B, corpo: {} });
  ok(sb.dados.amigos[0].status === "offline" && sb.dados.amigos[0].jogo === null && sb.dados.amigos[0].vistoEm === null, "invisível aparece como offline, sem jogo");
  await api("PUT", "/api/perfis", { token: A.token, corpo: { perfis: [{ localId: "p1", apelido: "Sky 2", invisivel: false }] } });
  ok((await api("POST", "/api/presenca", { ...A, corpo: { status: "dormindo" } })).status === 400, "status inválido = 400");

  // ---------------------------------------------------------------- mensagens
  const marca = sb.dados.agora;
  const m1 = await api("POST", "/api/mensagens", { ...A, corpo: { paraId: idB, texto: "Bora jogar?" } });
  ok(m1.status === 201, "A envia mensagem");
  await api("POST", "/api/mensagens", { ...A, corpo: { paraId: idB, tipo: "convite", texto: "Entra aí", jogoId: "ps2-gow2", jogo: "God of War II", sistema: "ps2" } });
  ok((await api("POST", "/api/mensagens", { ...A, corpo: { paraId: idB, texto: "x".repeat(281) } })).status === 400, "mensagem com mais de 280 caracteres = 400");
  sb = await api("POST", "/api/sync", { ...B, corpo: { desde: marca } });
  ok(sb.dados.mensagens.length === 2 && sb.dados.naoLidas === 2 && sb.dados.mensagens[1].tipo === "convite" && sb.dados.mensagens[1].jogo === "God of War II", "B recebe mensagem e convite no sync");
  const lidas = await api("POST", "/api/mensagens/lidas", { ...B, corpo: { deId: idA } });
  ok(lidas.dados.marcadas === 2, "B marca como lidas");
  sb = await api("POST", "/api/sync", { ...B, corpo: { desde: sb.dados.agora } });
  ok(sb.dados.naoLidas === 0, "nenhuma não lida depois disso");
  const conv = await api("GET", `/api/mensagens?com=${idA}`, { ...B });
  ok(conv.dados.mensagens.length === 2 && conv.dados.mensagens[0].minha === false && conv.dados.mensagens[0].lida, "histórico da conversa");

  // ---------------------------------------------------------------- troféus
  const t1 = await api("POST", "/api/trofeus", { ...A, corpo: { trofeus: [{ trofeu: "primeira-partida", nome: "Primeira partida", tipo: "bronze" }, { trofeu: "maratonista", nome: "Maratonista", tipo: "ouro" }] } });
  ok(t1.dados.novos === 2, "A registra 2 troféus");
  const t2 = await api("POST", "/api/trofeus", { ...A, corpo: { trofeus: [{ trofeu: "maratonista", tipo: "ouro" }] } });
  ok(t2.dados.novos === 0, "troféu repetido não conta de novo");
  sb = await api("POST", "/api/sync", { ...B, corpo: {} });
  ok(sb.dados.trofeus.length === 2 && sb.dados.trofeus[0].de.apelido === "Sky 2", "B vê os troféus de A");
  ok((await api("GET", `/api/trofeus?perfil=${idA}`, { ...B })).dados.trofeus.length === 2, "B compara troféus com A");

  // ---------------------------------------------------------------- mesmo perfil em dois consoles
  const cod = await api("POST", "/api/perfis/codigo", { ...A });
  ok(cod.status === 200 && /^[A-Z0-9]{8}$/.test(cod.dados.codigo), "A gera o código para usar o perfil em outro console");
  ok((await api("POST", "/api/perfis/vincular", { token: B.token, corpo: { localId: "p2", codigo: "ZZZZZZZZ" } })).status === 404, "código de vínculo errado = 404");
  ok((await api("POST", "/api/perfis/vincular", { token: A.token, corpo: { localId: "p3", codigo: cod.dados.codigo } })).status === 400, "não dá para vincular no próprio console");
  const vinc = await api("POST", "/api/perfis/vincular", { token: B.token, corpo: { localId: "p2", codigo: cod.dados.codigo.toLowerCase() } });
  ok(vinc.status === 200 && vinc.dados.perfil.id === idA, "B vincula o perfil de A como seu p2");
  ok((await api("POST", "/api/perfis/vincular", { token: B.token, corpo: { localId: "p3", codigo: cod.dados.codigo } })).status === 404, "o código de vínculo só vale uma vez");
  const euB = await api("GET", "/api/eu", { token: B.token });
  const p2 = euB.dados.perfis.find((x) => x.localId === "p2");
  ok(euB.dados.perfis.length === 2 && p2.vinculado === true && p2.codigo === codA, "B agora tem dois perfis: o dele e o vinculado");
  const A2 = { token: B.token, perfil: "p2" }; // o jogador A, sentado no console B
  const sA2 = await api("POST", "/api/sync", { ...A2, corpo: {} });
  ok(sA2.dados.eu.id === idA && sA2.dados.amigos.length === 1 && sA2.dados.amigos[0].id === idB, "no console B, o perfil vinculado vê os amigos de A");
  const pv = await api("PUT", "/api/perfis", { token: B.token, corpo: { perfis: [{ localId: "p1", apelido: "Bart" }, { localId: "p2", apelido: "Outro nome" }] } });
  ok(pv.dados.perfis.find((x) => x.localId === "p2").apelido === "Sky 2", "o console B não renomeia o perfil vinculado");

  // ---------------------------------------------------------------- saves na nuvem
  if (!saude.dados.saves) {
    console.log("  --  armazenamento não configurado: testes de save pulados");
    ok((await api("GET", "/api/saves", { ...A })).status === 200, "lista de saves responde mesmo sem armazenamento");
  } else {
    const jogo = { sistema: "ps2", jogoId: "ps2-God of War II (USA)" };
    const q = `sistema=${jogo.sistema}&jogoId=${encodeURIComponent(jogo.jogoId)}`;
    const arq = (n) => { const b = randomBytes(n); return { b, hash: createHash("sha256").update(b).digest("hex"), tamanho: n }; };
    const enviar = async (quem, f, baseVersao, extra = {}) => {
      const r = await api("POST", "/api/saves/enviar", { ...quem, corpo: { ...jogo, titulo: "God of War II", hash: f.hash, tamanho: f.tamanho, baseVersao, ...extra } });
      if (r.dados?.estado !== "enviar") return r;
      const put = await fetch(r.dados.url, { method: "PUT", body: f.b });
      if (!put.ok) throw new Error("PUT no armazenamento falhou: " + put.status + " " + (await put.text()));
      const c = await api("POST", "/api/saves/confirmar", { ...quem, corpo: { versaoId: r.dados.versaoId } });
      return { status: c.status, dados: { ...r.dados, ...c.dados } };
    };

    ok((await api("GET", `/api/saves/baixar?${q}`, { ...A })).status === 404, "sem save na nuvem = 404");
    const f1 = arq(4096);
    const e1 = await enviar(A, f1, 0);
    ok(e1.status === 200 && e1.dados.versao === 1, "primeiro envio vira a versão 1");
    const igual = await api("POST", "/api/saves/enviar", { ...A, corpo: { ...jogo, hash: f1.hash, tamanho: f1.tamanho, baseVersao: 1 } });
    ok(igual.dados.estado === "igual", "mesmo conteúdo = nada a enviar");
    const d1 = await api("GET", `/api/saves/baixar?${q}`, { ...A });
    const baixado = Buffer.from(await (await fetch(d1.dados.url)).arrayBuffer());
    ok(d1.dados.versao === 1 && baixado.equals(f1.b), "download devolve o mesmo arquivo");

    const f2 = arq(5000);
    const conf = await api("POST", "/api/saves/enviar", { ...A, corpo: { ...jogo, hash: f2.hash, tamanho: f2.tamanho, baseVersao: 0 } });
    ok(conf.status === 409 && conf.dados.erro === "conflito" && conf.dados.nuvem.versao === 1, "base desatualizada = conflito, com os dados da nuvem");
    const e2 = await enviar(A, f2, 0, { forcar: true });
    ok(e2.dados.versao === 2, "forçar resolve o conflito (versão 2)");

    // envio que nunca chega não vira a versão atual
    const f3 = arq(100);
    const pend = await api("POST", "/api/saves/enviar", { ...A, corpo: { ...jogo, hash: f3.hash, tamanho: f3.tamanho, baseVersao: 2 } });
    ok((await api("POST", "/api/saves/confirmar", { ...A, corpo: { versaoId: pend.dados.versaoId } })).status === 409, "confirmar sem o arquivo = 409");
    // arquivo com tamanho diferente do declarado é rejeitado
    const f4 = arq(200);
    const errado = await api("POST", "/api/saves/enviar", { ...A, corpo: { ...jogo, hash: f4.hash, tamanho: 999, baseVersao: 2 } });
    await fetch(errado.dados.url, { method: "PUT", body: f4.b });
    ok((await api("POST", "/api/saves/confirmar", { ...A, corpo: { versaoId: errado.dados.versaoId } })).status === 400, "tamanho diferente do declarado = rejeitado");
    ok((await api("GET", `/api/saves/baixar?${q}`, { ...A })).dados.versao === 2, "a versão atual continua sendo a 2");

    const dB = await api("GET", `/api/saves/baixar?${q}`, { ...A2 });
    ok(dB.status === 200 && dB.dados.versao === 2 && dB.dados.hash === f2.hash, "no console B, o perfil vinculado baixa o save de A");
    const fB = arq(777);
    ok((await api("POST", "/api/saves/enviar", { ...A2, corpo: { ...jogo, hash: fB.hash, tamanho: fB.tamanho, baseVersao: 0 } })).status === 409, "console B com save próprio e base 0 = conflito");
    const eB = await enviar(A2, fB, 2);
    ok(eB.dados.versao > 2 && (await api("GET", `/api/saves/baixar?${q}`, { ...A })).dados.console === "Teste B", "B envia uma versão nova e A vê que veio do console B");

    let ultima = eB.dados.versao;
    for (let i = 0; i < 5; i++) ultima = (await enviar(A, arq(300 + i), ultima)).dados.versao;
    const vs = await api("GET", `/api/saves/versoes?${q}`, { ...A });
    ok(vs.dados.versoes.length === 5 && vs.dados.versaoAtual === ultima && vs.dados.versoes[0].versao === ultima, "só as 5 últimas versões ficam guardadas");
    ok((await api("GET", `/api/saves/baixar?${q}&versao=2`, { ...A })).status === 404, "a versão 2 já foi descartada");
    const antiga = vs.dados.versoes[4].versao;
    ok((await api("GET", `/api/saves/baixar?${q}&versao=${antiga}`, { ...A })).status === 200, "dá para baixar uma versão antiga guardada");

    const lista = await api("GET", "/api/saves", { ...A });
    ok(lista.dados.saves.length === 1 && lista.dados.saves[0].jogoId === jogo.jogoId && lista.dados.saves[0].console === "Teste A", "lista de saves do perfil");
    ok((await api("GET", "/api/saves", { ...B })).dados.saves.length === 0, "B não vê os saves de A");
    ok((await api("GET", `/api/saves/baixar?${q}`, { ...B })).status === 404, "B não baixa os saves de A");
    ok((await api("POST", "/api/saves/enviar", { ...A, corpo: { ...jogo, hash: f1.hash, tamanho: 999999999, baseVersao: ultima } })).status === 413, "save acima do limite = 413");
    ok((await api("DELETE", `/api/saves?${q}`, { ...A })).status === 200, "apagar o save da nuvem");
    ok((await api("GET", "/api/saves", { ...A })).dados.saves.length === 0, "lista vazia depois de apagar");
  }

  ok((await api("DELETE", "/api/perfis/vincular?localId=p2", { token: B.token })).status === 200, "B desfaz o vínculo");
  ok((await api("POST", "/api/sync", { ...A2, corpo: {} })).status === 404, "sem vínculo, o p2 de B não existe mais");

  // ---------------------------------------------------------------- desfazer amizade
  ok((await api("DELETE", `/api/amigos/${ped.dados.amizadeId}`, { ...B })).status === 200, "B desfaz a amizade");
  sa = await api("POST", "/api/sync", { ...A, corpo: {} });
  ok(sa.dados.amigos.length === 0, "A não vê mais B");
} catch (e) {
  console.error("\n" + e.message);
  process.exitCode = 1;
} finally {
  for (const token of tokens) await api("DELETE", "/api/eu", { token });
  if (tokens.length) {
    const r = await api("GET", "/api/eu", { token: tokens[0] });
    if (r.status !== 401) { console.error("FALHOU: console de teste não foi removido"); process.exitCode = 1; }
    else console.log("  ok  consoles de teste removidos");
  }
}
console.log(process.exitCode ? `\nParou depois de ${passos} passos.` : `\nTudo certo: ${passos} verificações.`);
