import type { Database } from "@/lib/supabase/database.types";

type StatusRelatorio = Database["public"]["Enums"]["status_relatorio"];

export const NOME_STATUS_RELATORIO: Record<StatusRelatorio, string> = { gerando: "Gerando análise…", pronto: "Pronto", erro: "Erro" };
export const TOM_STATUS_RELATORIO: Record<StatusRelatorio, "marca" | "sucesso" | "perigo"> = { gerando: "marca", pronto: "sucesso", erro: "perigo" };

/** Análise escrita pelo Analista gerencial (A4). */
export type AnaliseRelatorio = {
  resumo?: string;
  destaques?: string[];
  pontos_atencao?: string[];
  planos?: { membro: string; pontos_fortes?: string[]; melhorias?: string[]; acoes?: string[] }[];
};

const lista = (titulo: string, itens?: string[]) => (itens?.length ? `${titulo}\n${itens.map((i) => `• ${i}`).join("\n")}` : "");

/** Rascunho em texto corrido para a revisão do diretor. */
export function textoDaAnalise(a: AnaliseRelatorio | null, periodo: string): string {
  if (!a) return "";
  const partes = [
    `Relatório da R.I · ${periodo}`,
    a.resumo ?? "",
    lista("Destaques", a.destaques),
    lista("Pontos de atenção", a.pontos_atencao),
    ...(a.planos ?? []).map((p) => [
      `Plano de melhoria · ${p.membro}`,
      lista("Pontos fortes", p.pontos_fortes),
      lista("Melhorias", p.melhorias),
      lista("Ações", p.acoes),
    ].filter(Boolean).join("\n")),
  ];
  return partes.filter(Boolean).join("\n\n");
}
