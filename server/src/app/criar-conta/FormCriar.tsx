"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { EscolherAvatar } from "@/components/EscolherAvatar";
import { chamar } from "@/lib/cliente";

export function FormCriar() {
  const router = useRouter();
  const [f, setF] = useState({ convite: "", usuario: "", apelido: "", senha: "", senha2: "", avatar: "estrela" });
  const [erro, setErro] = useState("");
  const [enviando, setEnviando] = useState(false);
  const muda = (k: keyof typeof f) => (e: React.ChangeEvent<HTMLInputElement>) => setF({ ...f, [k]: e.target.value });

  async function enviar(e: React.FormEvent) {
    e.preventDefault();
    setErro("");
    if (f.senha !== f.senha2) return setErro("As senhas não são iguais.");
    setEnviando(true);
    try {
      const { senha2: _, ...corpo } = f;
      const r = await chamar<{ usuario: string }>("/api/web/registrar", "POST", corpo);
      router.push(`/u/${r.usuario}`);
      router.refresh();
    } catch (err) {
      setErro((err as Error).message);
      setEnviando(false);
    }
  }

  return (
    <form onSubmit={enviar}>
      <label htmlFor="convite">Código de convite</label>
      <input id="convite" value={f.convite} onChange={muda("convite")} required />
      <label htmlFor="usuario">ID SkyNetwork (para entrar; aparece no endereço do seu perfil)</label>
      <input id="usuario" autoCapitalize="none" autoComplete="username" pattern="[A-Za-z0-9_]{3,16}"
        title="3 a 16 letras, números ou _" value={f.usuario} onChange={muda("usuario")} required />
      <label htmlFor="apelido">Nome que aparece para os amigos</label>
      <input id="apelido" maxLength={24} value={f.apelido} onChange={muda("apelido")} required />
      <label>Ícone do perfil</label>
      <EscolherAvatar valor={f.avatar} mudar={(avatar) => setF({ ...f, avatar })} />
      <label htmlFor="senha">Senha (mínimo 6 caracteres)</label>
      <input id="senha" type="password" autoComplete="new-password" minLength={6} value={f.senha} onChange={muda("senha")} required />
      <label htmlFor="senha2">Repita a senha</label>
      <input id="senha2" type="password" autoComplete="new-password" value={f.senha2} onChange={muda("senha2")} required />
      {erro && <p className="erro">{erro}</p>}
      <div style={{ marginTop: 22 }}>
        <button type="submit" disabled={enviando}>{enviando ? "Criando…" : "Criar conta"}</button>
      </div>
    </form>
  );
}
