import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { quemEstaLogado } from "@/lib/sessao-pagina";
import { FormCriar } from "./FormCriar";

export const metadata: Metadata = { title: "Criar conta" };

export default async function CriarConta() {
  const eu = await quemEstaLogado();
  if (eu) redirect("/conta");
  return (
    <div className="cartao estreito" style={{ maxWidth: 560 }}>
      <h1>Criar conta</h1>
      <p className="suave">
        Já tem um perfil no console? Crie a conta por lá (Configurações → SkyNetwork) para manter seus
        amigos, troféus e saves. Aqui você cria uma conta nova.
      </p>
      <FormCriar />
    </div>
  );
}
