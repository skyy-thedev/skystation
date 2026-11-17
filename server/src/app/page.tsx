import Link from "next/link";
import { Avatar } from "@/components/Avatar";
import { Banner } from "@/components/Banner";
import { CartaoJogo } from "@/components/CartaoJogo";
import { GradeJogos } from "@/components/GradeJogos";
import avatares from "@/lib/avatares.json";
import { nomeSistema } from "@/lib/jogos";
import { quemEstaLogado } from "@/lib/sessao-pagina";
import { vitrine } from "@/lib/vitrine";

// a página muda a cada sinal dos consoles: nada de página estática
export const dynamic = "force-dynamic";

function resumoCurto(t: string | null) {
  if (!t) return null;
  return t.length > 220 ? `${t.slice(0, 217).replace(/\s+\S*$/, "")}…` : t;
}

export default async function Inicio() {
  const eu = await quemEstaLogado();
  const v = await vitrine(eu);
  const d = v.destaque;

  const botaoConta = eu ? (
    <Link href={`/u/${eu.usuario}`} className="botao botao-claro">Ver meu perfil</Link>
  ) : (
    <Link href="/criar-conta" className="botao">Criar conta</Link>
  );

  return (
    <>
      {d ? (
        <Banner
          info={d.info}
          sistema={d.sistema}
          selo={`${d.selo} · ${nomeSistema(d.sistema)}`}
          texto={
            <>
              {resumoCurto(d.info.resumo) && <p>{resumoCurto(d.info.resumo)}</p>}
              <p className="banner-quem">
                <span className="avatares-pilha">
                  {d.jogadores.slice(0, 4).map((j, i) => (
                    <Avatar key={`${j.usuario ?? j.apelido}-${i}`} id={j.avatar} tamanho={28} titulo={j.apelido} />
                  ))}
                </span>
                {d.legenda}
              </p>
            </>
          }
          acoes={
            <>
              <Link href={d.href} className="botao botao-claro">Ver o jogo</Link>
              {eu ? <Link href="/#jogos" className="botao">O que a galera joga</Link> : botaoConta}
            </>
          }
        />
      ) : (
        <Banner
          selo="SkyStation"
          titulo={<>A rede do <span className="ciano">SkyStation</span></>}
          texto={<p>Seu perfil, seus amigos, seus troféus e seus saves, em qualquer console e aqui no site.</p>}
          acoes={
            eu ? (
              <>
                {botaoConta}
                <Link href="/conta" className="botao secundario">Minha conta</Link>
              </>
            ) : (
              <>
                <Link href="/entrar" className="botao botao-claro">Iniciar sessão</Link>
                {botaoConta}
              </>
            )
          }
          extra={
            <div className="vitrine">
              {avatares.map((a) => (
                <Avatar key={a.id} id={a.id} tamanho={56} titulo={a.nome} />
              ))}
            </div>
          }
        />
      )}

      <GradeJogos
        abas={[
          {
            id: "agora",
            titulo: "Jogando agora",
            total: v.jogando.length,
            vazio: "Ninguém está jogando agora. Ligue o SkyStation e apareça aqui!",
            cartoes: v.jogando.map((i) => <CartaoJogo key={i.chave} item={i} />),
          },
          {
            id: "recentes",
            titulo: "Jogados recentemente",
            total: v.recentes.length,
            vazio: eu ? "Nenhum jogo recente entre você e seus amigos." : "Entre na sua conta para ver o que seus amigos andam jogando.",
            cartoes: v.recentes.map((i) => <CartaoJogo key={i.chave} item={i} />),
          },
          {
            id: "trofeus",
            titulo: "Troféus recentes",
            total: v.trofeus.length,
            vazio: "Nenhum troféu por aqui ainda.",
            cartoes: v.trofeus.map((i) => <CartaoJogo key={i.chave} item={i} />),
          },
        ]}
      />

      <section className="faixa-mes">
        <div className="faixa-mes-titulo">
          <span>Em {v.mes.nome}</span>
          <strong>na SkyNetwork</strong>
          <p>O que rolou neste mês entre você e a galera: platinas, caçadores de troféus e quem chegou na rede.</p>
        </div>
        <div className="faixa-mes-cartoes">
          <article className="cartao-mes cartao-mes-platina">
            <div className="cartao-mes-arte"><span className="trofeu-grande" /></div>
            <h3>Platinas do mês</h3>
            <p className="numero">{v.mes.platinas}</p>
            <p className="apagado">
              {v.mes.ultimaPlatina ? `Última: ${v.mes.ultimaPlatina.jogo}, por ${v.mes.ultimaPlatina.de}` : "Nenhuma platina ainda. Quem vai ser o primeiro?"}
            </p>
          </article>
          <article className="cartao-mes cartao-mes-cacador">
            <div className="cartao-mes-arte">
              {v.mes.cacador ? <Avatar id={v.mes.cacador.avatar} tamanho={84} titulo={v.mes.cacador.apelido} /> : <span className="trofeu-grande ouro" />}
            </div>
            <h3>Caçador do mês</h3>
            <p className="numero">{v.mes.cacador ? v.mes.cacador.apelido : "—"}</p>
            <p className="apagado">
              {v.mes.cacador ? `${v.mes.cacador.total} ${v.mes.cacador.total === 1 ? "troféu" : "troféus"} em ${v.mes.nome}` : "Ganhe um troféu e tome a coroa."}
            </p>
          </article>
          <article className="cartao-mes cartao-mes-novos">
            <div className="cartao-mes-arte vitrine-mini">
              {avatares.slice(0, 5).map((a) => <Avatar key={a.id} id={a.id} tamanho={40} />)}
            </div>
            <h3>Novos na rede</h3>
            <p className="numero">{v.mes.novosMembros}</p>
            <p className="apagado">{v.mes.novosMembros === 1 ? "conta criada neste mês" : "contas criadas neste mês"}</p>
          </article>
        </div>
      </section>
    </>
  );
}
