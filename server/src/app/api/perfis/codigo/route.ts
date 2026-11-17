import { autenticarPerfil, hashToken, novoCodigoVinculo } from "@/lib/auth";
import { db } from "@/lib/db";
import { json, rota } from "@/lib/http";

const VALIDADE_MS = 15 * 60 * 1000;

/**
 * POST /api/perfis/codigo — gera um código de 8 letras, válido por 15 minutos e para um uso só,
 * para usar ESTE perfil em outro console (POST /api/perfis/vincular lá). Quem tem o código
 * passa a ler e gravar os saves do perfil: por isso ele expira rápido e o banco guarda só o hash.
 */
export const POST = rota(async (req) => {
  const { perfil } = await autenticarPerfil(req);
  const codigo = novoCodigoVinculo();
  await db.perfil.update({
    where: { id: perfil.id },
    data: { vinculoHash: hashToken(codigo), vinculoExpira: new Date(Date.now() + VALIDADE_MS) },
  });
  return json({ codigo, expiraEmSegundos: VALIDADE_MS / 1000 });
});
