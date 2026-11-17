import Link from "next/link";
import { hrefCatalogo, SITUACOES, type JogoComFicha } from "@/lib/catalogo";
import { CORES_SISTEMA, nomeSistema } from "@/lib/jogos";
import { Capa } from "./Capa";

/** Capa de um jogo do catálogo (testado no SkyStation). */
export function CartaoCatalogo({ jogo }: { jogo: JogoComFicha }) {
  const s = SITUACOES[jogo.situacao];
  return (
    <Link href={hrefCatalogo(jogo)} className="cartao-jogo">
      <Capa nome={jogo.info.nome || jogo.nome} src={jogo.info.capa ?? jogo.info.arte} sistema={nomeSistema(jogo.sistema)} cor={CORES_SISTEMA[jogo.sistema] ?? "#1b3a6b"} />
      <div className="cartao-jogo-texto">
        <b className="titulo-jogo">{jogo.nome}</b>
        <span className="legenda-jogo">
          <span className="bolinha" style={{ background: s.cor, boxShadow: `0 0 8px ${s.cor}` }} />
          {s.rotulo}
          {jogo.info.ano ? ` · ${jogo.info.ano}` : ""}
        </span>
      </div>
    </Link>
  );
}
