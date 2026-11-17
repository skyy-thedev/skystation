"use client";

import avatares from "@/lib/avatares.json";
import { Avatar } from "./Avatar";

export function EscolherAvatar({ valor, mudar }: { valor: string; mudar: (id: string) => void }) {
  return (
    <div className="grade-avatares" role="radiogroup" aria-label="Ícone do perfil">
      {avatares.map((a) => (
        <button key={a.id} type="button" title={a.nome} aria-pressed={valor === a.id} onClick={() => mudar(a.id)}>
          <Avatar id={a.id} tamanho={56} titulo={a.nome} />
        </button>
      ))}
    </div>
  );
}
