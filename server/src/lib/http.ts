import { NextRequest, NextResponse } from "next/server";
import { ZodError, type ZodType } from "zod";

/** Erro que vira resposta JSON: { erro: "codigo", mensagem: "texto para a tela" }. */
export class Erro extends Error {
  constructor(
    public status: number,
    public codigo: string,
    mensagem: string,
    public extra: Record<string, unknown> = {},
  ) {
    super(mensagem);
  }
}

export function json(dados: unknown, status = 200) {
  return NextResponse.json(dados, { status, headers: { "Cache-Control": "no-store" } });
}

/** Envolve uma rota: transforma Erro e dados inválidos em respostas limpas, nunca em HTML de erro. */
export function rota<C>(fn: (req: NextRequest, ctx: C) => Promise<Response>) {
  return async (req: NextRequest, ctx: C) => {
    try {
      return await fn(req, ctx);
    } catch (e) {
      if (e instanceof Erro) {
        return json({ erro: e.codigo, mensagem: e.message, ...e.extra }, e.status);
      }
      if (e instanceof ZodError) {
        const campo = e.issues[0];
        return json(
          {
            erro: "dados_invalidos",
            mensagem: `Dados inválidos${campo?.path.length ? ` em "${campo.path.join(".")}"` : ""}: ${campo?.message ?? ""}`,
          },
          400,
        );
      }
      console.error(`[${req.method} ${req.nextUrl.pathname}]`, e);
      return json({ erro: "interno", mensagem: "Erro interno do servidor." }, 500);
    }
  };
}

/** Lê e valida o corpo JSON. */
export async function corpo<T>(req: NextRequest, schema: ZodType<T>): Promise<T> {
  let bruto: unknown;
  try {
    bruto = await req.json();
  } catch {
    throw new Erro(400, "json_invalido", "O corpo da requisição não é um JSON válido.");
  }
  return schema.parse(bruto);
}

/** Lê e valida os parâmetros da URL (?a=1&b=2). */
export function consulta<T>(req: NextRequest, schema: ZodType<T>): T {
  return schema.parse(Object.fromEntries(req.nextUrl.searchParams));
}
