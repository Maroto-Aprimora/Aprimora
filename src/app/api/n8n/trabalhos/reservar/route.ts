import { z } from "zod";
import { exigir, rotaN8n } from "@/lib/n8n";

const esquema = z.object({ agente: z.string().min(1).optional(), limite: z.number().int().min(1).max(20).optional() });

/** Reserva até `limite` trabalhos pendentes de agentes ligados (opcionalmente de um agente). */
export const POST = rotaN8n(async ({ segredo, supabase, corpo }) => {
  const { agente, limite } = esquema.parse(corpo ?? {});
  return exigir(await supabase.rpc("n8n_reservar", { _segredo: segredo, ...(agente ? { _agente: agente } : {}), _limite: limite ?? 3 }));
});
