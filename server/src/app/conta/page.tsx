import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { minhaConta } from "@/lib/conta-web";
import { quemEstaLogado } from "@/lib/sessao-pagina";
import { Conta } from "./Conta";

export const metadata: Metadata = { title: "Minha conta" };

export default async function PaginaConta() {
  const eu = await quemEstaLogado();
  if (!eu) redirect("/entrar");
  return <Conta inicial={JSON.parse(JSON.stringify(await minhaConta(eu.id)))} />;
}
