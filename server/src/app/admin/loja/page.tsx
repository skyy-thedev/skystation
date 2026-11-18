import type { Metadata } from "next";
import { notFound, redirect } from "next/navigation";
import { db } from "@/lib/db";
import { compararVersoes, ehAdmin, versaoJson } from "@/lib/loja";
import { quemEstaLogado } from "@/lib/sessao-pagina";
import { AdminLoja, type ItemAdmin } from "./AdminLoja";

export const metadata: Metadata = { title: "SkyStore · painel" };
export const dynamic = "force-dynamic";

export default async function PaginaAdminLoja() {
  const eu = await quemEstaLogado();
  if (!eu) redirect("/entrar");
  if (!ehAdmin(eu.usuario)) notFound(); // para os outros a página nem existe
  const itens = await db.lojaItem.findMany({ include: { versoes: true }, orderBy: { criadoEm: "desc" } });
  const dados: ItemAdmin[] = itens.map(({ versoes, ...i }) => ({
    ...JSON.parse(JSON.stringify(i)),
    versoes: JSON.parse(JSON.stringify(versoes.sort((a, b) => compararVersoes(b.versao, a.versao)).map(versaoJson))),
  }));
  return <AdminLoja inicial={dados} />;
}
