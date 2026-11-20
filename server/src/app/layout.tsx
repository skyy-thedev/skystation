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

function Logo() {
  // estrela cadente da marca: um rastro e uma estrela de 4 pontas
  return (
    <svg className="logo-icone" viewBox="0 0 32 32" aria-hidden="true">
      <path d="M3 25 L17 14" stroke="currentColor" strokeWidth="3" strokeLinecap="round" opacity=".45" />
      <path d="M22 4 L24.2 9.8 L30 12 L24.2 14.2 L22 20 L19.8 14.2 L14 12 L19.8 9.8 Z" fill="currentColor" />
    </svg>
  );
}

export default async function RootLayout({ children }: { children: ReactNode }) {
  const eu = await quemEstaLogado();
  return (
    <html lang="pt-BR">
      <body>
        <header className="topo">
          <div className="topo-faixa">
            <span>SkyStation</span>
          </div>
          <div className="topo-barra">
            <Link href="/" className="marca">
              <Logo />
              <span>Sky<b>Network</b></span>
            </Link>
            <nav className="menu-principal">
              <Link href="/">Início</Link>
              <Link href="/#jogos">Jogos</Link>
              <Link href="/#emuladores">Emuladores</Link>
              <Link href="/loja">SkyStore</Link>
              {eu && <Link href={`/u/${eu.usuario}`}>Meu perfil</Link>}
              {eu && <Link href="/conta">Conta</Link>}
            </nav>
            <div className="menu">
              {eu ? (
                <Link href={`/u/${eu.usuario}`} className="chip">
                  <Avatar id={eu.avatar} tamanho={30} />
                  <span>{eu.apelido}</span>
                </Link>
              ) : (
                <>
                  <Link href="/criar-conta" className="link-topo">Criar conta</Link>
                  <Link href="/entrar" className="botao pilula">Iniciar sessão</Link>
                </>
              )}
            </div>
          </div>
        </header>
        <main className="principal">{children}</main>
        <footer className="rodape">
          <div className="marca marca-rodape">
            <Logo />
            <span>Sky<b>Network</b></span>
          </div>
          <span>A rede do SkyStation · feita em casa, para jogar com os amigos</span>
        </footer>
      </body>
    </html>
  );
}
