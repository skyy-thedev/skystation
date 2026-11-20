// SkyStore: publicar pelo navegador (painel /admin/loja), sem terminal. Tudo roda no computador de quem publica:
// o .tar.gz é montado aqui, o sha256 calculado aqui e a assinatura Ed25519 feita aqui com a chave privada,
// que é lida do arquivo .pem escolhido e NUNCA é enviada ao servidor (fica só na memória desta aba).

export type ArquivoPacote = { caminho: string; dados: Uint8Array };

const enc = new TextEncoder();

function campo(h: Uint8Array, texto: string, pos: number, tam: number) {
  const b = enc.encode(texto);
  if (b.length > tam) throw new Error(`Nome longo demais no pacote: ${texto}`);
  h.set(b, pos);
}

function octal(n: number, tam: number) {
  return n.toString(8).padStart(tam - 1, "0") + "\0";
}

/** Cabeçalho ustar (512 bytes). Caminhos acima de 100 bytes usam o campo "prefix" (até 255 no total). */
function cabecalho(caminho: string, tamanho: number, mtime: number) {
  const h = new Uint8Array(512);
  let nome = caminho;
  let prefixo = "";
  if (enc.encode(caminho).length > 100) {
    const corte = caminho.lastIndexOf("/", 155);
    if (corte <= 0) throw new Error(`Caminho longo demais no pacote: ${caminho}`);
    prefixo = caminho.slice(0, corte);
    nome = caminho.slice(corte + 1);
  }
  campo(h, nome, 0, 100);
  campo(h, "0000644\0", 100, 8);
  campo(h, "0000000\0", 108, 8);
  campo(h, "0000000\0", 116, 8);
  campo(h, octal(tamanho, 12), 124, 12);
  campo(h, octal(mtime, 12), 136, 12);
  campo(h, "        ", 148, 8); // soma ainda em branco
  campo(h, "0", 156, 1); // arquivo comum
  campo(h, "ustar\0", 257, 6);
  campo(h, "00", 263, 2);
  campo(h, "skystation", 265, 32);
  campo(h, "skystation", 297, 32);
  campo(h, prefixo, 345, 155);
  let soma = 0;
  for (const b of h) soma += b;
  campo(h, soma.toString(8).padStart(6, "0") + "\0 ", 148, 8);
  return h;
}

/** Monta um .tar.gz (ustar + gzip do próprio navegador). */
export async function tarGz(arquivos: ArquivoPacote[]): Promise<Uint8Array> {
  const mtime = Math.floor(Date.now() / 1000);
  const partes: Uint8Array[] = [];
  for (const a of [...arquivos].sort((x, y) => x.caminho.localeCompare(y.caminho))) {
    partes.push(cabecalho(a.caminho, a.dados.length, mtime), a.dados);
    const resto = a.dados.length % 512;
    if (resto) partes.push(new Uint8Array(512 - resto));
  }
  partes.push(new Uint8Array(1024)); // fim do tar: dois blocos zerados
  const tar = new Blob(partes as BlobPart[]);
  const gz = tar.stream().pipeThrough(new CompressionStream("gzip"));
  return new Uint8Array(await new Response(gz).arrayBuffer());
}

/** Lê a pasta escolhida (input webkitdirectory), sem o cache do Godot; exige game.json na raiz da pasta. */
export async function lerPasta(lista: FileList): Promise<ArquivoPacote[]> {
  const arquivos: ArquivoPacote[] = [];
  for (const f of Array.from(lista)) {
    const caminho = (f as File & { webkitRelativePath: string }).webkitRelativePath || f.name;
    const partes = caminho.split("/");
    if (partes.some((p) => p === ".godot" || p === ".git" || p === "node_modules") || caminho.endsWith(".import")) continue;
    arquivos.push({ caminho, dados: new Uint8Array(await f.arrayBuffer()) });
  }
  const raiz = arquivos[0]?.caminho.split("/")[0];
  if (!raiz || !arquivos.some((a) => a.caminho === `${raiz}/game.json`)) {
    throw new Error("A pasta escolhida precisa ter o game.json dentro (escolha a pasta do jogo, ex.: deadzone).");
  }
  return arquivos;
}

export async function sha256Hex(dados: Uint8Array) {
  const h = new Uint8Array(await crypto.subtle.digest("SHA-256", dados as BufferSource));
  return Array.from(h, (b) => b.toString(16).padStart(2, "0")).join("");
}

function pemParaDer(pem: string) {
  const b64 = pem.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  if (!b64) throw new Error("Esse arquivo não parece uma chave .pem.");
  const bin = atob(b64);
  return Uint8Array.from(bin, (c) => c.charCodeAt(0));
}

function b64(bytes: Uint8Array) {
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s);
}

async function importar(pem: string, extraivel: boolean) {
  if (!pem.includes("PRIVATE KEY")) throw new Error("Escolha a chave PRIVADA (chave-privada.pem), não a pública.");
  try {
    return await crypto.subtle.importKey("pkcs8", pemParaDer(pem) as BufferSource, { name: "Ed25519" }, extraivel, ["sign"]);
  } catch {
    throw new Error("Não consegui ler a chave (navegador sem Ed25519 ou arquivo errado). Use Chrome, Edge ou Firefox atualizados.");
  }
}

/** Assina o texto da SkyStore; devolve a assinatura em base64 (64 bytes). */
export async function assinar(pem: string, mensagem: string) {
  const chave = await importar(pem, false);
  return b64(new Uint8Array(await crypto.subtle.sign({ name: "Ed25519" }, chave, enc.encode(mensagem))));
}

/** A chave PÚBLICA (32 bytes em base64) que corresponde à privada: a da Vercel e do console. */
export async function chavePublicaDe(pem: string) {
  const chave = await importar(pem, true);
  const jwk = await crypto.subtle.exportKey("jwk", chave);
  const x = (jwk.x ?? "").replace(/-/g, "+").replace(/_/g, "/");
  return x + "=".repeat((4 - (x.length % 4)) % 4);
}

export function mensagemAssinada(slug: string, versao: string, sha256: string, tamanho: number) {
  return `skystation-loja-v1\n${slug}\n${versao}\n${sha256}\n${tamanho}`;
}
