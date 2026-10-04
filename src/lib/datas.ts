/**
 * Datas no fuso de Brasília (America/Sao_Paulo, UTC−3 sem horário de verão desde 2019).
 * O banco guarda tudo em UTC (timestamptz); a tela mostra e recebe horários de Brasília.
 */
export const FUSO = "America/Sao_Paulo";
const OFFSET = "-03:00";

/** "2026-10-05T15:30" (campo datetime-local) → ISO em UTC. */
export function deHorarioLocal(valor: string | null | undefined): string | null {
  if (!valor) return null;
  const comSegundos = valor.length === 16 ? `${valor}:00` : valor;
  return new Date(`${comSegundos}${OFFSET}`).toISOString();
}

/** ISO → "2026-10-05T15:30" para preencher um campo datetime-local. */
export function paraHorarioLocal(iso: string | null | undefined): string {
  if (!iso) return "";
  const p = partes(iso);
  return `${p.ano}-${p.mes}-${p.dia}T${p.hora}:${p.minuto}`;
}

/** Dia (AAAA-MM-DD) em Brasília de um instante. */
export function diaBR(iso: string | Date): string {
  const p = partes(typeof iso === "string" ? iso : iso.toISOString());
  return `${p.ano}-${p.mes}-${p.dia}`;
}

export function horaBR(iso: string): string {
  const p = partes(iso);
  return `${p.hora}:${p.minuto}`;
}

export function hojeBR(): string {
  return diaBR(new Date());
}

function partes(iso: string) {
  const f = new Intl.DateTimeFormat("en-CA", {
    timeZone: FUSO, year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit", hour12: false,
  }).formatToParts(new Date(iso));
  const v = (t: string) => f.find((x) => x.type === t)?.value ?? "00";
  return { ano: v("year"), mes: v("month"), dia: v("day"), hora: v("hour") === "24" ? "00" : v("hour"), minuto: v("minute") };
}

/** Soma dias a uma data "AAAA-MM-DD". */
export function somarDias(dia: string, n: number): string {
  const d = new Date(`${dia}T12:00:00Z`);
  d.setUTCDate(d.getUTCDate() + n);
  return d.toISOString().slice(0, 10);
}

/** Dia da semana (0 = domingo) de uma data "AAAA-MM-DD". */
export function diaDaSemana(dia: string): number {
  return new Date(`${dia}T12:00:00Z`).getUTCDay();
}

export const NOMES_DIA = ["Domingo", "Segunda", "Terça", "Quarta", "Quinta", "Sexta", "Sábado"];
export const NOMES_MES = ["janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho", "agosto", "setembro", "outubro", "novembro", "dezembro"];
