import "server-only";
import { carregarConfiguracaoComercial } from "@/lib/crm-servidor";
import { criarClienteServidor } from "@/lib/supabase/server";
import type { ChaveIndicador } from "@/lib/indicadores-catalogo";
import { limitesIso, type Periodo } from "@/lib/periodo";

/**
 * Indicadores do funil comercial, calculados a partir do histórico de movimentações.
 * Regra geral: um negócio "chegou" a uma fase no período quando há um registro de entrada nela
 * dentro do período (cada negócio conta uma vez por fase, mesmo se entrou mais de uma vez).
 */

const PAGINA = 1000;
const DIA_MS = 86_400_000;

/** Busca todas as linhas, página a página (a API devolve no máximo 1000 por vez). */
async function buscarTudo<T>(pagina: (de: number, ate: number) => PromiseLike<{ data: T[] | null; error: unknown }>) {
  const linhas: T[] = [];
  for (let de = 0; ; de += PAGINA) {
    const { data, error } = await pagina(de, de + PAGINA - 1);
    if (error) throw error;
    linhas.push(...(data ?? []));
    if (!data || data.length < PAGINA) return linhas;
  }
}

export async function carregarDadosComerciais(periodo: Periodo) {
  const [config, supabase] = await Promise.all([carregarConfiguracaoComercial(), criarClienteServidor()]);
  const { inicio, fim } = limitesIso(periodo);
  const [negocios, historico, atividades, { data: tipos }, { data: membros }, { data: processos }, { data: motivos }] = await Promise.all([
    buscarTudo((a, b) => supabase.from("negocios")
      .select("id, titulo, created_at, fase_id, valor, ganho_em, encerrado_em, motivo_id, origem_id, responsavel_id, empresas(nome, cidade)")
      .eq("funil_id", config.funil.id).order("created_at").range(a, b)),
    buscarTudo((a, b) => supabase.from("negocio_historico")
      .select("negocio_id, fase_destino_id, created_at, negocios!inner(funil_id)")
      .eq("negocios.funil_id", config.funil.id).order("negocio_id").order("created_at").range(a, b)),
    buscarTudo((a, b) => supabase.from("atividades")
      .select("id, tipo_id, titulo, status, inicio, responsavel_id, negocio_id, resumo, local, atividade_participantes(membro_id), negocios(titulo), empresas(nome)")
      .gte("inicio", inicio).lt("inicio", fim).order("inicio").range(a, b)),
    supabase.from("tipos_atividade").select("id, chave, nome"),
    supabase.from("membros").select("id, nome, data_entrada"),
    supabase.from("processos_seletivos").select("data").order("data"),
    supabase.from("motivos").select("id, nome, tipo"),
  ]);
  return {
    config, periodo, inicio, fim, negocios, historico, atividades,
    tipos: tipos ?? [], membros: membros ?? [], processos: processos ?? [], motivos: motivos ?? [],
  };
}

export type DadosComerciais = Awaited<ReturnType<typeof carregarDadosComerciais>>;

const normalizar = (s: string | null | undefined) => (s ?? "").toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "").trim();
/** Testa se um instante (ISO) cai em [inicio, fim). Compara números: o banco devolve "+00:00" e o JS "Z". */
const dentroDe = (inicio: string, fim: string) => {
  const a = Date.parse(inicio);
  const b = Date.parse(fim);
  return (iso: string | null | undefined) => {
    if (!iso) return false;
    const t = Date.parse(iso);
    return t >= a && t < b;
  };
};
const media = (xs: number[]) => (xs.length ? xs.reduce((s, x) => s + x, 0) / xs.length : null);
const taxa = (parte: number, todo: number) => (todo > 0 ? parte / todo : null);

/** Etapas do funil de conversão (chaves das fases). */
export const ETAPAS_CONVERSAO = [
  { chave: "entrada", rotulo: "Leads" },
  { chave: "email", rotulo: "Em cadência (e-mail/coldcall)" },
  { chave: "oportunidade", rotulo: "Oportunidade" },
  { chave: "diagnostico", rotulo: "Diagnóstico agendado" },
  { chave: "proposta", rotulo: "Proposta apresentada" },
  { chave: "ganho", rotulo: "Contrato fechado" },
] as const;

