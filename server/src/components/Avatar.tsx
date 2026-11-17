import avatares from "@/lib/avatares.json";

const IDS = new Set(avatares.map((a) => a.id));

/** Ícone de perfil do SkyStation (SVG em /public/avatares). */
export function Avatar({ id, tamanho = 48, titulo }: { id: string; tamanho?: number; titulo?: string }) {
  const certo = IDS.has(id) ? id : "estrela";
  return (
    // eslint-disable-next-line @next/next/no-img-element
    <img className="avatar" src={`/avatares/${certo}.svg`} width={tamanho} height={tamanho} alt={titulo ?? ""} />
  );
}
