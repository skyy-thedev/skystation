import type { Metadata } from "next";
import Link from "next/link";
import type { ReactNode } from "react";
import { Avatar } from "@/components/Avatar";
import { quemEstaLogado } from "@/lib/sessao-pagina";
import "./globals.css";

export const metadata: Metadata = {
  title: { default: "SkyNetwork", template: "%s · SkyNetwork" },
  description: "A rede do SkyStation: perfis, amigos, troféus e saves na nuvem.",
  robots: { index: false },
};

export default async function RootLayout({ children }: { children: ReactNode }) {
  const eu = await quemEstaLogado();
  return (
    <html lang="pt-BR">
      <body>
        <header className="topo">
          <Link href="/" className="marca">
            Sky<span>Network</span>
          </Link>
          <nav className="menu">
            {eu ? (
              <>
                <Link href={`/u/${eu.usuario}`} className="chip">
                  <Avatar id={eu.avatar} tamanho={30} />
                  {eu.apelido}
                </Link>
                <Link href="/conta" className="botao secundario pequeno">Conta</Link>
              </>
            ) : (
              <>
                <Link href="/entrar" className="botao secundario pequeno">Entrar</Link>
                <Link href="/criar-conta" className="botao pequeno">Criar conta</Link>
              </>
            )}
          </nav>
        </header>
        <main className="principal">{children}</main>
        <footer className="rodape">SkyStation · SkyNetwork</footer>
      </body>
    </html>
  );
}
