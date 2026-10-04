import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";
import type { Database } from "./database.types";
import { SUPABASE_KEY, SUPABASE_URL } from "./env";

/** Cliente do servidor (Server Components, Server Actions e Route Handlers). Sempre age como o usuário logado. */
export async function criarClienteServidor() {
  const cookieStore = await cookies();
  return createServerClient<Database>(SUPABASE_URL, SUPABASE_KEY, {
    cookies: {
      getAll() {
        return cookieStore.getAll();
      },
      setAll(cookiesToSet) {
        try {
          cookiesToSet.forEach(({ name, value, options }) => cookieStore.set(name, value, options));
        } catch {
          // Chamado a partir de um Server Component: o proxy já renova a sessão.
        }
      },
    },
  });
}
