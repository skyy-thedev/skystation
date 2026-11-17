import Link from "next/link";
import { Avatar } from "@/components/Avatar";
import avatares from "@/lib/avatares.json";
import { quemEstaLogado } from "@/lib/sessao-pagina";

export default async function Inicio() {
  const eu = await quemEstaLogado();
  return (
    <section className="heroi">
      <h1>
        A rede do <span style={{ color: "var(--destaque)" }}>SkyStation</span>
      </h1>
      <p>Seu perfil, seus amigos, seus troféus e seus saves, em qualquer console e aqui no site.</p>
      <div className="linha" style={{ justifyContent: "center" }}>
        {eu ? (
          <>
            <Link href={`/u/${eu.usuario}`} className="botao">Ver meu perfil</Link>
            <Link href="/conta" className="botao secundario">Minha conta</Link>
          </>
        ) : (
          <>
            <Link href="/entrar" className="botao">Entrar</Link>
            <Link href="/criar-conta" className="botao secundario">Criar conta</Link>
          </>
        )}
      </div>
      <div className="vitrine">
        {avatares.map((a) => (
          <Avatar key={a.id} id={a.id} tamanho={52} titulo={a.nome} />
        ))}
      </div>
    </section>
  );
}
