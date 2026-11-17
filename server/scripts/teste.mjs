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
const contas = []; // [navegador, senha] para excluir no fim

/** Um "navegador": guarda o cookie de sessão do site entre as chamadas. */
function navegador() {
  let cookie = "";
  return async (metodo, caminho, corpo, extra = {}) => {
    const r = await fetch(BASE + caminho, {
      method: metodo,
      redirect: "manual",
      headers: {
        ...(corpo !== undefined ? { "Content-Type": "application/json" } : {}),
        ...(cookie ? { Cookie: cookie } : {}),
        ...extra,
      },
      body: corpo !== undefined ? JSON.stringify(corpo) : undefined,
    });
    const set = r.headers.get("set-cookie");
    if (set) {
      const m = /sky_sessao=([^;]*)/.exec(set);
      if (m) cookie = m[1] ? `sky_sessao=${m[1]}` : "";
    }
    const texto = await r.text();
    let dados = null;
    try { dados = JSON.parse(texto); } catch {}
    return { status: r.status, dados, texto, local: r.headers.get("location") };
  };
}
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

  // ---------------------------------------------------------------- contas pessoais e site
  const sufixo = randomBytes(3).toString("hex");
  const uA = `sky_${sufixo}`, uB = `bart_${sufixo}`, uC = `novo_${sufixo}`;
  const nA = navegador(), nB = navegador(), nC = navegador(), anonimo = navegador();
  ok((await api("POST", "/api/conta", { ...A, corpo: { usuario: "A!", senha: "segredo1" } })).status === 400, "ID com caractere inválido = 400");
  ok((await api("POST", "/api/conta", { ...A, corpo: { usuario: "admin", senha: "segredo1" } })).status === 409, "ID reservado = 409");
  ok((await api("POST", "/api/conta", { ...A, corpo: { usuario: uA, senha: "123" } })).status === 400, "senha curta = 400");
  const ca = await api("POST", "/api/conta", { ...A, corpo: { usuario: uA.toUpperCase(), senha: "segredo-A" } });
  ok(ca.status === 201 && ca.dados.conta.usuario === uA && ca.dados.conta.avatar === "estrela", "o perfil de A vira conta (ID em minúsculas, ícone padrão)");
  contas.push([nA, "segredo-A"]);
  ok((await api("POST", "/api/conta", { ...A, corpo: { usuario: uA + "x", senha: "segredo-A" } })).status === 409, "um perfil só tem uma conta");
  ok((await api("POST", "/api/conta", { ...B, corpo: { usuario: uA, senha: "segredo-B" } })).status === 409, "ID já usado = 409");
  ok((await api("POST", "/api/conta", { ...B, corpo: { usuario: uB, senha: "segredo-B" } })).status === 201, "B também cria conta");
  contas.push([nB, "segredo-B"]);

  ok((await nA("POST", "/api/web/entrar", { usuario: uA, senha: "errada" })).status === 401, "site: senha errada = 401");
  ok((await nA("GET", "/api/web/eu")).status === 401, "site: sem sessão = 401");
  const la = await nA("POST", "/api/web/entrar", { usuario: uA.toUpperCase(), senha: "segredo-A" });
  ok(la.status === 200, "site: A entra (ID sem diferenciar maiúsculas)");
  const euA = await nA("GET", "/api/web/eu");
  ok(euA.status === 200 && euA.dados.eu.usuario === uA && euA.dados.amigos.length === 1, "site: /api/web/eu traz a conta e os amigos");
  await nB("POST", "/api/web/entrar", { usuario: uB, senha: "segredo-B" });

  ok((await nA("PATCH", "/api/web/eu", { avatar: "dragao" })).status === 400, "ícone que não existe = 400");
  ok((await nA("PATCH", "/api/web/eu", { bio: "oi" }, { Origin: "https://site-malicioso.example" })).status === 403, "mudança vinda de outro site = 403");
  const pa3 = await nA("PATCH", "/api/web/eu", { avatar: "cometa", apelido: "Sky da Web", bio: "Jogo PS2 todo dia", visibilidade: "publico" });
  ok(pa3.status === 200 && pa3.dados.eu.avatar === "cometa", "site: muda ícone, nome, bio e visibilidade");
  await api("PUT", "/api/perfis", { token: A.token, corpo: { perfis: [{ localId: "p1", apelido: "Nome do console" }] } });
  let sbx = await api("POST", "/api/sync", { ...B, corpo: {} });
  const amigoA = sbx.dados.amigos.find((x) => x.id === euA.dados.eu.id);
  ok(amigoA && amigoA.avatar === "cometa" && amigoA.apelido === "Sky da Web" && amigoA.usuario === uA,
     "no console de B, o amigo aparece com o ícone e o nome da conta (o console não sobrescreve)");
  const pc = await api("PATCH", "/api/conta", { ...A, corpo: { avatar: "robo" } });
  ok(pc.status === 200 && pc.dados.conta.avatar === "robo", "o console também troca o ícone");

  // perfil no site: público, só amigos, privado, invisível
  await api("POST", "/api/presenca", { ...A, corpo: { status: "jogando", jogoId: "ps2-gow2", jogo: "God of War II", sistema: "ps2" } });
  let vp = await anonimo("GET", `/api/web/perfil/${uA}`);
  ok(vp.status === 200 && vp.dados.completo && vp.dados.jogo === "God of War II" && vp.dados.trofeus.total === 0 && vp.dados.amigos.length === 1,
     "público: qualquer um vê status, jogo, troféus e amigos");
  let html = await anonimo("GET", `/u/${uA}`);
  ok(html.status === 200 && html.texto.includes("Sky da Web") && html.texto.includes("God of War II") && html.texto.includes("/avatares/robo.svg"),
     "a página do perfil no site mostra nome, jogo e ícone");
  await nA("PATCH", "/api/web/eu", { invisivel: true });
  vp = await anonimo("GET", `/api/web/perfil/${uA}`);
  ok(vp.dados.status === "offline" && vp.dados.jogo === null, "invisível: ninguém vê o que está jogando");
  ok((await nA("GET", `/api/web/perfil/${uA}`)).dados.status === "jogando", "…menos o próprio dono");
  await nA("PATCH", "/api/web/eu", { invisivel: false, visibilidade: "amigos" });
  vp = await anonimo("GET", `/api/web/perfil/${uA}`);
  ok(vp.dados.completo === false && vp.dados.bio === undefined && vp.dados.apelido === "Sky da Web", "só amigos: visitante vê só nome e ícone");
  ok((await nB("GET", `/api/web/perfil/${uA}`)).dados.completo === true, "só amigos: o amigo B vê tudo");
  await nA("PATCH", "/api/web/eu", { visibilidade: "privado" });
  ok((await nB("GET", `/api/web/perfil/${uA}`)).dados.completo === false, "privado: nem o amigo vê");
  ok((await nA("GET", `/api/web/perfil/${uA}`)).dados.completo === true, "privado: o dono vê");
  html = await anonimo("GET", `/u/${uA}`);
  ok(html.status === 200 && html.texto.includes("Este perfil é privado") && !html.texto.includes("God of War II"), "a página respeita o privado");
  ok((await anonimo("GET", `/u/ninguem_${sufixo}`)).status === 404, "perfil que não existe = 404");
  ok((await anonimo("GET", "/")).status === 200 && (await anonimo("GET", "/entrar")).status === 200, "página inicial e de entrar no ar");
  const conta = await anonimo("GET", "/conta");
  ok([303, 307, 308].includes(conta.status) && (conta.local || "").includes("/entrar"), "/conta sem login manda para /entrar");
  ok((await nA("GET", "/conta")).texto.includes(uA), "/conta logado mostra a conta");

  // criar conta pelo site e entrar com ela num console
  ok((await nC("POST", "/api/web/registrar", { usuario: uC, senha: "segredo-C", apelido: "Caio", convite: "errado" })).status === 403, "site: convite errado = 403");
  const rc = await nC("POST", "/api/web/registrar", { usuario: uC, senha: "segredo-C", apelido: "Caio", avatar: "raposa", convite: CONVITE.toUpperCase() });
  ok(rc.status === 201 && (await nC("GET", "/api/web/eu")).dados.eu.avatar === "raposa", "site: cria conta sem console e já fica logado");
  contas.push([nC, "segredo-C"]);
  ok((await anonimo("POST", "/api/web/registrar", { usuario: uC, senha: "x123456", apelido: "X", convite: CONVITE })).status === 409, "site: ID repetido = 409");
  ok((await api("POST", "/api/perfis/entrar", { token: B.token, corpo: { localId: "p3", usuario: uC, senha: "errada1" } })).status === 401, "console: senha errada = 401");
  const ent = await api("POST", "/api/perfis/entrar", { token: B.token, corpo: { localId: "p3", usuario: uC, senha: "segredo-C" } });
  ok(ent.status === 200 && ent.dados.perfil.usuario === uC, "console B entra com a conta criada no site (perfil p3)");
  const euB3 = await api("GET", "/api/eu", { token: B.token });
  ok(euB3.dados.perfis.some((x) => x.localId === "p3" && x.vinculado && x.usuario === uC && x.avatar === "raposa"), "o p3 de B agora é a conta do site");
  ok((await api("POST", "/api/sync", { token: B.token, perfil: "p3", corpo: {} })).dados.eu.usuario === uC, "e sincroniza como ela");

  // senhas
  ok((await nA("POST", "/api/web/senha", { atual: "errada", nova: "nova-senha-A" })).status === 401, "trocar senha com a atual errada = 401");
  ok((await nA("POST", "/api/web/senha", { atual: "segredo-A", nova: "nova-senha-A" })).status === 200, "trocar senha pelo site");
  ok((await api("POST", "/api/conta/senha", { ...A, corpo: { senha: "pelo-console" } })).status === 200, "esqueci a senha: o console define outra");
  ok((await nA("GET", "/api/web/eu")).status === 401, "trocar pelo console encerra as sessões do site");
  ok((await nA("POST", "/api/web/entrar", { usuario: uA, senha: "pelo-console" })).status === 200, "entra com a senha nova");
  contas[0][1] = "pelo-console";

  // bloqueio depois de 5 erros (na conta C, que é só de teste)
  for (let i = 0; i < 5; i++) await anonimo("POST", "/api/web/entrar", { usuario: uC, senha: "errada" + i });
  ok((await anonimo("POST", "/api/web/entrar", { usuario: uC, senha: "segredo-C" })).status === 429, "5 senhas erradas bloqueiam por 15 minutos");

  // excluir conta
  ok((await nB("DELETE", "/api/web/eu", { senha: "errada" })).status === 401, "excluir conta pede a senha certa");

  // ---------------------------------------------------------------- desfazer amizade
  ok((await api("DELETE", `/api/amigos/${ped.dados.amizadeId}`, { ...B })).status === 200, "B desfaz a amizade");
  sa = await api("POST", "/api/sync", { ...A, corpo: {} });
  ok(sa.dados.amigos.length === 0, "A não vê mais B");
} catch (e) {
  console.error("\n" + e.message);
  process.exitCode = 1;
} finally {
  for (const token of tokens) await api("DELETE", "/api/eu", { token });
  // contas pessoais sobrevivem ao console: exclui pelo site (a C está bloqueada, então espera o
  // bloqueio só se precisar; ela ainda tem a sessão aberta da criação)
  for (const [nav, senha] of contas) {
    const r = await nav("DELETE", "/api/web/eu", { senha });
    if (r.status !== 200 && r.status !== 401) console.error("aviso: não consegui excluir uma conta de teste", r.status, r.dados);
  }
  if (tokens.length) {
    const r = await api("GET", "/api/eu", { token: tokens[0] });
    if (r.status !== 401) { console.error("FALHOU: console de teste não foi removido"); process.exitCode = 1; }
    else console.log("  ok  consoles de teste removidos");
  }
}
console.log(process.exitCode ? `\nParou depois de ${passos} passos.` : `\nTudo certo: ${passos} verificações.`);
