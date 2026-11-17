"use client";

import { useState, type ReactNode } from "react";

// Abas da grade de capas (como "Novos lançamentos / Em breve" da loja). Os cartões chegam prontos do
// servidor; aqui só se escolhe qual lista aparece.

type Aba = { id: string; titulo: string; total: number; vazio: string; cartoes: ReactNode };

export function GradeJogos({ abas }: { abas: Aba[] }) {
  const primeira = abas.find((a) => a.total > 0)?.id ?? abas[0]?.id;
  const [atual, setAtual] = useState(primeira);
  const aba = abas.find((a) => a.id === atual) ?? abas[0];
  return (
    <section className="grade-jogos" id="jogos">
      <div className="abas-pilula" role="tablist">
        {abas.map((a) => (
          <button
            key={a.id}
            role="tab"
            aria-selected={a.id === atual}
            className={a.id === atual ? "ativa" : ""}
            onClick={() => setAtual(a.id)}
          >
            {a.titulo}
            {a.total > 0 && <span className="contador">{a.total}</span>}
          </button>
        ))}
      </div>
      {aba && aba.total > 0 ? <div className="capas">{aba.cartoes}</div> : <p className="vazio">{aba?.vazio}</p>}
    </section>
  );
}
