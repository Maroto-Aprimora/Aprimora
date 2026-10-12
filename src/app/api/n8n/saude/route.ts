import { exigir, rotaN8n } from "@/lib/n8n";

/** Saúde da fila (fluxo "Sistema · Monitor da fila"). */
export const GET = rotaN8n(async ({ segredo, supabase }) => exigir(await supabase.rpc("n8n_saude", { _segredo: segredo })));
