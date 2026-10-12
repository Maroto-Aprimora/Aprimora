import { z } from "zod";
import { exigir, rotaN8n } from "@/lib/n8n";
import type { Json } from "@/lib/supabase/database.types";

const esquema = z.object({ tipo: z.string().min(1).max(100), detalhes: z.record(z.string(), z.unknown()).optional() });

/** Alerta do n8n (ex.: fila acumulada): auditoria + notificação aos diretores. */
export const POST = rotaN8n(async ({ segredo, supabase, corpo }) => {
  const { tipo, detalhes } = esquema.parse(corpo ?? {});
  return exigir(await supabase.rpc("n8n_alerta", { _segredo: segredo, _tipo: tipo, _detalhes: (detalhes ?? {}) as Json }));
});
