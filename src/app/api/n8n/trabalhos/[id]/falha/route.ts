import { z } from "zod";
import { exigir, rotaN8n, uuid } from "@/lib/n8n";

const esquema = z.object({ etapa: z.string().max(200).optional(), mensagem: z.string().max(4000).optional() });

/** Registra a falha: o trabalho volta para a fila com espera crescente; depois de 3 tentativas, fica com erro. */
export async function POST(request: Request, { params }: { params: Promise<{ id: string }> }) {
  const id = uuid.safeParse((await params).id);
  if (!id.success) return Response.json({ erro: "id inválido" }, { status: 400 });
  return rotaN8n(async ({ segredo, supabase, corpo }) => {
    const { etapa, mensagem } = esquema.parse(corpo ?? {});
    return exigir(await supabase.rpc("n8n_falhar", { _segredo: segredo, _id: id.data, _etapa: etapa ?? "", _mensagem: mensagem ?? "" }));
  })(request);
}
