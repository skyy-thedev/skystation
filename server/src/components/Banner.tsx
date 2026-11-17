import type { ReactNode } from "react";
import { CORES_SISTEMA, nomeSistema, type InfoJogo } from "@/lib/jogos";
import { Capa } from "./Capa";

// Banner grande do topo (a "arte de capa" da página). Usa a arte larga do jogo; sem ela, a própria
// capa desfocada vira o fundo e a capa nítida aparece à direita.

type Props = {
  info?: InfoJogo | null;
  sistema?: string;
  selo?: string;
  titulo?: ReactNode; // se não vier, usa o nome do jogo
  texto?: ReactNode;
  acoes?: ReactNode;
  extra?: ReactNode; // canto direito quando não há jogo (ex.: vitrine de ícones)
  baixo?: boolean; // versão mais curta (página do jogo)
};

export function Banner({ info, sistema = "", selo, titulo, texto, acoes, extra, baixo }: Props) {
  const fundo = info?.arte ?? info?.capa ?? null;
  const desfocado = !info?.arte && Boolean(info?.capa);
  const cor = CORES_SISTEMA[sistema] ?? "#123a7a";
  return (
    <section className={`banner${baixo ? " banner-baixo" : ""}`} style={{ ["--cor-sistema" as string]: cor }}>
      {fundo ? (
        // eslint-disable-next-line @next/next/no-img-element
        <img className={`banner-fundo${desfocado ? " desfocado" : ""}`} src={fundo} alt="" referrerPolicy="no-referrer" />
      ) : (
        <div className="banner-fundo banner-cosmos" />
      )}
      <div className="banner-veu" />
      <div className="banner-conteudo">
        <div className="banner-texto">
          {selo && <span className="banner-selo">{selo}</span>}
          <h1>{titulo ?? info?.nome}</h1>
          {texto && <div className="banner-descricao">{texto}</div>}
          {acoes && <div className="linha banner-acoes">{acoes}</div>}
        </div>
        {info && !info.arte ? (
          <div className="banner-capa">
            <Capa nome={info.nome} src={info.capa} sistema={nomeSistema(sistema)} cor={cor} grande />
          </div>
        ) : (
          extra && <div className="banner-extra">{extra}</div>
        )}
      </div>
    </section>
  );
}
