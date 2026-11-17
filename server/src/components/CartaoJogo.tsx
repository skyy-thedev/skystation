import Link from "next/link";
import { CORES_SISTEMA, nomeSistema } from "@/lib/jogos";
import type { ItemJogo } from "@/lib/vitrine";
import { Avatar } from "./Avatar";
import { Capa } from "./Capa";

const CORES_TROFEU: Record<string, string> = { bronze: "var(--bronze)", prata: "var(--prata)", ouro: "var(--ouro)", platina: "var(--platina)" };

/** Uma capa da grade: capa, nome e uma linha de contexto (quem joga, quando, que troféu). */
export function CartaoJogo({ item }: { item: ItemJogo }) {
  const rotulo = item.sistema === "sky" ? "" : nomeSistema(item.sistema);
  return (
    <Link href={item.href} className="cartao-jogo">
      <Capa nome={item.info.nome} src={item.info.capa ?? item.info.arte} sistema={rotulo} cor={CORES_SISTEMA[item.sistema] ?? "#1b3a6b"} />
      <div className="cartao-jogo-texto">
        {item.trofeu ? (
          <>
            <b className="titulo-jogo">
              <span className="trofeu" style={{ background: CORES_TROFEU[item.trofeu.tipo] ?? "var(--apagado)" }} />
              {item.trofeu.nome}
            </b>
            <span className="apagado">{item.info.nome}</span>
          </>
        ) : (
          <b className="titulo-jogo">{item.info.nome}</b>
        )}
        <span className="legenda-jogo">
          <span className="avatares-pilha">
            {item.jogadores.slice(0, 3).map((j, i) => (
              <Avatar key={`${j.usuario ?? j.apelido}-${i}`} id={j.avatar} tamanho={20} titulo={j.apelido} />
            ))}
          </span>
          {item.legenda}
        </span>
      </div>
    </Link>
  );
}
