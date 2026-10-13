import { z } from "zod";
import { exigir, rotaN8n } from "@/lib/n8n";
import type { Json } from "@/lib/supabase/database.types";

const esquema = z.object({ chamadas: z.array(z.record(z.string(), z.unknown())).max(200) });

/** Chamadas da API4COM consultadas pelo n8n (GET /api/v1/calls). Cada chamada entra uma vez só. */
export const POST = rotaN8n(async ({ segredo, supabase, corpo }) => {
  const { chamadas } = esquema.parse(corpo ?? {});
  return exigir(await supabase.rpc("n8n_registrar_chamadas", { _segredo: segredo, _chamadas: chamadas as Json }));
});
