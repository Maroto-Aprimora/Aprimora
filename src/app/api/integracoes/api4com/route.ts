import { createClient } from "@supabase/supabase-js";
import type { Database, Json } from "@/lib/supabase/database.types";
import { SUPABASE_KEY, SUPABASE_URL } from "@/lib/supabase/env";

/**
 * Webhook da API4COM ("após desligamento da chamada", versão 1.4): guarda o evento exatamente como chega
 * (eventos_integracoes) para depois virar ligação e trabalho do Agente de ligação. O token vai na URL
 * (?token=…) e é conferido no banco pelo hash em privado.config 'api4com_token_hash'.
 */
async function lerCorpo(request: Request): Promise<Json> {
  const tipo = request.headers.get("content-type") ?? "";
  const texto = await request.text();
  if (!texto) return {};
  if (tipo.includes("application/x-www-form-urlencoded")) return Object.fromEntries(new URLSearchParams(texto));
  try {
    return JSON.parse(texto) as Json;
  } catch {
    return { bruto: texto.slice(0, 20000) };
  }
}

export async function POST(request: Request) {
  const token = new URL(request.url).searchParams.get("token");
  if (!token) return Response.json({ erro: "não autorizado" }, { status: 401 });
  const payload = await lerCorpo(request);
  const supabase = createClient<Database>(SUPABASE_URL, SUPABASE_KEY, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data, error } = await supabase.rpc("registrar_evento_integracao", { _origem: "api4com", _token: token, _payload: payload });
  if (error) {
    const naoAutorizado = error.message.includes("não autorizado");
    return Response.json({ erro: naoAutorizado ? "não autorizado" : "falha ao registrar" }, { status: naoAutorizado ? 401 : 500 });
  }
  return Response.json(data);
}

/** Alguns painéis testam o endereço com GET antes de ativar. */
export function GET() {
  return Response.json({ ok: true, servico: "Portal Aprimora · webhook API4COM" });
}
