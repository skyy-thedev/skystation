"use client";

import { useState } from "react";
import { chamar } from "@/lib/cliente";

type Versao = { id: string; versao: string; notas: string; tamanho: number; enviada: boolean; publicada: boolean; criadaEm: string };
export type ItemAdmin = {
  id: string; slug: string; tipo: string; nome: string; resumo: string; descricao: string; autor: string;
  oficial: boolean; capa: string | null; publicado: boolean; downloads: number; versoes: Versao[];
};

const VAZIO = { slug: "", tipo: "jogo", nome: "", resumo: "", descricao: "", autor: "SkyStation", oficial: true, capa: "", publicado: false };
const TIPOS: Record<string, string> = { app: "App", jogo: "Jogo", tema: "Tema", emulador: "Emulador" };
const mb = (b: number) => (b >= 1073741824 ? `${(b / 1073741824).toFixed(2)} GB` : `${(b / 1048576).toFixed(1)} MB`);

export function AdminLoja({ inicial }: { inicial: ItemAdmin[] }) {
  const [itens, setItens] = useState(inicial);
  const [f, setF] = useState(VAZIO);
  const [aviso, setAviso] = useState<{ texto: string; erro?: boolean } | null>(null);

  async function acao(fn: () => Promise<unknown>, ok: string) {
    setAviso(null);
    try {
      await fn();
      setItens((await chamar<{ itens: ItemAdmin[] }>("/api/admin/loja", "GET")).itens);
      setAviso({ texto: ok });
    } catch (e) {
      setAviso({ texto: (e as Error).message, erro: true });
    }
  }

  const editar = (i: ItemAdmin) => {
    setF({ slug: i.slug, tipo: i.tipo, nome: i.nome, resumo: i.resumo, descricao: i.descricao, autor: i.autor,
      oficial: i.oficial, capa: i.capa ?? "", publicado: i.publicado });
    window.scrollTo({ top: 0, behavior: "smooth" });
  };

  return (
    <div className="abas" style={{ paddingTop: 30 }}>
      <section className="cartao">
        <h1>SkyStore · painel</h1>
        <p className="suave">
          Cadastre o item aqui. Os arquivos são enviados e assinados pelo <code>node scripts/loja.mjs enviar</code> no seu PC
          (a chave privada nunca sobe para o servidor).
        </p>
        <div className="form-loja">
          <label>Slug (endereço, não muda depois)
            <input value={f.slug} onChange={(e) => setF({ ...f, slug: e.target.value.toLowerCase() })} placeholder="objeto-7" />
          </label>
          <label>Tipo
            <select value={f.tipo} onChange={(e) => setF({ ...f, tipo: e.target.value })}>
              {Object.entries(TIPOS).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
            </select>
          </label>
          <label>Nome<input value={f.nome} maxLength={80} onChange={(e) => setF({ ...f, nome: e.target.value })} /></label>
          <label>Autor<input value={f.autor} maxLength={80} onChange={(e) => setF({ ...f, autor: e.target.value })} /></label>
          <label className="largo">Resumo (uma linha na vitrine)
            <input value={f.resumo} maxLength={160} onChange={(e) => setF({ ...f, resumo: e.target.value })} />
          </label>
          <label className="largo">Descrição
            <textarea value={f.descricao} maxLength={4000} rows={4} onChange={(e) => setF({ ...f, descricao: e.target.value })} />
          </label>
          <label className="largo">Capa (endereço https da imagem)
            <input value={f.capa} onChange={(e) => setF({ ...f, capa: e.target.value })} placeholder="https://…" />
          </label>
          <label className="marcar"><input type="checkbox" checked={f.oficial} onChange={(e) => setF({ ...f, oficial: e.target.checked })} /> Oficial da SkyStation</label>
          <label className="marcar"><input type="checkbox" checked={f.publicado} onChange={(e) => setF({ ...f, publicado: e.target.checked })} /> Na vitrine</label>
        </div>
        <div className="linha" style={{ marginTop: 16 }}>
          <button className="pilula" onClick={() => acao(() => chamar("/api/admin/loja", "POST", f), `“${f.nome}” salvo.`)}>Salvar item</button>
          <button className="pilula secundario" onClick={() => setF(VAZIO)}>Novo</button>
        </div>
        {aviso && <p className={aviso.erro ? "erro" : "ok"}>{aviso.texto}</p>}
      </section>

      {itens.length === 0 && <p className="vazio">Nenhum item ainda. Cadastre o primeiro acima.</p>}
      {itens.map((i) => (
        <section className="cartao" key={i.id}>
          <div className="linha" style={{ justifyContent: "space-between" }}>
            <div>
              <h2 style={{ margin: 0 }}>{i.nome} {i.oficial && <span className="selo-oficial">Oficial</span>}</h2>
              <div className="apagado">{TIPOS[i.tipo] ?? i.tipo} · {i.slug} · {i.downloads} downloads · {i.publicado ? "na vitrine" : "escondido"}</div>
            </div>
            <div className="linha">
              <button className="pequeno secundario" onClick={() => editar(i)}>Editar</button>
              <button className="pequeno secundario" onClick={() => acao(() => chamar("/api/admin/loja", "POST", {
                slug: i.slug, tipo: i.tipo, nome: i.nome, publicado: !i.publicado }), i.publicado ? "Saiu da vitrine." : "Na vitrine.")}>
                {i.publicado ? "Esconder" : "Mostrar na vitrine"}
              </button>
            </div>
          </div>
          {i.versoes.length === 0 ? (
            <p className="apagado">Sem versões. No PC: <code>node scripts/loja.mjs enviar pacote.skypkg {i.slug} 1.0</code></p>
          ) : (
            <table className="tabela-versoes">
              <tbody>
                {i.versoes.map((v) => (
                  <tr key={v.id}>
                    <td><b>{v.versao}</b></td>
                    <td>{mb(v.tamanho)}</td>
                    <td>{v.publicada ? "publicada" : v.enviada ? "enviada" : "envio incompleto"}</td>
                    <td className="apagado">{v.notas}</td>
                    <td style={{ textAlign: "right", whiteSpace: "nowrap" }}>
                      {v.enviada && (
                        <button className="pequeno secundario" onClick={() => acao(() => chamar("/api/admin/loja/versoes", "PATCH",
                          { id: v.id, publicada: !v.publicada }), v.publicada ? "Versão tirada do ar." : "Versão publicada.")}>
                          {v.publicada ? "Tirar do ar" : "Publicar"}
                        </button>
                      )}{" "}
                      <button className="pequeno perigo" onClick={() => confirm(`Apagar a versão ${v.versao}?`) &&
                        acao(() => chamar("/api/admin/loja/versoes", "DELETE", { id: v.id }), "Versão apagada.")}>Apagar</button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </section>
      ))}
    </div>
  );
}
