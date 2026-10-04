import "server-only";
import { situacaoSla } from "@/lib/crm";
import { carregarConfiguracaoComercial } from "@/lib/crm-servidor";
import { criarClienteServidor } from "@/lib/supabase/server";
import { diasDesde } from "@/lib/formatar";

/** Números do funil comercial usados no painel geral e no painel do Comercial. */
export async function resumoComercial(usuarioId: string) {
  const [config, supabase] = await Promise.all([carregarConfiguracaoComercial(), criarClienteServidor()]);
  const agora = new Date();
  const inicioTrimestre = new Date(agora.getFullYear(), Math.floor(agora.getMonth() / 3) * 3, 1).toISOString();

  const [{ data: abertos }, { data: ganhos }, { count: novos }] = await Promise.all([
    supabase.from("negocios").select("id, titulo, fase_id, responsavel_id, valor, entrou_na_fase_em").eq("funil_id", config.funil.id).is("encerrado_em", null),
    supabase.from("negocios").select("valor").eq("funil_id", config.funil.id).gte("ganho_em", inicioTrimestre),
    supabase.from("negocios").select("id", { count: "exact", head: true }).eq("funil_id", config.funil.id).gte("created_at", inicioTrimestre),
  ]);

  const fases = new Map(config.fases.map((f) => [f.id, f]));
  const lista = abertos ?? [];
  const estourados = lista
    .map((n) => ({ ...n, fase: fases.get(n.fase_id)!, dias: diasDesde(n.entrou_na_fase_em) }))
    .filter((n) => n.fase && situacaoSla(n.fase, n.dias) === "estourado");
  const porMacro = config.fases
    .filter((f) => f.tipo === "aberta")
    .reduce<Record<string, number>>((acc, f) => {
      acc[f.macroetapa] = (acc[f.macroetapa] ?? 0) + lista.filter((n) => n.fase_id === f.id).length;
      return acc;
    }, {});

  return {
    ativos: lista.length,
    meus: lista.filter((n) => n.responsavel_id === usuarioId).length,
    novos: novos ?? 0,
    receita: (ganhos ?? []).reduce((s, n) => s + (n.valor ?? 0), 0),
    ganhos: (ganhos ?? []).length,
    ponderado: lista.reduce((s, n) => s + (n.valor ?? 0) * (fases.get(n.fase_id)?.probabilidade ?? 0), 0),
    estourados,
    porMacro,
  };
}
