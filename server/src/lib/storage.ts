import {
  DeleteObjectCommand,
  GetObjectCommand,
  HeadObjectCommand,
  PutObjectCommand,
  S3Client,
} from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";
import { Erro } from "./http";

// Os arquivos de save NÃO passam pelo servidor: o servidor só assina um endereço temporário e o
// console envia/baixa direto do armazenamento (Cloudflare R2 ou qualquer serviço compatível com S3).

let cliente: S3Client | undefined;

function s3() {
  const { S3_ENDPOINT, S3_BUCKET, S3_ACCESS_KEY_ID, S3_SECRET_ACCESS_KEY } = process.env;
  if (!S3_ENDPOINT || !S3_BUCKET || !S3_ACCESS_KEY_ID || !S3_SECRET_ACCESS_KEY) {
    throw new Erro(503, "sem_armazenamento", "Os saves na nuvem ainda não foram configurados no servidor.");
  }
  cliente ??= new S3Client({
    endpoint: S3_ENDPOINT,
    region: process.env.S3_REGION || "auto",
    forcePathStyle: true,
    credentials: { accessKeyId: S3_ACCESS_KEY_ID, secretAccessKey: S3_SECRET_ACCESS_KEY },
    // O SDK novo acrescenta um checksum que o R2 não aceita em endereços assinados.
    requestChecksumCalculation: "WHEN_REQUIRED",
    responseChecksumValidation: "WHEN_REQUIRED",
  });
  return { cliente, bucket: S3_BUCKET };
}

export const tamanhoMaximo = () => Number(process.env.SKY_SAVE_MAX_MB || 64) * 1024 * 1024;

/** Endereço para o console ENVIAR o arquivo (PUT), válido por 15 minutos. */
export async function urlEnvio(chave: string) {
  const { cliente, bucket } = s3();
  return getSignedUrl(cliente, new PutObjectCommand({ Bucket: bucket, Key: chave }), { expiresIn: 900 });
}

/** Grava um arquivo pequeno direto do servidor (pacotes da SkyStore enviados pelo painel do site). */
export async function gravar(chave: string, dados: Uint8Array, tipo = "application/gzip") {
  const { cliente, bucket } = s3();
  await cliente.send(new PutObjectCommand({ Bucket: bucket, Key: chave, Body: dados, ContentType: tipo }));
}

/** Endereço para o console BAIXAR o arquivo (GET), válido por 5 minutos. */
export async function urlDownload(chave: string) {
  const { cliente, bucket } = s3();
  return getSignedUrl(cliente, new GetObjectCommand({ Bucket: bucket, Key: chave }), { expiresIn: 300 });
}

/** Tamanho do arquivo no armazenamento, ou null se ele não existe. */
export async function tamanhoDe(chave: string): Promise<number | null> {
  const { cliente, bucket } = s3();
  try {
    const r = await cliente.send(new HeadObjectCommand({ Bucket: bucket, Key: chave }));
    return r.ContentLength ?? 0;
  } catch (e) {
    const status = (e as { $metadata?: { httpStatusCode?: number } }).$metadata?.httpStatusCode;
    if (status === 404 || (e as Error).name === "NotFound") return null;
    throw e;
  }
}

export async function apagar(chaves: string[]) {
  if (!chaves.length) return;
  const { cliente, bucket } = s3();
  // Um por vez de propósito: são poucos arquivos, e o apagar em lote exige um checksum que nem
  // todo serviço compatível com S3 aceita.
  for (const Key of chaves) {
    await cliente.send(new DeleteObjectCommand({ Bucket: bucket, Key }));
  }
}
