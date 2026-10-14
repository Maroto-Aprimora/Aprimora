import { z } from "zod";
import { exigir, rotaN8n } from "@/lib/n8n";
import type { Json } from "@/lib/supabase/database.types";

const esquema = z.object({
  mensagens: z.array(z.object({
    gmail_id: z.string().min(1),
    thread_id: z.string().min(1),
    de: z.string().optional(),
    assunto: z.string().optional(),
    trecho: z.string().optional(),
    recebido_em: z.string().optional(),
  })).max(200),
});

/**
 * A6 · Monitor de respostas: mensagens novas da caixa da comercial@ (o n8n consulta o Gmail a cada 5 minutos).
 * Só entram as que respondem um fio de e-mail enviado pelo portal; cada mensagem entra uma vez só.
 */
export const POST = rotaN8n(async ({ segredo, supabase, corpo }) => {
  const { mensagens } = esquema.parse(corpo ?? {});
  return exigir(await supabase.rpc("n8n_registrar_respostas", { _segredo: segredo, _mensagens: mensagens as Json }));
});
