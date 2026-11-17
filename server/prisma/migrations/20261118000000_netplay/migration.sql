-- Fase 11.4: convite para jogar junto (netplay do RetroArch) leva os dados da sala.
ALTER TABLE "Mensagem" ADD COLUMN "sala" JSONB;