/** Calcula os indicadores do período. `responsavel` filtra pelos negócios de uma pessoa. */
export function calcularIndicadores(d: DadosComerciais, responsavel?: string | null) {
  const { inicio, fim, config } = d;
  const noPeriodo = dentroDe(inicio, fim);
  const fasePorId = new Map(config.fases.map((f) => [f.id, f]));
  const idFase = (chave: string) => config.fases.find((f) => f.chave === chave)?.id;
  const negocios = responsavel ? d.negocios.filter((n) => n.responsavel_id === responsavel) : d.negocios;
  const ids = new Set(negocios.map((n) => n.id));
  const negocioPorId = new Map(negocios.map((n) => [n.id, n]));
  const historico = d.historico.filter((h) => ids.has(h.negocio_id));

  // Entradas em cada fase dentro do período (um negócio conta uma vez por fase)
  const entradas = new Map<string, Set<string>>();
  for (const h of historico) {
    if (!noPeriodo(h.created_at)) continue;
    if (!entradas.has(h.fase_destino_id)) entradas.set(h.fase_destino_id, new Set());
    entradas.get(h.fase_destino_id)!.add(h.negocio_id);
  }
  const entraramEm = (chave: string) => [...(entradas.get(idFase(chave) ?? "") ?? [])];
  // "Leads" = negócios criados no período (mais confiável que o registro de entrada para dados migrados)
  const leadsNovos = negocios.filter((n) => noPeriodo(n.created_at));
  // Cadência = entrou em E-mail ou direto em Coldcall
  const emCadencia = new Set([...entraramEm("email"), ...entraramEm("coldcall_1")]);

  const ganhos = negocios.filter((n) => noPeriodo(n.ganho_em));
  const perdidos = negocios.filter((n) => noPeriodo(n.encerrado_em) && fasePorId.get(n.fase_id)?.chave === "nao_vendido");
  const desqualificados = negocios.filter((n) => noPeriodo(n.encerrado_em) && fasePorId.get(n.fase_id)?.chave === "nao_qualificado");
  const faturamento = ganhos.reduce((s, n) => s + (n.valor ?? 0), 0);

  const contagemEtapa: Record<string, number> = {
    entrada: leadsNovos.length,
    email: emCadencia.size,
    oportunidade: entraramEm("oportunidade").length,
    diagnostico: entraramEm("diagnostico").length,
    proposta: entraramEm("proposta").length,
    ganho: ganhos.length,
  };
  const funil = ETAPAS_CONVERSAO.map((e, i) => ({
    ...e,
    quantidade: contagemEtapa[e.chave],
    conversao: i === 0 ? null : taxa(contagemEtapa[e.chave], contagemEtapa[ETAPAS_CONVERSAO[i - 1].chave]),
  }));

  // Tempo em cada fase: da entrada até a saída seguinte (saídas dentro do período)
  const tempos = new Map<string, number[]>();
  for (let i = 0; i < historico.length - 1; i++) {
    const atual = historico[i];
    const proximo = historico[i + 1];
    if (proximo.negocio_id !== atual.negocio_id || !noPeriodo(proximo.created_at)) continue;
    const dias = (Date.parse(proximo.created_at) - Date.parse(atual.created_at)) / DIA_MS;
    if (!tempos.has(atual.fase_destino_id)) tempos.set(atual.fase_destino_id, []);
    tempos.get(atual.fase_destino_id)!.push(dias);
  }
  const tempoPorFase = config.fases
    .filter((f) => f.tipo === "aberta" && f.chave !== "entrada")
    .map((f) => ({ fase: f.nome, sla: f.sla_dias, mediaDias: media(tempos.get(f.id) ?? []), amostras: (tempos.get(f.id) ?? []).length }));

  const cicloDias = media(ganhos.map((n) => (Date.parse(n.ganho_em!) - Date.parse(n.created_at)) / DIA_MS));

  // Por responsável (responsável atual do negócio)
  const nomeMembro = new Map(d.membros.map((m) => [m.id, m.nome]));
  const porPessoa = new Map<string, { leads: number; diagnosticos: number; propostas: number; contratos: number; faturamento: number; atividades: number }>();
  const linhaPessoa = (id: string | null) => {
    const k = id ?? "sem";
    if (!porPessoa.has(k)) porPessoa.set(k, { leads: 0, diagnosticos: 0, propostas: 0, contratos: 0, faturamento: 0, atividades: 0 });
    return porPessoa.get(k)!;
  };
  for (const n of leadsNovos) linhaPessoa(n.responsavel_id).leads++;
  for (const id of entraramEm("diagnostico")) linhaPessoa(negocioPorId.get(id)?.responsavel_id ?? null).diagnosticos++;
  for (const id of entraramEm("proposta")) linhaPessoa(negocioPorId.get(id)?.responsavel_id ?? null).propostas++;
  for (const n of ganhos) { const l = linhaPessoa(n.responsavel_id); l.contratos++; l.faturamento += n.valor ?? 0; }
  const atividades = d.atividades.filter((a) => a.status === "realizada" && (!responsavel || a.responsavel_id === responsavel));
  for (const a of atividades) linhaPessoa(a.responsavel_id).atividades++;
  const pessoas = [...porPessoa.entries()]
    .map(([id, v]) => ({ id, nome: id === "sem" ? "Sem responsável" : nomeMembro.get(id) ?? "—", ...v }))
    .sort((a, b) => b.faturamento - a.faturamento || b.contratos - a.contratos || b.diagnosticos - a.diagnosticos || a.nome.localeCompare(b.nome));

  // Por origem do lead
  const nomeOrigem = new Map(config.origens.map((o) => [o.id, o.nome]));
  const porOrigem = new Map<string, { leads: number; diagnosticos: number; contratos: number }>();
  const linhaOrigem = (id: string | null) => {
    const k = (id && nomeOrigem.get(id)) || "Sem origem";
    if (!porOrigem.has(k)) porOrigem.set(k, { leads: 0, diagnosticos: 0, contratos: 0 });
    return porOrigem.get(k)!;
  };
  for (const n of leadsNovos) linhaOrigem(n.origem_id).leads++;
  for (const id of entraramEm("diagnostico")) linhaOrigem(negocioPorId.get(id)?.origem_id ?? null).diagnosticos++;
  for (const n of ganhos) linhaOrigem(n.origem_id).contratos++;
  const origens = [...porOrigem.entries()].map(([origem, v]) => ({ origem, ...v })).sort((a, b) => b.leads - a.leads);

  // Motivos de perda e desqualificação
  const nomeMotivo = new Map(d.motivos.map((m) => [m.id, m.nome]));
  const contarMotivos = (lista: typeof negocios) => {
    const c = new Map<string, number>();
    for (const n of lista) { const k = (n.motivo_id && nomeMotivo.get(n.motivo_id)) || "Sem motivo"; c.set(k, (c.get(k) ?? 0) + 1); }
    return [...c.entries()].map(([motivo, quantidade]) => ({ motivo, quantidade })).sort((a, b) => b.quantidade - a.quantidade);
  };

  // Atividades por tipo
  const nomeTipo = new Map(d.tipos.map((t) => [t.id, t.nome]));
  const atividadesPeriodo = d.atividades.filter((a) => !responsavel || a.responsavel_id === responsavel);
  const porTipo = new Map<string, { realizadas: number; agendadas: number; canceladas: number }>();
  for (const a of atividadesPeriodo) {
    // A remarcada é substituída pela atividade na data nova; contar as duas duplicaria o agendamento
    if (a.status === "remarcada") continue;
    const k = nomeTipo.get(a.tipo_id) ?? "Outro";
    if (!porTipo.has(k)) porTipo.set(k, { realizadas: 0, agendadas: 0, canceladas: 0 });
    const l = porTipo.get(k)!;
    if (a.status === "realizada") l.realizadas++;
    else if (a.status === "cancelada") l.canceladas++;
    else l.agendadas++;
  }

  return {
    resumo: {
      leadsNovos: leadsNovos.length,
      oportunidades: contagemEtapa.oportunidade,
      diagnosticos: contagemEtapa.diagnostico,
      propostas: contagemEtapa.proposta,
      contratos: ganhos.length,
      faturamento,
      ticketMedio: ganhos.length ? faturamento / ganhos.length : null,
      taxaGanho: taxa(ganhos.length, ganhos.length + perdidos.length),
      conversaoLeadContrato: taxa(ganhos.length, leadsNovos.length),
      cicloDias,
      perdidos: perdidos.length,
      desqualificados: desqualificados.length,
    },
    funil,
    tempoPorFase,
    pessoas,
    origens,
    motivosPerda: contarMotivos(perdidos),
    motivosDesqualificacao: contarMotivos(desqualificados),
    atividadesPorTipo: [...porTipo.entries()].map(([tipo, v]) => ({ tipo, ...v })).sort((a, b) => b.realizadas - a.realizadas),
  };
}

