import { db } from "@/lib/db";
import { json, rota } from "@/lib/http";

/** GET /api/saude — o console usa para saber se o servidor (e o banco) estão no ar. */
export const GET = rota(async () => {
  await db.$queryRaw`SELECT 1`;
  return json({
    ok: true,
    servico: "skynetwork",
    versao: "0.1.0",
    saves: Boolean(process.env.S3_ENDPOINT && process.env.S3_BUCKET),
    agora: new Date(),
  });
});
