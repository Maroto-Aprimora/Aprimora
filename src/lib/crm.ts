import type { Enums, Tables } from "@/lib/supabase/database.types";

export type Fase = Tables<"fases">;
export type CampoFase = Tables<"fase_campos">;
export type Motivo = Tables<"motivos">;
export type ResultadoLigacao = Tables<"resultados_ligacao">;
export type MembroResumo = { id: string; nome: string };

export const NOME_MACROETAPA: Record<Enums<"macroetapa">, string> = {
  prospeccao: "Prospecção",
  cadencia: "Cadência",
  oportunidade: "Oportunidade",
  venda: "Venda consultiva",
  ganho: "Ganho",
  pausa: "Pausa",
  perda: "Perda",
};

export const NOME_AREA: Record<Enums<"area_servico">, string> = {
  negocios: "Negócios",
  producao: "Produção",
  qualidade: "Qualidade",
};

/** Situação do SLA de um negócio na fase atual. */
export function situacaoSla(fase: Pick<Fase, "sla_dias">, dias: number): "sem" | "ok" | "atencao" | "estourado" {
  if (!fase.sla_dias) return "sem";
  if (dias >= fase.sla_dias) return "estourado";
  if (dias >= fase.sla_dias * 0.7) return "atencao";
  return "ok";
}

export const NOME_PRAZO_TAREFA: Record<Enums<"prazo_tarefa_auto">, string> = {
  mesmo_dia: "No mesmo dia",
  proximo_dia_util: "No próximo dia útil",
  proximo_toque: "Na próxima ligação (7 dias)",
  data_retorno: "Na data de retorno",
  vespera_compromisso: "Na véspera do compromisso",
};
