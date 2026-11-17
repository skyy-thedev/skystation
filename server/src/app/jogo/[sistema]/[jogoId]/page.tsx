import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { Avatar } from "@/components/Avatar";
import { Banner } from "@/components/Banner";
import { nomeSistema } from "@/lib/jogos";
import { quemEstaLogado } from "@/lib/sessao-pagina";
import { paginaJogo } from "@/lib/vitrine";

type Props = { params: Promise<{ sistema: string; jogoId: string }> };

const CORES: Record<string, string> = { bronze: "var(--bronze)", prata: "var(--prata)", ouro: "var(--ouro)", platina: "var(--platina)" };

const decodificar = (s: string) => {
  try {
    return decodeURIComponent(s);
  } catch {
    return s;
  }
};

async function carregar({ params }: Props) {
  const { sistema, jogoId } = await params;
  const eu = await quemEstaLogado();
  return paginaJogo(decodificar(sistema), decodificar(jogoId), eu);
}

export async function generateMetadata(props: Props): Promise<Metadata> {
  const j = await carregar(props);
  return { title: j?.info.nome ?? "Jogo" };
}

function data(d: Date) {
  return d.toLocaleDateString("pt-BR", { day: "2-digit", month: "short", year: "numeric", timeZone: "America/Sao_Paulo" });
}

export default async function Jogo(props: Props) {
  const j = await carregar(props);
  if (!j) notFound();
  const { info } = j;
  const fonte = info.link ? (
    <a href={info.link} target="_blank" rel="noreferrer noopener">
      {info.fonte === "igdb" ? "IGDB" : info.fonte === "rawg" ? "RAWG" : "Wikipédia"}
    </a>
  ) : null;

  return (
    <>
      <Banner
        baixo
        info={info}
        sistema={j.sistema}
        selo={[nomeSistema(j.sistema), info.ano, ...info.generos].filter(Boolean).join(" · ")}
        texto={info.resumo ? <p>{info.resumo}</p> : <p>Ainda não achamos a ficha deste jogo na internet.</p>}
        acoes={fonte && <span className="apagado">Fonte: {fonte}</span>}
      />

      <div className="duas conteudo-jogo">
        <section className="cartao">
          <h2>Quem joga · {j.jogadores.length}</h2>
          {j.jogadores.length ? (
            <ul className="lista">
              {j.jogadores.map((p, i) => (
                <li key={p.usuario ?? `${p.apelido}-${i}`}>
                  <Avatar id={p.avatar} tamanho={40} />
                  <span style={{ flex: 1 }}>
                    {p.usuario ? <Link href={`/u/${p.usuario}`}>{p.apelido}</Link> : p.apelido}
                    <span className="apagado" style={{ display: "block" }}>
                      {p.agora && <span className="bolinha jogando" style={{ display: "inline-block", marginRight: 6 }} />}
                      {p.legenda}
                    </span>
                  </span>
                  {p.trofeus > 0 && <span className="status">{p.trofeus} {p.trofeus === 1 ? "troféu" : "troféus"}</span>}
                </li>
              ))}
            </ul>
          ) : (
            <p className="apagado">Ninguém que você pode ver joga este jogo ainda.</p>
          )}
        </section>
        <section className="cartao">
          <h2>Troféus ganhos · {j.trofeus.length}</h2>
          {j.trofeus.length ? (
            <ul className="lista">
              {j.trofeus.slice(0, 20).map((t) => (
                <li key={`${t.perfilId}-${t.trofeu}`}>
                  <span className="trofeu" style={{ background: CORES[t.tipo] ?? "var(--apagado)" }} />
                  <span style={{ flex: 1 }}>
                    {t.nome || t.trofeu}
                    <span className="apagado"> · {t.de.apelido}</span>
                  </span>
                  <span className="apagado">{data(t.ganhoEm)}</span>
                </li>
              ))}
            </ul>
          ) : (
            <p className="apagado">Nenhum troféu deste jogo ainda.</p>
          )}
        </section>
      </div>
    </>
  );
}
