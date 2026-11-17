-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "public";

-- CreateTable
CREATE TABLE "Console" (
    "id" TEXT NOT NULL,
    "nome" TEXT NOT NULL,
    "tokenHash" TEXT NOT NULL,
    "criadoEm" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "vistoEm" TIMESTAMP(3),
    "janelaInicio" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "janelaContagem" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "Console_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Perfil" (
    "id" TEXT NOT NULL,
    "consoleId" TEXT NOT NULL,
    "localId" TEXT NOT NULL,
    "apelido" TEXT NOT NULL,
    "cor" TEXT NOT NULL DEFAULT '#4fd1ff',
    "invisivel" BOOLEAN NOT NULL DEFAULT false,
    "codigo" TEXT NOT NULL,
    "criadoEm" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Perfil_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Save" (
    "id" TEXT NOT NULL,
    "perfilId" TEXT NOT NULL,
    "sistema" TEXT NOT NULL,
    "jogoId" TEXT NOT NULL,
    "titulo" TEXT,
    "versaoAtual" INTEGER NOT NULL DEFAULT 0,
    "atualizadoEm" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Save_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "SaveVersao" (
    "id" TEXT NOT NULL,
    "saveId" TEXT NOT NULL,
    "numero" INTEGER NOT NULL,
    "hash" TEXT NOT NULL,
    "tamanho" INTEGER NOT NULL,
    "chave" TEXT NOT NULL,
    "consoleId" TEXT,
    "confirmada" BOOLEAN NOT NULL DEFAULT false,
    "criadaEm" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "SaveVersao_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Amizade" (
    "id" TEXT NOT NULL,
    "aId" TEXT NOT NULL,
    "bId" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'pendente',
    "criadaEm" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Amizade_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Presenca" (
    "perfilId" TEXT NOT NULL,
    "status" TEXT NOT NULL,
    "jogoId" TEXT,
    "jogo" TEXT,
    "sistema" TEXT,
    "desde" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "vistoEm" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Presenca_pkey" PRIMARY KEY ("perfilId")
);

-- CreateTable
CREATE TABLE "Mensagem" (
    "id" TEXT NOT NULL,
    "deId" TEXT NOT NULL,
    "paraId" TEXT NOT NULL,
    "tipo" TEXT NOT NULL DEFAULT 'texto',
    "texto" TEXT NOT NULL,
    "jogoId" TEXT,
    "jogo" TEXT,
    "sistema" TEXT,
    "enviadaEm" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "lidaEm" TIMESTAMP(3),

    CONSTRAINT "Mensagem_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "TrofeuGanho" (
    "id" TEXT NOT NULL,
    "perfilId" TEXT NOT NULL,
    "jogoId" TEXT NOT NULL DEFAULT 'skystation',
    "jogo" TEXT,
    "trofeu" TEXT NOT NULL,
    "nome" TEXT,
    "tipo" TEXT NOT NULL,
    "ganhoEm" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "criadoEm" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "TrofeuGanho_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "Console_tokenHash_key" ON "Console"("tokenHash");

-- CreateIndex
CREATE UNIQUE INDEX "Perfil_codigo_key" ON "Perfil"("codigo");

-- CreateIndex
CREATE UNIQUE INDEX "Perfil_consoleId_localId_key" ON "Perfil"("consoleId", "localId");

-- CreateIndex
CREATE UNIQUE INDEX "Save_perfilId_sistema_jogoId_key" ON "Save"("perfilId", "sistema", "jogoId");

-- CreateIndex
CREATE INDEX "SaveVersao_confirmada_criadaEm_idx" ON "SaveVersao"("confirmada", "criadaEm");

-- CreateIndex
CREATE UNIQUE INDEX "SaveVersao_saveId_numero_key" ON "SaveVersao"("saveId", "numero");

-- CreateIndex
CREATE INDEX "Amizade_bId_idx" ON "Amizade"("bId");

-- CreateIndex
CREATE UNIQUE INDEX "Amizade_aId_bId_key" ON "Amizade"("aId", "bId");

-- CreateIndex
CREATE INDEX "Mensagem_paraId_enviadaEm_idx" ON "Mensagem"("paraId", "enviadaEm");

-- CreateIndex
CREATE INDEX "Mensagem_deId_enviadaEm_idx" ON "Mensagem"("deId", "enviadaEm");

-- CreateIndex
CREATE INDEX "TrofeuGanho_criadoEm_idx" ON "TrofeuGanho"("criadoEm");

-- CreateIndex
CREATE UNIQUE INDEX "TrofeuGanho_perfilId_jogoId_trofeu_key" ON "TrofeuGanho"("perfilId", "jogoId", "trofeu");

-- AddForeignKey
ALTER TABLE "Perfil" ADD CONSTRAINT "Perfil_consoleId_fkey" FOREIGN KEY ("consoleId") REFERENCES "Console"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Save" ADD CONSTRAINT "Save_perfilId_fkey" FOREIGN KEY ("perfilId") REFERENCES "Perfil"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SaveVersao" ADD CONSTRAINT "SaveVersao_saveId_fkey" FOREIGN KEY ("saveId") REFERENCES "Save"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SaveVersao" ADD CONSTRAINT "SaveVersao_consoleId_fkey" FOREIGN KEY ("consoleId") REFERENCES "Console"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Amizade" ADD CONSTRAINT "Amizade_aId_fkey" FOREIGN KEY ("aId") REFERENCES "Perfil"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Amizade" ADD CONSTRAINT "Amizade_bId_fkey" FOREIGN KEY ("bId") REFERENCES "Perfil"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Presenca" ADD CONSTRAINT "Presenca_perfilId_fkey" FOREIGN KEY ("perfilId") REFERENCES "Perfil"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Mensagem" ADD CONSTRAINT "Mensagem_deId_fkey" FOREIGN KEY ("deId") REFERENCES "Perfil"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Mensagem" ADD CONSTRAINT "Mensagem_paraId_fkey" FOREIGN KEY ("paraId") REFERENCES "Perfil"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TrofeuGanho" ADD CONSTRAINT "TrofeuGanho_perfilId_fkey" FOREIGN KEY ("perfilId") REFERENCES "Perfil"("id") ON DELETE CASCADE ON UPDATE CASCADE;
