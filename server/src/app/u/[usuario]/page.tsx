import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { Avatar } from "@/components/Avatar";
import { perfilVisto } from "@/lib/conta";
import { quemEstaLogado } from "@/lib/sessao-pagina";

type Props = { params: Promise<{ usuario: string }> };

const SISTEMAS: Record<string, string> = {
  ps1: "PS1", ps2: "PS2", ps3: "PS3", psp: "PSP", x360: "Xbox 360", snes: "SNES", n64: "N64", gc: "GameCube",
  wii: "Wii", nds: "DS", "3ds": "3DS", gba: "GBA", gb: "Game Boy", nes: "NES", md: "Mega Drive",
};
const CORES: Record<string, string> = { bronze: "var(--bronze)", prata: "var(--prata)", ouro: "var(--ouro)", platina: "var(--platina)" };
const VIS: Record<string, string> = { publico: "Perfil público", amigos: "Visível para amigos", privado: "Perfil privado" };

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { usuario } = await params;
  return { title: `@${usuario.toLowerCase()}` };
}

function curta(d: Date | string) {
  return new Date(d).toLocaleDateString("pt-BR", { day: "2-digit", month: "2-digit", year: "2-digit", timeZone: "America/Sao_Paulo" });
}

function data(d: Date | string) {
  return new Date(d).toLocaleDateString("pt-BR", { day: "2-digit", month: "short", year: "numeric", timeZone: "America/Sao_Paulo" });
}

export default async function Perfil({ params }: Props) {
  const { usuario } = await params;
  const eu = await quemEstaLogado();
  const p = await perfilVisto(usuario, eu);
  if (!p) notFound();

  const topo = (
    <div className="perfil-topo">
      <Avatar id={p.avatar} tamanho={112} titulo={p.apelido} />
      <div style={{ flex: 1, minWidth: 220 }}>
        <h1>{p.apelido}</h1>
        <div className="apagado">@{p.usuario} · {VIS[p.visibilidade] ?? ""}</div>
        {p.completo && (
          <div className="linha" style={{ marginTop: 12 }}>
            <span className="status">
              <span className={`bolinha ${p.status}`} />
              {p.status === "jogando"
                ? `Jogando ${p.jogo ?? ""}${p.sistema ? ` · ${SISTEMAS[p.sistema] ?? p.sistema.toUpperCase()}` : ""}`
                : p.status === "offline" ? "Offline" : p.status === "ausente" ? "Ausente" : "Online"}
            </span>
            {p.dono && p.invisivel && <span className="apagado">Você está invisível para os amigos</span>}
          </div>
        )}
      </div>
      {p.dono && <Link href="/conta" className="botao secundario">Editar perfil</Link>}
    </div>
  );

  if (!p.completo) {
    return (
      <div className="cartao">
        {topo}
        <div className="cadeado">
          {p.visibilidade === "amigos"
            ? eu ? `Só os amigos de ${p.apelido} veem este perfil.` : "Este perfil é visível só para amigos. Entre na sua conta."
            : "Este perfil é privado."}
        </div>
      </div>
    );
  }

  return (
    <>
      <div className="cartao">
        {topo}
        {p.bio && <p style={{ marginTop: 18, marginBottom: 0 }}>{p.bio}</p>}
        <p className="apagado" style={{ marginBottom: 0 }}>Na SkyNetwork desde {data(p.membroDesde)}</p>
      </div>
      <div className="duas">
        <section className="cartao">
          <h2>Troféus · {p.trofeus.total}</h2>
          <div className="contagem">
            {(["platina", "ouro", "prata", "bronze"] as const).map((t) => (
              <div key={t}>
                <b style={{ color: CORES[t] }}>{p.trofeus.porTipo[t] ?? 0}</b>
                <span className="apagado">{t}</span>
              </div>
            ))}
          </div>
          {p.trofeus.recentes.length ? (
            <ul className="lista">
              {p.trofeus.recentes.map((t) => (
                <li key={`${t.jogoId}-${t.trofeu}`}>
                  <span className="trofeu" style={{ background: CORES[t.tipo] ?? "var(--apagado)" }} />
                  <span style={{ flex: 1 }}>
                    {t.nome || t.trofeu}
                    <span className="apagado"> · {t.jogoId === "skystation" ? "SkyStation" : t.jogo || t.jogoId}</span>
                  </span>
                  <span className="apagado">{curta(t.ganhoEm)}</span>
                </li>
              ))}
            </ul>
          ) : (
            <p className="apagado">Nenhum troféu ainda.</p>
          )}
        </section>
        <section className="cartao">
          <h2>Amigos · {p.amigos.length}</h2>
          {p.amigos.length ? (
            <ul className="lista">
              {p.amigos.map((a, i) => (
                <li key={a.usuario ?? `${a.apelido}-${i}`}>
                  <Avatar id={a.avatar} tamanho={36} />
                  {a.usuario ? <Link href={`/u/${a.usuario}`}>{a.apelido}</Link> : <span>{a.apelido}</span>}
                </li>
              ))}
            </ul>
          ) : (
            <p className="apagado">Nenhum amigo ainda.</p>
          )}
        </section>
      </div>
    </>
  );
}
