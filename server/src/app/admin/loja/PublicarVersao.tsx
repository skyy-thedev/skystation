"use client";

import { useRef, useState } from "react";
import { chamar } from "@/lib/cliente";
import { assinar, chavePublicaDe, lerPasta, mensagemAssinada, sha256Hex, tarGz } from "@/lib/pacote-navegador";

// Publicar uma versão sem terminal: escolhe a pasta do jogo e a chave privada; o navegador empacota, assina e
// envia. A chave é lida só nesta aba (não vai para o servidor nem fica salva).

const LIMITE_SERVIDOR = 4 * 1024 * 1024;
const mb = (b: number) => `${(b / 1048576).toFixed(2)} MB`;

async function lerChave(input: HTMLInputElement | null) {
  const f = input?.files?.[0];
  if (!f) throw new Error("Escolha o arquivo da chave privada (chave-privada.pem).");
  return f.text();
}

export function PublicarVersao({ slug, sugestao, aoTerminar }: { slug: string; sugestao: string; aoTerminar: () => void }) {
  const pasta = useRef<HTMLInputElement>(null);
  const chave = useRef<HTMLInputElement>(null);
  const [versao, setVersao] = useState(sugestao);
  const [notas, setNotas] = useState("");
  const [publicar, setPublicar] = useState(true);
  const [passo, setPasso] = useState("");
  const [erro, setErro] = useState("");
  const [ocupado, setOcupado] = useState(false);

  async function enviar() {
    setErro("");
    setOcupado(true);
    try {
      if (!/^\d{1,4}(\.\d{1,4}){0,3}(-[a-z0-9.]{1,16})?$/.test(versao)) throw new Error("Versão no formato 1.0 ou 0.3.1");
      if (!pasta.current?.files?.length) throw new Error("Escolha a pasta do jogo.");
      const pem = await lerChave(chave.current);
      setPasso("Lendo a pasta…");
      const arquivos = await lerPasta(pasta.current.files);
      setPasso(`Empacotando ${arquivos.length} arquivos…`);
      const pacote = await tarGz(arquivos);
      const sha256 = await sha256Hex(pacote);
      setPasso("Assinando (no seu computador)…");
      const assinatura = await assinar(pem, mensagemAssinada(slug, versao, sha256, pacote.length));
      setPasso(`Enviando ${mb(pacote.length)}…`);
      const ini = await chamar<{ versaoId: string; url: string }>("/api/admin/loja/versoes", "POST", {
        slug, versao, sha256, tamanho: pacote.length, assinatura, ...(notas ? { notas } : {}),
      });
      let foi = false;
      try {
        const r = await fetch(ini.url, { method: "PUT", body: pacote as BodyInit });   // direto ao R2 (precisa de CORS)
        foi = r.ok;
      } catch {
        foi = false;
      }
      if (!foi) {
        if (pacote.length > LIMITE_SERVIDOR) {
          throw new Error(`Pacote de ${mb(pacote.length)}: acima de 4 MB o envio é direto ao R2 e ele ainda não aceita o site ` +
            "(configure o CORS do bucket) — ou use o loja.mjs enviar.");
        }
        const r = await fetch(`/api/admin/loja/versoes/arquivo?id=${encodeURIComponent(ini.versaoId)}`, {
          method: "POST", body: pacote as BodyInit, credentials: "same-origin",
        });
        if (!r.ok) throw new Error((await r.json().catch(() => ({}))).mensagem || "O envio falhou.");
      }
      setPasso("Conferindo…");
      await chamar("/api/admin/loja/versoes/confirmar", "POST", { id: ini.versaoId, publicar });
      setPasso(`Versão ${versao} ${publicar ? "publicada" : "enviada (ainda fora do ar)"} · ${mb(pacote.length)}`);
      aoTerminar();
    } catch (e) {
      setPasso("");
      setErro((e as Error).message);
    } finally {
      setOcupado(false);
    }
  }

  return (
    <div className="publicar-versao">
      <h3>Publicar nova versão</h3>
      <div className="form-loja">
        <label>Pasta do jogo (com o game.json)
          <input ref={pasta} type="file" {...{ webkitdirectory: "", directory: "" }} multiple />
        </label>
        <label>Chave privada (chave-privada.pem)
          <input ref={chave} type="file" accept=".pem" />
        </label>
        <label>Versão<input value={versao} onChange={(e) => setVersao(e.target.value.trim())} placeholder="0.3" /></label>
        <label className="marcar"><input type="checkbox" checked={publicar} onChange={(e) => setPublicar(e.target.checked)} /> Já publicar (consoles veem na hora)</label>
        <label className="largo">Novidades desta versão
          <textarea rows={2} maxLength={2000} value={notas} onChange={(e) => setNotas(e.target.value)} />
        </label>
      </div>
      <div className="linha" style={{ marginTop: 12 }}>
        <button className="pilula" disabled={ocupado} onClick={enviar}>{ocupado ? "Trabalhando…" : "Empacotar, assinar e enviar"}</button>
        {passo && <span className={ocupado ? "apagado" : "ok"}>{passo}</span>}
      </div>
      {erro && <p className="erro">{erro}</p>}
      <p className="apagado" style={{ marginBottom: 0 }}>
        A chave é lida só nesta aba para assinar e não é enviada a lugar nenhum. A pasta <code>.godot</code> fica de fora
        (o console prepara o jogo ao instalar).
      </p>
    </div>
  );
}

/** Mostra a chave PÚBLICA a partir da privada (para a Vercel e para o console). */
export function VerChavePublica() {
  const chave = useRef<HTMLInputElement>(null);
  const [pub, setPub] = useState("");
  const [erro, setErro] = useState("");
  return (
    <div className="publicar-versao">
      <h3>Chave pública</h3>
      <p className="apagado">Escolha a chave-privada.pem: a pública aparece aqui (ela não é segredo).</p>
      <div className="linha">
        <input ref={chave} type="file" accept=".pem" onChange={async () => {
          setErro(""); setPub("");
          try { setPub(await chavePublicaDe(await lerChave(chave.current))); } catch (e) { setErro((e as Error).message); }
        }} />
      </div>
      {pub && <p><code className="chave-publica">{pub}</code></p>}
      {erro && <p className="erro">{erro}</p>}
    </div>
  );
}
