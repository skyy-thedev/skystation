import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { quemEstaLogado } from "@/lib/sessao-pagina";
import { FormEntrar } from "./FormEntrar";

export const metadata: Metadata = { title: "Entrar" };

export default async function Entrar() {
  const eu = await quemEstaLogado();
  if (eu) redirect(`/u/${eu.usuario}`);
  return (
    <div className="cartao estreito">
      <h1>Entrar</h1>
      <p className="suave">Use o seu ID SkyNetwork e a senha criados no console ou aqui no site.</p>
      <FormEntrar />
    </div>
  );
}
