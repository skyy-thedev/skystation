-- Contas pessoais (Fase 10.5): perfil pode existir sem console; ID, senha, ícone, bio, visibilidade.

-- DropForeignKey
ALTER TABLE "Perfil" DROP CONSTRAINT "Perfil_consoleId_fkey";

-- AlterTable
ALTER TABLE "Perfil" ADD COLUMN     "avatar" TEXT NOT NULL DEFAULT 'estrela',
ADD COLUMN     "bio" TEXT NOT NULL DEFAULT '',
ADD COLUMN     "bloqueadoAte" TIMESTAMP(3),
ADD COLUMN     "falhasLogin" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "senhaHash" TEXT,
ADD COLUMN     "usuario" TEXT,
ADD COLUMN     "visibilidade" TEXT NOT NULL DEFAULT 'amigos',
ALTER COLUMN "consoleId" DROP NOT NULL,
ALTER COLUMN "localId" DROP NOT NULL;

-- CreateTable
CREATE TABLE "Sessao" (
    "id" TEXT NOT NULL,
    "perfilId" TEXT NOT NULL,
    "tokenHash" TEXT NOT NULL,
    "criadaEm" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expira" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Sessao_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "Sessao_tokenHash_key" ON "Sessao"("tokenHash");

-- CreateIndex
CREATE INDEX "Sessao_perfilId_idx" ON "Sessao"("perfilId");

-- CreateIndex
CREATE UNIQUE INDEX "Perfil_usuario_key" ON "Perfil"("usuario");

-- AddForeignKey
ALTER TABLE "Perfil" ADD CONSTRAINT "Perfil_consoleId_fkey" FOREIGN KEY ("consoleId") REFERENCES "Console"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Sessao" ADD CONSTRAINT "Sessao_perfilId_fkey" FOREIGN KEY ("perfilId") REFERENCES "Perfil"("id") ON DELETE CASCADE ON UPDATE CASCADE;
