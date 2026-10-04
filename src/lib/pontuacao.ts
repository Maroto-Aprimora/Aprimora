/** Sistema de pontos da Aprimora: punição por atividades não realizadas, de 0 a 12, com marco no 6. */
export const PONTOS_MAXIMO = 12;
export const PONTOS_MARCO = 6;

/** Total válido (soma dos lançamentos não cancelados, limitado a 0..12). */
export function totalPontos(lancamentos: { pontos: number; cancelado_em: string | null }[]) {
  const soma = lancamentos.filter((l) => !l.cancelado_em).reduce((s, l) => s + l.pontos, 0);
  return Math.max(0, Math.min(PONTOS_MAXIMO, soma));
}

export function situacaoPontos(total: number): "ok" | "atencao" | "marco" {
  if (total >= PONTOS_MARCO) return "marco";
  if (total >= PONTOS_MARCO - 2) return "atencao";
  return "ok";
}
