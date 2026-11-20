import { createHash } from "node:crypto";
import { NextRequest } from "next/server";
import { db } from "@/lib/db";
import { Erro, json, rota } from "@/lib/http";
import { sessaoAdmin } from "@/lib/loja";
import { gravar } from "@/lib/storage";

/** Funções da Vercel aceitam corpo de até ~4,5 MB; acima disso o painel usa o envio direto ao R2. */
const LIMITE_PELO_SERVIDOR = 4 * 1024 * 1024;

/**
 * POST /api/admin/loja/versoes/arquivo?id=<versaoId> — envio pelo painel do site (sem terminal), para pacotes
 * pequenos. O corpo é o pacote. O servidor só grava se o tamanho e o sha256 forem os que foram ASSINADOS no passo 1
 * (a assinatura já foi conferida lá): ninguém troca o arquivo no meio do caminho.
 */
export const POST = rota(async (req: NextRequest) => {
  await sessaoAdmin(req);
  const id = req.nextUrl.searchParams.get("id") ?? "";
  const v = await db.lojaVersao.findUnique({ where: { id } });
  if (!v) throw new Erro(404, "versao_desconhecida", "Versão não encontrada.");
  if (v.enviada) throw new Erro(409, "ja_enviada", "Essa versão já foi enviada.");
  if (Number(v.tamanho) > LIMITE_PELO_SERVIDOR) {
    throw new Erro(413, "grande_demais", "Pacote grande: envie direto ao armazenamento (precisa do CORS no R2).");
  }
  const dados = new Uint8Array(await req.arrayBuffer());
  if (BigInt(dados.length) !== v.tamanho) throw new Erro(400, "tamanho_diferente", `Chegaram ${dados.length} bytes, eram ${v.tamanho}.`);
  const sha = createHash("sha256").update(dados).digest("hex");
  if (sha !== v.sha256) throw new Erro(400, "sha256_diferente", "O arquivo não é o que foi assinado.");
  await gravar(v.chave, dados);
  return json({ ok: true });
});
