"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { Avatar } from "@/components/Avatar";
import { EscolherAvatar } from "@/components/EscolherAvatar";
import { chamar } from "@/lib/cliente";

type Pessoa = { amizadeId: string; id: string; usuario: string | null; apelido: string; avatar: string };
type Dados = {
  eu: { usuario: string; apelido: string; avatar: string; bio: string; visibilidade: string; invisivel: boolean; codigo: string };
  amigos: Pessoa[];
  pedidos: Pessoa[];
  enviados: Pessoa[];
};

function Nome({ p }: { p: Pessoa }) {
  return (
    <>
      <Avatar id={p.avatar} tamanho={36} />
      <span style={{ flex: 1 }}>
        {p.usuario ? <Link href={`/u/${p.usuario}`}>{p.apelido}</Link> : p.apelido}
        {p.usuario && <span className="apagado"> @{p.usuario}</span>}
      </span>
    </>
  );
}

export function Conta({ inicial }: { inicial: Dados }) {
  const router = useRouter();
  const [d, setD] = useState(inicial);
  const [f, setF] = useState({ ...inicial.eu });
  const [aviso, setAviso] = useState<{ onde: string; texto: string; erro?: boolean } | null>(null);
  const [quem, setQuem] = useState("");
  const [senha, setSenha] = useState({ atual: "", nova: "", nova2: "" });

  async function acao(onde: string, fn: () => Promise<unknown>, ok: string) {
    setAviso(null);
    try {
      await fn();
      setAviso({ onde, texto: ok });
      setD(await chamar<Dados>("/api/web/eu", "GET"));
      router.refresh();
    } catch (e) {
      setAviso({ onde, texto: (e as Error).message, erro: true });
    }
  }
  const msg = (onde: string) => aviso?.onde === onde && <p className={aviso.erro ? "erro" : "ok"}>{aviso.texto}</p>;

  return (
    <div className="abas">
      <section className="cartao">
        <div className="perfil-topo" style={{ marginBottom: 6 }}>
          <Avatar id={f.avatar} tamanho={84} />
          <div style={{ flex: 1 }}>
            <h1 style={{ marginBottom: 2 }}>{d.eu.apelido}</h1>
            <div className="apagado">
              @{d.eu.usuario} · código de amigo <b style={{ color: "var(--texto)" }}>{d.eu.codigo}</b>
            </div>
          </div>
          <Link href={`/u/${d.eu.usuario}`} className="botao secundario">Ver meu perfil</Link>
        </div>
        <form onSubmit={(e) => {
          e.preventDefault();
          acao("perfil", () => chamar("/api/web/eu", "PATCH", {
            apelido: f.apelido, avatar: f.avatar, bio: f.bio, visibilidade: f.visibilidade, invisivel: f.invisivel,
          }), "Perfil salvo. Os consoles recebem a mudança em até 30 segundos.");
        }}>
          <label>Ícone do perfil</label>
          <EscolherAvatar valor={f.avatar} mudar={(avatar) => setF({ ...f, avatar })} />
          <label htmlFor="apelido">Nome</label>
          <input id="apelido" maxLength={24} value={f.apelido} onChange={(e) => setF({ ...f, apelido: e.target.value })} required />
          <label htmlFor="bio">Sobre você (até 140 caracteres)</label>
          <textarea id="bio" maxLength={140} value={f.bio} onChange={(e) => setF({ ...f, bio: e.target.value })} />
          <label htmlFor="vis">Quem vê o seu perfil no site</label>
          <select id="vis" value={f.visibilidade} onChange={(e) => setF({ ...f, visibilidade: e.target.value })}>
            <option value="publico">Qualquer pessoa com o link</option>
            <option value="amigos">Só os meus amigos</option>
            <option value="privado">Só eu</option>
          </select>
          <label className="linha" style={{ cursor: "pointer" }}>
            <input type="checkbox" style={{ width: "auto" }} checked={f.invisivel}
              onChange={(e) => setF({ ...f, invisivel: e.target.checked })} />
            Invisível: ninguém vê se estou online nem o que estou jogando
          </label>
          {msg("perfil")}
          <div style={{ marginTop: 18 }}><button type="submit">Salvar perfil</button></div>
        </form>
      </section>

      <section className="cartao">
        <h2>Amigos · {d.amigos.length}</h2>
        <form className="linha" onSubmit={(e) => {
          e.preventDefault();
          acao("amigos", async () => {
            await chamar("/api/web/amigos", "POST", { quem });
            setQuem("");
          }, "Pronto! Se a pessoa aceitar, ela aparece aqui.");
        }}>
          <input style={{ flex: 1, minWidth: 200 }} placeholder="ID SkyNetwork ou código de amigo" value={quem}
            onChange={(e) => setQuem(e.target.value)} required />
          <button type="submit">Adicionar</button>
        </form>
        {msg("amigos")}
        {d.pedidos.length > 0 && (
          <>
            <h2 style={{ marginTop: 20 }}>Pedidos de amizade</h2>
            <ul className="lista">
              {d.pedidos.map((p) => (
                <li key={p.amizadeId}>
                  <Nome p={p} />
                  <button className="pequeno" onClick={() => acao("amigos", () => chamar(`/api/web/amigos/${p.amizadeId}/aceitar`), `Agora você e ${p.apelido} são amigos`)}>Aceitar</button>
                  <button className="pequeno secundario" onClick={() => acao("amigos", () => chamar(`/api/web/amigos/${p.amizadeId}`, "DELETE"), "Pedido recusado")}>Recusar</button>
                </li>
              ))}
            </ul>
          </>
        )}
        <ul className="lista" style={{ marginTop: 14 }}>
          {d.amigos.map((p) => (
            <li key={p.amizadeId}>
              <Nome p={p} />
              <button className="pequeno perigo" onClick={() => {
                if (confirm(`Desfazer a amizade com ${p.apelido}?`)) {
                  acao("amigos", () => chamar(`/api/web/amigos/${p.amizadeId}`, "DELETE"), "Amizade desfeita");
                }
              }}>Desfazer</button>
            </li>
          ))}
          {d.enviados.map((p) => (
            <li key={p.amizadeId}>
              <Nome p={p} />
              <span className="apagado">aguardando</span>
              <button className="pequeno secundario" onClick={() => acao("amigos", () => chamar(`/api/web/amigos/${p.amizadeId}`, "DELETE"), "Pedido cancelado")}>Cancelar</button>
            </li>
          ))}
        </ul>
        {!d.amigos.length && !d.enviados.length && <p className="apagado">Nenhum amigo ainda.</p>}
      </section>

      <section className="cartao">
        <h2>Segurança</h2>
        <form onSubmit={(e) => {
          e.preventDefault();
          if (senha.nova !== senha.nova2) return setAviso({ onde: "senha", texto: "As senhas novas não são iguais.", erro: true });
          acao("senha", async () => {
            await chamar("/api/web/senha", "POST", { atual: senha.atual, nova: senha.nova });
            setSenha({ atual: "", nova: "", nova2: "" });
          }, "Senha trocada. As outras sessões do site foram encerradas.");
        }}>
          <label htmlFor="atual">Senha atual</label>
          <input id="atual" type="password" autoComplete="current-password" value={senha.atual} onChange={(e) => setSenha({ ...senha, atual: e.target.value })} required />
          <label htmlFor="nova">Senha nova</label>
          <input id="nova" type="password" autoComplete="new-password" minLength={6} value={senha.nova} onChange={(e) => setSenha({ ...senha, nova: e.target.value })} required />
          <label htmlFor="nova2">Repita a senha nova</label>
          <input id="nova2" type="password" autoComplete="new-password" value={senha.nova2} onChange={(e) => setSenha({ ...senha, nova2: e.target.value })} required />
          {msg("senha")}
          <div className="linha" style={{ marginTop: 18, justifyContent: "space-between" }}>
            <button type="submit">Trocar a senha</button>
            <button type="button" className="secundario" onClick={async () => {
              await chamar("/api/web/sair");
              router.push("/");
              router.refresh();
            }}>Sair da conta</button>
          </div>
        </form>
        <details style={{ marginTop: 26 }}>
          <summary className="apagado" style={{ cursor: "pointer" }}>Excluir a conta</summary>
          <form onSubmit={async (e) => {
            e.preventDefault();
            const senhaExc = (new FormData(e.currentTarget).get("senhaExc") as string) || "";
            if (!confirm("Excluir a conta para sempre? Amigos, mensagens, troféus e saves na nuvem serão apagados.")) return;
            try {
              await chamar("/api/web/eu", "DELETE", { senha: senhaExc });
              router.push("/");
              router.refresh();
            } catch (err) {
              setAviso({ onde: "excluir", texto: (err as Error).message, erro: true });
            }
          }}>
            <p className="apagado">Apaga o perfil, os amigos, as mensagens, os troféus e os saves na nuvem. Os saves dentro dos consoles continuam lá.</p>
            <label htmlFor="senhaExc">Sua senha</label>
            <input id="senhaExc" name="senhaExc" type="password" autoComplete="current-password" required />
            {msg("excluir")}
            <div style={{ marginTop: 14 }}><button type="submit" className="perigo">Excluir a conta</button></div>
          </form>
        </details>
      </section>
    </div>
  );
}
