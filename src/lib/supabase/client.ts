import { createBrowserClient } from "@supabase/ssr";
import { createClient as createPlainClient } from "@supabase/supabase-js";
import type { Database } from "./database.types";
import { SUPABASE_KEY, SUPABASE_URL } from "./env";

/** Cliente do navegador (sessão em cookies, compartilhada com o servidor). */
export function criarClienteNavegador() {
  return createBrowserClient<Database>(SUPABASE_URL, SUPABASE_KEY);
}

/**
 * Cliente avulso, sem sessão, usado só para disparar e-mails de convite para OUTRA pessoa.
 * Usa o fluxo "implicit" porque o link será aberto em outro navegador (o do convidado),
 * onde não existe o "code verifier" do fluxo PKCE.
 */
export function criarClienteConvite() {
  return createPlainClient<Database>(SUPABASE_URL, SUPABASE_KEY, {
    auth: { flowType: "implicit", persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
  });
}
