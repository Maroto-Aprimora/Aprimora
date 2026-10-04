import type { Enums, Tables } from "@/lib/supabase/database.types";
import { diaDaSemana, somarDias } from "@/lib/datas";

export type TipoAtividade = Tables<"tipos_atividade">;
export type ReuniaoRecorrente = Tables<"reunioes_recorrentes">;
export type StatusAtividade = Enums<"status_atividade">;

/** Cores dos tipos de atividade (chaves guardadas no banco → classes Tailwind com os tokens). */
export const COR_TIPO: Record<string, string> = {
  destaque: "bg-destaque text-white",
  marca: "bg-marca text-marca-texto",
  sucesso: "bg-sucesso text-white",
  azul: "bg-azul-claro text-marca-forte",
  roxo: "bg-roxo text-white",
  cinza: "bg-texto-suave text-white",
};
export const CORES_DISPONIVEIS = Object.keys(COR_TIPO);

export const NOME_STATUS: Record<StatusAtividade, string> = {
  pendente: "Pendente",
  confirmada: "Confirmada",
  realizada: "Realizada",
  cancelada: "Cancelada",
};

/** Item mostrado na agenda: atividade gravada ou ocorrência calculada de reunião recorrente. */
export type ItemAgenda = {
  id: string;
  recorrente: boolean;
  titulo: string;
  tipoId: string;
  inicio: string;
  fim: string | null;
  local: string | null;
  status: StatusAtividade | null;
  responsavelId: string | null;
  participantes: string[];
  negocioId: string | null;
  empresaNome: string | null;
};

/** Ocorrências das reuniões recorrentes entre dois dias (inclusive). Horários em Brasília (−03:00). */
export function ocorrenciasRecorrentes(reunioes: ReuniaoRecorrente[], de: string, ate: string): ItemAgenda[] {
  const itens: ItemAgenda[] = [];
  for (let dia = de; dia <= ate; dia = somarDias(dia, 1)) {
    const dow = diaDaSemana(dia);
    for (const r of reunioes) {
      if (!r.ativa || r.dia_semana !== dow || r.valida_de > dia || (r.valida_ate && r.valida_ate < dia)) continue;
      itens.push({
        id: `${r.id}:${dia}`,
        recorrente: true,
        titulo: r.titulo,
        tipoId: r.tipo_id,
        inicio: new Date(`${dia}T${r.hora_inicio.slice(0, 5)}:00-03:00`).toISOString(),
        fim: new Date(`${dia}T${r.hora_fim.slice(0, 5)}:00-03:00`).toISOString(),
        local: r.local,
        status: null,
        responsavelId: null,
        participantes: [],
        negocioId: null,
        empresaNome: null,
      });
    }
  }
  return itens;
}
