import type { Metadata } from "next";
import type { ReactNode } from "react";

export const metadata: Metadata = {
  title: "SkyNetwork",
  description: "Servidor do SkyStation: saves na nuvem, amigos, mensagens e troféus.",
  robots: { index: false },
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="pt-BR">
      <body
        style={{
          margin: 0,
          minHeight: "100vh",
          display: "grid",
          placeItems: "center",
          background: "#070b14",
          color: "#e8f1ff",
          fontFamily: "system-ui, sans-serif",
        }}
      >
        {children}
      </body>
    </html>
  );
}