export type Indicadores = ReturnType<typeof calcularIndicadores>;

/** Valor de um indicador de meta no período (opcionalmente só de um membro). */
export function valorIndicadorMeta(d: DadosComerciais, chave: ChaveIndicador, membroId?: string | null): number {
  const { inicio, fim, config } = d;
  const noPeriodo = dentroDe(inicio, fim);
  const negocios = membroId ? d.negocios.filter((n) => n.responsavel_id === membroId) : d.negocios;
  const porId = new Map(negocios.map((n) => [n.id, n]));
  const entraram = (faseChave: string) => {
    const faseId = config.fases.find((f) => f.chave === faseChave)?.id;
    const conjunto = new Set<string>();
    for (const h of d.historico) if (h.fase_destino_id === faseId && porId.has(h.negocio_id) && noPeriodo(h.created_at)) conjunto.add(h.negocio_id);
    return [...conjunto].map((id) => porId.get(id)!);
  };
  const atividadesDoTipo = (tipoChave: string) => {
    const tipoId = d.tipos.find((t) => t.chave === tipoChave)?.id;
    return d.atividades.filter((a) => a.tipo_id === tipoId && (!membroId || a.responsavel_id === membroId));
  };

  switch (chave) {
    case "faturamento":
      return negocios.filter((n) => noPeriodo(n.ganho_em)).reduce((s, n) => s + (n.valor ?? 0), 0);
    case "contratos":
      return negocios.filter((n) => noPeriodo(n.ganho_em)).length;
    case "propostas":
      return entraram("proposta").length;
    case "diagnosticos":
      return entraram("diagnostico").length;
    case "oportunidades":
      return entraram("oportunidade").length;
    case "diagnosticos_fora_londrina":
      return entraram("diagnostico").filter((n) => n.empresas?.cidade && normalizar(n.empresas.cidade) !== "londrina").length;
    case "diagnosticos_pos_venda": {
      const posVenda = new Set(config.origens.filter((o) => normalizar(o.nome).startsWith("pos-venda") || normalizar(o.nome).startsWith("pos venda")).map((o) => o.id));
      return entraram("diagnostico").filter((n) => n.origem_id && posVenda.has(n.origem_id)).length;
    }
    case "diagnosticos_membros_novos": {
      // Último processo seletivo que começou até o fim do período
      const fimDia = d.periodo.ate;
      const ultimo = [...d.processos].filter((p) => p.data <= fimDia).at(-1)?.data;
      if (!ultimo) return 0;
      const novos = new Set(d.membros.filter((m) => m.data_entrada && m.data_entrada >= ultimo).map((m) => m.id));
      return entraram("diagnostico").filter((n) => n.responsavel_id && novos.has(n.responsavel_id)).length;
    }
    case "leads_novos":
      return negocios.filter((n) => noPeriodo(n.created_at)).length;
    case "prospectday":
      return atividadesDoTipo("prospectday").filter((a) => a.status !== "cancelada").length;
    case "coldcalls":
      return atividadesDoTipo("coldcall").filter((a) => a.status === "realizada").length;
  }
}
