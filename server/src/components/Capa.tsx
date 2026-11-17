"use client";

import { useState } from "react";

// Capa de um jogo. Sem imagem (ou se o link da imagem quebrar), desenha uma capa com a cor do
// sistema e o nome do jogo, no estilo das caixas de verdade (faixa do sistema no topo).

type Props = {
  nome: string;
  src: string | null;
  sistema: string; // rótulo já pronto ("PS2")
  cor: string;
  grande?: boolean;
};

export function Capa({ nome, src, sistema, cor, grande }: Props) {
  const [quebrou, setQuebrou] = useState(false);
  const classe = `capa${grande ? " capa-grande" : ""}`;
  if (src && !quebrou) {
    return (
      <div className={classe}>
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src={src} alt={`Capa de ${nome}`} loading="lazy" referrerPolicy="no-referrer" onError={() => setQuebrou(true)} />
        {sistema && <span className="selo-sistema">{sistema}</span>}
      </div>
    );
  }
  return (
    <div className={`${classe} capa-gerada`} style={{ ["--cor-sistema" as string]: cor }} role="img" aria-label={`Capa de ${nome}`}>
      <span className="faixa-sistema">{sistema || "SkyStation"}</span>
      <span className="nome-gerado">{nome}</span>
      {sistema && <span className="selo-sistema">{sistema}</span>}
    </div>
  );
}
