import { cookies } from "next/headers";
import { COOKIE, perfilDaSessao } from "./conta";

/** Nas páginas (componentes de servidor): o perfil logado no site, ou null. */
export async function quemEstaLogado() {
  const p = await perfilDaSessao((await cookies()).get(COOKIE)?.value);
  return p?.usuario ? p : null;
}
