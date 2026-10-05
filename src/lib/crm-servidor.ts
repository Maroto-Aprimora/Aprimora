import "server-only";
import { criarClienteServidor } from "@/lib/supabase/server";
import type { MembroResumo } from "@/lib/crm";

/** Tudo o que as telas do CRM precisam para montar formulários e o kanban. */
export async function carregarConfiguracaoComercial() {
  const supabase = await criarClienteServidor();
  const { data: funil } = await supabase.from("funis").select("id, nome").eq("diretoria", "comercial").eq("chave", "comercial").single();
  if (!funil) throw new Error("Funil comercial não encontrado. Rode as migrações do banco.");

  const [fases, campos, motivos, origens, segmentos, servicos, cargos] = await Promise.all([
    supabase.from("fases").select("*").eq("funil_id", funil.id).order("ordem"),
    supabase.from("fase_campos").select("*").order("ordem"),
    supabase.from("motivos").select("*").eq("diretoria", "comercial").order("ordem"),
    supabase.from("origens").select("id, nome, ativo, ordem").eq("diretoria", "comercial").order("ordem"),
    supabase.from("segmentos").select("id, nome, ativo").eq("diretoria", "comercial").order("nome"),
    supabase.from("servicos").select("id, nome, area, descricao, ativo, ordem").eq("diretoria", "comercial").order("ordem"),
    supabase.from("membro_diretorias").select("cargo, membros!inner(id, nome, ativo)").eq("diretoria", "comercial"),
  ]);

  const idsFases = new Set((fases.data ?? []).map((f) => f.id));
  const membrosComercial: MembroResumo[] = (cargos.data ?? [])
    .map((c) => c.membros)
    .filter((m) => m.ativo)
    .map((m) => ({ id: m.id, nome: m.nome }))
    .sort((a, b) => a.nome.localeCompare(b.nome));

  return {
    funil,
    fases: (fases.data ?? []).filter((f) => f.ativa && !f.excluida_em),
    /** Inclui fases desativadas e excluídas: serve para mostrar nomes no histórico. */
    todasFases: fases.data ?? [],
    campos: (campos.data ?? []).filter((c) => idsFases.has(c.fase_id)),
    motivos: (motivos.data ?? []).filter((m) => m.ativo),
    origens: (origens.data ?? []).filter((o) => o.ativo),
    segmentos: (segmentos.data ?? []).filter((s) => s.ativo),
    servicos: (servicos.data ?? []).filter((s) => s.ativo),
    membrosComercial,
  };
}

export type ConfiguracaoComercial = Awaited<ReturnType<typeof carregarConfiguracaoComercial>>;

/** Membros (todas as diretorias) — para campos do tipo "membros", como gerente do projeto. */
export async function carregarTodosMembros(): Promise<MembroResumo[]> {
  const supabase = await criarClienteServidor();
  const { data } = await supabase.from("membros").select("id, nome").eq("ativo", true).order("nome");
  return data ?? [];
}
