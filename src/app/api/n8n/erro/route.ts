import { z } from "zod";
import { exigir, rotaN8n } from "@/lib/n8n";

const texto = z.union([z.string(), z.number()]).transform(String).optional().nullable();
const esquema = z.object({ fluxo: z.string().max(300).optional().nullable(), execucao_id: texto, execucao_url: texto, no: texto, mensagem: texto });

/** Um fluxo do n8n quebrou (fluxo "Sistema · Tratamento de erros"): auditoria + notificação aos diretores. */
export const POST = rotaN8n(async ({ segredo, supabase, corpo }) => {
  const e = esquema.parse(corpo ?? {});
  return exigir(await supabase.rpc("n8n_erro", {
    _segredo: segredo, _fluxo: e.fluxo ?? "—",
    ...(e.execucao_id ? { _execucao_id: e.execucao_id } : {}), ...(e.execucao_url ? { _execucao_url: e.execucao_url } : {}),
    ...(e.no ? { _no: e.no } : {}), ...(e.mensagem ? { _mensagem: e.mensagem } : {}),
  }));
});
