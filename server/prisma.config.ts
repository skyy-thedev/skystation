import "dotenv/config";
import { defineConfig } from "prisma/config";

// Migrações usam a conexão direta (sem pool) quando ela existe: a integração Neon da Vercel
// cria DATABASE_URL (com pool, para o app) e DATABASE_URL_UNPOOLED (direta, para migrar).
export default defineConfig({
  schema: "prisma/schema.prisma",
  migrations: { path: "prisma/migrations" },
  datasource: {
    url: process.env.DATABASE_URL_UNPOOLED ?? process.env.DATABASE_URL ?? "",
  },
});
