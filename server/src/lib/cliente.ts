/** fetch para as rotas do site: devolve o JSON ou lança Error com a mensagem do servidor. */
export async function chamar<T = Record<string, unknown>>(caminho: string, metodo = "POST", corpo?: unknown): Promise<T> {
  const r = await fetch(caminho, {
    method: metodo,
    headers: corpo !== undefined ? { "Content-Type": "application/json" } : undefined,
    body: corpo !== undefined ? JSON.stringify(corpo) : undefined,
    credentials: "same-origin",
  });
  const dados = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error(dados.mensagem || "Não deu certo. Tente de novo.");
  return dados as T;
}
