import { createPublicKey, verify } from "node:crypto";
import type { NextRequest } from "next/server";
import { z } from "zod";
import { Erro } from "./http";
import { sessaoWeb } from "./web";

// SkyStore (Fase 12). Quem publica é só o Sky: o pacote é assinado no PC dele com a chave privada da
// loja (scripts/loja.mjs) e o servidor só guarda a assinatura. O console confere a assinatura com a
// chave pública antes de instalar: nem quem invadir o servidor ou o armazenamento consegue trocar
// um pacote por outro.

export const TIPOS = ["app", "jogo", "tema", "emulador"] as const;

export const slugSchema = z
  .string()
  .regex(/^[a-z0-9][a-z0-9-]{1,47}$/, "use 2 a 48 letras minúsculas, números ou -");
export const versaoSchema = z
  .string()
  .regex(/^\d{1,4}(\.\d{1,4}){0,3}(-[a-z0-9.]{1,16})?$/, "use algo como 1.0 ou 1.2.3");

/** O texto que é assinado: amarra o arquivo ao item e à versão (não dá para trocar um pelo outro). */
export function mensagemAssinada(slug: string, versao: string, sha256: string, tamanho: number | bigint) {
  return `skystation-loja-v1\n${slug}\n${versao}\n${sha256}\n${tamanho}`;
}

/** Chave pública da loja: 32 bytes em base64 (SKY_LOJA_CHAVE_PUBLICA). */
function chavePublica() {
  const b64 = process.env.SKY_LOJA_CHAVE_PUBLICA?.trim();
  if (!b64) throw new Erro(503, "loja_sem_chave", "A SkyStore ainda não tem a chave pública configurada (SKY_LOJA_CHAVE_PUBLICA).");
  const raw = Buffer.from(b64, "base64");
  if (raw.length !== 32) throw new Erro(503, "loja_chave_invalida", "SKY_LOJA_CHAVE_PUBLICA deve ter 32 bytes em base64.");
  return createPublicKey({ key: { kty: "OKP", crv: "Ed25519", x: raw.toString("base64url") }, format: "jwk" });
}

export function assinaturaValida(mensagem: string, assinaturaB64: string) {
  const sig = Buffer.from(assinaturaB64, "base64");
  if (sig.length !== 64) return false;
  return verify(null, Buffer.from(mensagem), chavePublica(), sig);
}

/** Quem pode publicar na loja: IDs SkyNetwork em SKY_ADMIN (separados por vírgula). */
export async function sessaoAdmin(req: NextRequest) {
  const perfil = await sessaoWeb(req);
  if (!ehAdmin(perfil.usuario)) throw new Erro(403, "nao_admin", "Só a equipe da SkyStation publica na SkyStore.");
  return perfil;
}

export function ehAdmin(usuario: string | null | undefined) {
  const lista = (process.env.SKY_ADMIN || "").split(",").map((s) => s.trim().toLowerCase()).filter(Boolean);
  return !!usuario && lista.includes(usuario.toLowerCase());
}

export const tamanhoMaximoLoja = () => Number(process.env.SKY_LOJA_MAX_MB || 4096) * 1024 * 1024;

type VersaoBanco = {
  id: string; versao: string; notas: string; tamanho: bigint; sha256: string; assinatura: string;
  enviada: boolean; publicada: boolean; criadaEm: Date;
};

export function versaoJson(v: VersaoBanco) {
  return {
    id: v.id, versao: v.versao, notas: v.notas, tamanho: Number(v.tamanho), sha256: v.sha256,
    assinatura: v.assinatura, enviada: v.enviada, publicada: v.publicada, criadaEm: v.criadaEm,
  };
}

/** Compara versões "1.10.0" > "1.9" (número a número). */
export function compararVersoes(a: string, b: string) {
  const pa = a.split("-")[0].split(".").map(Number);
  const pb = b.split("-")[0].split(".").map(Number);
  for (let i = 0; i < Math.max(pa.length, pb.length); i++) {
    const d = (pa[i] ?? 0) - (pb[i] ?? 0);
    if (d) return d;
  }
  // 1.0-beta vem antes de 1.0
  return (a.includes("-") ? 0 : 1) - (b.includes("-") ? 0 : 1);
}

export function ultimaPublicada<T extends { versao: string; publicada: boolean; enviada: boolean }>(vs: T[]) {
  return vs.filter((v) => v.publicada && v.enviada).sort((x, y) => compararVersoes(y.versao, x.versao))[0] ?? null;
}
