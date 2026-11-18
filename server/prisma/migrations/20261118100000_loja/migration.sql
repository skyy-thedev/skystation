-- Fase 12: SkyStore (itens e versões assinadas).
CREATE TABLE "LojaItem" (
    "id" TEXT NOT NULL,
    "slug" TEXT NOT NULL,
    "tipo" TEXT NOT NULL,
    "nome" TEXT NOT NULL,
    "resumo" TEXT NOT NULL DEFAULT '',
    "descricao" TEXT NOT NULL DEFAULT '',
    "autor" TEXT NOT NULL DEFAULT 'SkyStation',
    "oficial" BOOLEAN NOT NULL DEFAULT false,
    "capa" TEXT,
    "publicado" BOOLEAN NOT NULL DEFAULT false,
    "downloads" INTEGER NOT NULL DEFAULT 0,
    "criadoEm" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "atualizadoEm" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "LojaItem_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "LojaVersao" (
    "id" TEXT NOT NULL,
    "itemId" TEXT NOT NULL,
    "versao" TEXT NOT NULL,
    "notas" TEXT NOT NULL DEFAULT '',
    "chave" TEXT NOT NULL,
    "tamanho" BIGINT NOT NULL,
    "sha256" TEXT NOT NULL,
    "assinatura" TEXT NOT NULL,
    "enviada" BOOLEAN NOT NULL DEFAULT false,
    "publicada" BOOLEAN NOT NULL DEFAULT false,
    "criadaEm" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "LojaVersao_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "LojaItem_slug_key" ON "LojaItem"("slug");
CREATE INDEX "LojaVersao_itemId_criadaEm_idx" ON "LojaVersao"("itemId", "criadaEm");
CREATE UNIQUE INDEX "LojaVersao_itemId_versao_key" ON "LojaVersao"("itemId", "versao");

ALTER TABLE "LojaVersao" ADD CONSTRAINT "LojaVersao_itemId_fkey" FOREIGN KEY ("itemId") REFERENCES "LojaItem"("id") ON DELETE CASCADE ON UPDATE CASCADE;
