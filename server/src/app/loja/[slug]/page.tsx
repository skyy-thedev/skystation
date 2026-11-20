import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { Capa } from "@/components/Capa";
import { CORES_TIPO, itemDaLoja, NOMES_TIPO, tamanhoLegivel } from "@/lib/vitrine-loja";

export const dynamic = "force-dynamic";
type Props = { params: Promise<{ slug: string }> };

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const item = await itemDaLoja((await params).slug);
  return { title: item ? `${item.nome} · SkyStore` : "SkyStore" };
}

function data(d: Date) {
  return d.toLocaleDateString("pt-BR", { day: "2-digit", month: "short", year: "numeric", timeZone: "America/Sao_Paulo" });
}

export default async function ItemLoja({ params }: Props) {
  const item = await itemDaLoja((await params).slug);
  if (!item) notFound();
  const atual = item.versoes[0];
  return (
    <>
      <p><Link href="/loja">← SkyStore</Link></p>
      <section className="cartao loja-item">
        <div className="loja-item-capa">
          <Capa nome={item.nome} src={item.capa} sistema={NOMES_TIPO[item.tipo] ?? item.tipo} cor={CORES_TIPO[item.tipo] ?? "#1b3a6b"} grande />
        </div>
        <div className="loja-item-texto">
          <span className="apagado">
            {item.oficial ? "★ Oficial da SkyStation · " : ""}{NOMES_TIPO[item.tipo] ?? item.tipo}
            {item.autor ? ` · ${item.autor}` : ""}
          </span>
          <h1>{item.nome}</h1>
          {item.resumo && <p><b>{item.resumo}</b></p>}
          {item.descricao && item.descricao.split(/\n{2,}/).map((p, k) => <p key={k}>{p}</p>)}
          <div className="ficha-tecnica">
            <div><span className="apagado">Versão</span><b>{atual.versao}</b></div>
            <div><span className="apagado">Tamanho</span><b>{tamanhoLegivel(atual.tamanho)}</b></div>
            <div><span className="apagado">Publicada</span><b>{data(atual.criadaEm)}</b></div>
            <div><span className="apagado">Downloads</span><b>{item.downloads}</b></div>
          </div>
          <p className="apagado" style={{ marginBottom: 0 }}>
            Para instalar: no console, vá até a categoria <b>SkyStore</b> e aperte ✕. Precisa estar na SkyNetwork.
          </p>
        </div>
      </section>
      {item.versoes.some((v) => v.notas) && (
        <section className="cartao">
          <h2>Novidades</h2>
          {item.versoes.map((v) => (
            <div key={v.versao} className="loja-versao">
              <b>Versão {v.versao}</b> <span className="apagado">· {data(v.criadaEm)}</span>
              {v.notas && <p>{v.notas}</p>}
            </div>
          ))}
        </section>
      )}
    </>
  );
}
