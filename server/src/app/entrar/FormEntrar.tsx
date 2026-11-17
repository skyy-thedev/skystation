"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { chamar } from "@/lib/cliente";

export function FormEntrar() {
  const router = useRouter();
  const [usuario, setUsuario] = useState("");
  const [senha, setSenha] = useState("");
  const [erro, setErro] = useState("");
  const [enviando, setEnviando] = useState(false);

  async function enviar(e: React.FormEvent) {
    e.preventDefault();
    setErro("");
    setEnviando(true);
    try {
      const r = await chamar<{ usuario: string }>("/api/web/entrar", "POST", { usuario, senha });
      router.push(`/u/${r.usuario}`);
      router.refresh();
    } catch (err) {
      setErro((err as Error).message);
      setEnviando(false);
    }
  }

  return (
    <form onSubmit={enviar}>
      <label htmlFor="usuario">ID SkyNetwork</label>
      <input id="usuario" autoComplete="username" autoCapitalize="none" value={usuario} onChange={(e) => setUsuario(e.target.value)} required />
      <label htmlFor="senha">Senha</label>
      <input id="senha" type="password" autoComplete="current-password" value={senha} onChange={(e) => setSenha(e.target.value)} required />
      {erro && <p className="erro">{erro}</p>}
      <div className="linha" style={{ marginTop: 20, justifyContent: "space-between" }}>
        <button type="submit" disabled={enviando}>{enviando ? "Entrando…" : "Entrar"}</button>
        <Link href="/criar-conta">Criar conta</Link>
      </div>
      <p className="apagado" style={{ marginTop: 22 }}>
        Esqueceu a senha? No SkyStation onde você usa a conta: Configurações → SkyNetwork → Trocar a senha.
      </p>
    </form>
  );
}
