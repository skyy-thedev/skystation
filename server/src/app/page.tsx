import Link from "next/link";
import { Avatar } from "@/components/Avatar";
import { Banner } from "@/components/Banner";
import { CartaoCatalogo } from "@/components/CartaoCatalogo";
import { GradeJogos } from "@/components/GradeJogos";
import avatares from "@/lib/avatares.json";
import { catalogoComFichas, destaqueDoDia, EM_BREVE, EMULADORES, hrefCatalogo, SITUACOES } from "@/lib/catalogo";
import { CORES_SISTEMA, nomeSistema } from "@/lib/jogos";
import { quemEstaLogado } from "@/lib/sessao-pagina";
import { vitrine } from "@/lib/vitrine";

// a faixa do mês muda a cada troféu: nada de página estática
export const dynamic = "force-dynamic";

function resumoCurto(t: string | null) {
  if (!t) return null;
  return t.length > 220 ? `${t.slice(0, 217).replace(/\s+\S*$/, "")}…` : t;
}

export default async function Inicio() {
  const eu = await quemEstaLogado();
  const [jogos, rede] = await Promise.all([catalogoComFichas(), vitrine(eu, { comFichas: false })]);
  const d = destaqueDoDia(jogos);
  const mes = rede.mes;
  const porSistema = (s: string) => jogos.filter((j) => j.sistema === s);

  return (
    <>
      {d ? (
        <Banner
          info={d.info}
          sistema={d.sistema}
          selo={`Testado no SkyStation · ${nomeSistema(d.sistema)}`}
          titulo={d.nome}
          texto={resumoCurto(d.info.resumo) && <p>{resumoCurto(d.info.resumo)}</p>}
          acoes={
            <>
              <Link href={hrefCatalogo(d)} className="botao botao-claro">Ver ficha</Link>
              <Link href="/#jogos" className="botao">Todos os jogos testados</Link>
            </>
          }
        />
      ) : (
        <Banner
          selo="SkyStation"
          titulo={<>A rede do <span className="ciano">SkyStation</span></>}
          texto={<p>Os jogos que rodam no SkyStation, e a rede para jogar com os amigos.</p>}
        />
      )}

      <section className="emuladores" id="emuladores">
        <div className="secao-titulo">
          <h2>Sistemas que já rodam no SkyStation</h2>
          <p className="suave">Emuladores instalados e testados no console. É só colocar o jogo na pasta e jogar.</p>
        </div>
        <div className="emuladores-grade">
          {EMULADORES.map((e) => {
            const n = porSistema(e.sistema).length;
            return (
              <article key={e.sistema} className="cartao-emulador" style={{ ["--cor-sistema" as string]: CORES_SISTEMA[e.sistema] ?? "#123a7a" }}>
                <span className="emulador-sigla">{nomeSistema(e.sistema)}</span>
                <span className="emulador-funciona"><span className="bolinha online" /> Funcionando</span>
                <h3>{e.nome}</h3>
                <p className="emulador-nome">{e.emulador}</p>
                <p className="apagado">{e.destaques}</p>
                <span className="emulador-total">{n ? `${n} ${n === 1 ? "jogo testado" : "jogos testados"}` : "Sem jogos na lista ainda"}</span>
              </article>
            );
          })}
        </div>
        <div className="em-teste">
          <span className="apagado">Em teste:</span>
          {EM_BREVE.map((e) => (
            <span key={e.sistema} className="chip-teste" title={e.emulador}>{e.nome}</span>
          ))}
        </div>
      </section>

      <GradeJogos
        abas={[
          {
            id: "todos",
            titulo: "Todos os testados",
            total: jogos.length,
            vazio: "Nenhum jogo na lista ainda.",
            cartoes: jogos.map((j) => <CartaoCatalogo key={j.id} jogo={j} />),
          },
          ...EMULADORES.filter((e) => porSistema(e.sistema).length).map((e) => ({
            id: e.sistema,
            titulo: nomeSistema(e.sistema),
            total: porSistema(e.sistema).length,
            vazio: "",
            cartoes: porSistema(e.sistema).map((j) => <CartaoCatalogo key={j.id} jogo={j} />),
          })),
        ]}
      />
      <p className="legenda-situacao">
        {(Object.keys(SITUACOES) as (keyof typeof SITUACOES)[]).map((k) => (
          <span key={k}>
            <span className="bolinha" style={{ background: SITUACOES[k].cor }} /> {SITUACOES[k].rotulo}
          </span>
        ))}
      </p>

      <section className="faixa-mes">
        <div className="faixa-mes-titulo">
          <span>Em {mes.nome}</span>
          <strong>na SkyNetwork</strong>
          <p>A rede dos consoles: platinas, caçadores de troféus e quem chegou.</p>
          {!eu && (
            <div className="linha" style={{ marginTop: 22 }}>
              <Link href="/criar-conta" className="botao botao-claro">Criar conta</Link>
              <Link href="/entrar" className="botao secundario-escuro">Iniciar sessão</Link>
            </div>
          )}
        </div>
        <div className="faixa-mes-cartoes">
          <article className="cartao-mes cartao-mes-platina">
            <div className="cartao-mes-arte"><span className="trofeu-grande" /></div>
            <h3>Platinas do mês</h3>
            <p className="numero">{mes.platinas}</p>
            <p className="apagado">
              {mes.ultimaPlatina ? `Última: ${mes.ultimaPlatina.jogo}, por ${mes.ultimaPlatina.de}` : "Nenhuma platina ainda. Quem vai ser o primeiro?"}
            </p>
          </article>
          <article className="cartao-mes cartao-mes-cacador">
            <div className="cartao-mes-arte">
              {mes.cacador ? <Avatar id={mes.cacador.avatar} tamanho={84} titulo={mes.cacador.apelido} /> : <span className="trofeu-grande ouro" />}
            </div>
            <h3>Caçador do mês</h3>
            <p className="numero">{mes.cacador ? mes.cacador.apelido : "—"}</p>
            <p className="apagado">
              {mes.cacador ? `${mes.cacador.total} ${mes.cacador.total === 1 ? "troféu" : "troféus"} em ${mes.nome}` : "Ganhe um troféu e tome a coroa."}
            </p>
          </article>
          <article className="cartao-mes cartao-mes-novos">
            <div className="cartao-mes-arte vitrine-mini">
              {avatares.slice(0, 5).map((a) => <Avatar key={a.id} id={a.id} tamanho={40} />)}
            </div>
            <h3>Novos na rede</h3>
            <p className="numero">{mes.novosMembros}</p>
            <p className="apagado">{mes.novosMembros === 1 ? "conta criada neste mês" : "contas criadas neste mês"}</p>
          </article>
        </div>
      </section>
    </>
  );
}
