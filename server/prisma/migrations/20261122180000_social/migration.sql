-- 13.26: social — jogos jogados, capturas publicadas, curtidas e comentários.
CREATE TABLE "JogoJogado" (
    "id" TEXT NOT NULL,
    "perfilId" TEXT NOT NULL,
    "jogoId" TEXT NOT NULL,
    "titulo" TEXT NOT NULL,
    "sistema" TEXT,
    "segundos" INTEGER NOT NULL DEFAULT 0,
    "partidas" INTEGER NOT NULL DEFAULT 0,
    "ultimaVez" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "JogoJogado_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "Post" (
    "id" TEXT NOT NULL,
    "perfilId" TEXT NOT NULL,
    "legenda" TEXT NOT NULL DEFAULT '',
    "jogoId" TEXT,
    "jogo" TEXT,
    "sistema" TEXT,
    "chave" TEXT NOT NULL,
    "tipo" TEXT NOT NULL DEFAULT 'image/jpeg',
    "tamanho" INTEGER NOT NULL,
    "confirmado" BOOLEAN NOT NULL DEFAULT false,
    "criadoEm" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Post_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "Curtida" (
    "postId" TEXT NOT NULL,
    "perfilId" TEXT NOT NULL,
    "criadaEm" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Curtida_pkey" PRIMARY KEY ("postId","perfilId")
);

CREATE TABLE "Comentario" (
    "id" TEXT NOT NULL,
    "postId" TEXT NOT NULL,
    "perfilId" TEXT NOT NULL,
    "texto" TEXT NOT NULL,
    "criadoEm" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Comentario_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "JogoJogado_perfilId_ultimaVez_idx" ON "JogoJogado"("perfilId", "ultimaVez");
CREATE UNIQUE INDEX "JogoJogado_perfilId_jogoId_key" ON "JogoJogado"("perfilId", "jogoId");
CREATE INDEX "Post_perfilId_criadoEm_idx" ON "Post"("perfilId", "criadoEm");
CREATE INDEX "Post_criadoEm_idx" ON "Post"("criadoEm");
CREATE INDEX "Comentario_postId_criadoEm_idx" ON "Comentario"("postId", "criadoEm");

ALTER TABLE "JogoJogado" ADD CONSTRAINT "JogoJogado_perfilId_fkey" FOREIGN KEY ("perfilId") REFERENCES "Perfil"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "Post" ADD CONSTRAINT "Post_perfilId_fkey" FOREIGN KEY ("perfilId") REFERENCES "Perfil"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "Curtida" ADD CONSTRAINT "Curtida_postId_fkey" FOREIGN KEY ("postId") REFERENCES "Post"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "Curtida" ADD CONSTRAINT "Curtida_perfilId_fkey" FOREIGN KEY ("perfilId") REFERENCES "Perfil"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "Comentario" ADD CONSTRAINT "Comentario_postId_fkey" FOREIGN KEY ("postId") REFERENCES "Post"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "Comentario" ADD CONSTRAINT "Comentario_perfilId_fkey" FOREIGN KEY ("perfilId") REFERENCES "Perfil"("id") ON DELETE CASCADE ON UPDATE CASCADE;
