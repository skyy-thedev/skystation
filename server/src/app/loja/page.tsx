import type { Metadata } from "next";
import Link from "next/link";
import { Capa } from "@/components/Capa";
import { CORES_TIPO, itensDaLoja, NOMES_TIPO, tamanhoLegivel } from "@/lib/vitrine-loja";

export const dynamic = "force-dynamic";
export const metadata: Metadata = { title: "SkyStore" };

export default async function Loja() {
  const itens = await itensDaLoja();
  return (
    <>
      <section className="cartao loja-topo">
        <h1>SkyStore</h1>
        <p>
          Jogos e apps oficiais da SkyStation. Baixe pelo console, na categoria <b>SkyStore</b> do menu: ele confere a
          assinatura de cada pacote antes de instalar.
        </p>
        <p className="apagado" style={{ marginBottom: 0 }}>
          Jogos de outros consoles não são vendidos nem distribuídos aqui: copie os seus para a pasta SKYROMS ou envie
          pela Central web do console.
        </p>
      </section>
      <section className="grade-jogos">
        {itens.length ? (
          <div className="capas">
            {itens.map((i) => (
              <Link key={i.slug} href={`/loja/${i.slug}`} className="cartao-jogo">
                <Capa nome={i.nome} src={i.capa} sistema={NOMES_TIPO[i.tipo] ?? i.tipo} cor={CORES_TIPO[i.tipo] ?? "#1b3a6b"} />
                <div className="cartao-jogo-texto">
                  <b className="titulo-jogo">{i.nome}</b>
                  <span className="legenda-jogo">
                    {i.oficial && <span className="selo-oficial">★ Oficial</span>}
                    versão {i.versao} · {tamanhoLegivel(i.tamanho)}
                  </span>
                </div>
              </Link>
            ))}
          </div>
        ) : (
          <p className="vazio">Ainda não há nada publicado. O primeiro jogo oficial está a caminho.</p>
        )}
      </section>
    </>
  );
}
