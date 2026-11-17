import { PrismaPg } from "@prisma/adapter-pg";
import { PrismaClient } from "@/generated/prisma/client";

// Um cliente só por processo. No "next dev" o código recarrega a cada mudança; sem guardar o
// cliente no globalThis, cada recarga abriria um pool novo até o Postgres recusar conexões.
const global = globalThis as unknown as { prisma?: PrismaClient };

function criar() {
  const adapter = new PrismaPg({ connectionString: process.env.DATABASE_URL });
  return new PrismaClient({ adapter });
}

export const db = global.prisma ?? criar();
if (process.env.NODE_ENV !== "production") global.prisma = db;
