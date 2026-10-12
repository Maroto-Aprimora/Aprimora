import { z } from "zod";
import { exigir, rotaN8n, uuid } from "@/lib/n8n";
import type { Json } from "@/lib/supabase/database.types";

const esquema = z.object({ resultado: z.record(z.string(), z.unknown()).optional() });

/** Conclui o trabalho. Se o resultado trouxer `aprovacao`, o item vai para a Caixa de aprovação do responsável. */
export async function POST(request: Request, { params }: { params: Promise<{ id: string }> }) {
  const id = uuid.safeParse((await params).id);
  if (!id.success) return Response.json({ erro: "id inválido" }, { status: 400 });
  return rotaN8n(async ({ segredo, supabase, corpo }) => {
    const { resultado } = esquema.parse(corpo ?? {});
    return exigir(await supabase.rpc("n8n_concluir", { _segredo: segredo, _id: id.data, _resultado: (resultado ?? {}) as Json }));
  })(request);
}
