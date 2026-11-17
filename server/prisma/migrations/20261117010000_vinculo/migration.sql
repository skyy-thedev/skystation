-- AlterTable
ALTER TABLE "Perfil" ADD COLUMN     "vinculoExpira" TIMESTAMP(3),
ADD COLUMN     "vinculoHash" TEXT;

-- CreateTable
CREATE TABLE "Vinculo" (
    "id" TEXT NOT NULL,
    "consoleId" TEXT NOT NULL,
    "localId" TEXT NOT NULL,
    "perfilId" TEXT NOT NULL,
    "criadoEm" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Vinculo_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "Vinculo_perfilId_idx" ON "Vinculo"("perfilId");

-- CreateIndex
CREATE UNIQUE INDEX "Vinculo_consoleId_localId_key" ON "Vinculo"("consoleId", "localId");

-- CreateIndex
CREATE UNIQUE INDEX "Perfil_vinculoHash_key" ON "Perfil"("vinculoHash");

-- AddForeignKey
ALTER TABLE "Vinculo" ADD CONSTRAINT "Vinculo_consoleId_fkey" FOREIGN KEY ("consoleId") REFERENCES "Console"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Vinculo" ADD CONSTRAINT "Vinculo_perfilId_fkey" FOREIGN KEY ("perfilId") REFERENCES "Perfil"("id") ON DELETE CASCADE ON UPDATE CASCADE;
