import { carregarConfiguracaoComercial } from "@/lib/crm-servidor";
import { calcularIndicadores, carregarDadosComerciais } from "@/lib/indicadores";
import { gerarCsv, gerarXlsx, type Planilha } from "@/lib/exportar";
import { periodoDosParametros } from "@/lib/periodo";
import { criarClienteServidor } from "@/lib/supabase/server";
import { diaBR } from "@/lib/datas";

const arred = (v: number | null, casas = 1) => (v == null ? null : Math.round(v * 10 ** casas) / 10 ** casas);

/** Exporta os indicadores do período ou a lista de negócios, em .xlsx ou .csv. Respeita o RLS de quem pede. */
export async function GET(request: Request) {
  const url = new URL(request.url);
  const sp = Object.fromEntries(url.searchParams.entries());
  const supabase = await criarClienteServidor();
  const { data: sessao } = await supabase.auth.getClaims();
  if (!sessao?.claims?.sub) return new Response("Não autorizado", { status: 401 });

  const periodo = periodoDosParametros(sp);
  const formato = sp.formato === "csv" ? "csv" : "xlsx";
  const conteudo = sp.conteudo === "negocios" ? "negocios" : "indicadores";
  const responsavel = sp.resp || null;
  let planilhas: Planilha[];

  if (conteudo === "indicadores") {
    const dados = await carregarDadosComerciais(periodo);
    const ind = calcularIndicadores(dados, responsavel);
    const r = ind.resumo;
    planilhas = [
      {
        nome: "Resumo",
        colunas: ["Indicador", "Valor"],
        linhas: [
          ["Período", `${periodo.de} a ${periodo.ate}`],
          ["Responsável", responsavel ? dados.membros.find((m) => m.id === responsavel)?.nome ?? responsavel : "Toda a equipe"],
          ["Leads novos", r.leadsNovos],
          ["Oportunidades", r.oportunidades],
          ["Diagnósticos marcados", r.diagnosticos],
          ["Propostas apresentadas", r.propostas],
          ["Contratos fechados", r.contratos],
          ["Faturamento (R$)", r.faturamento],
          ["Ticket médio (R$)", arred(r.ticketMedio, 2)],
          ["Taxa de ganho (%)", arred(r.taxaGanho == null ? null : r.taxaGanho * 100)],
          ["Conversão lead → contrato (%)", arred(r.conversaoLeadContrato == null ? null : r.conversaoLeadContrato * 100)],
          ["Ciclo de venda (dias)", arred(r.cicloDias)],
          ["Projetos não vendidos", r.perdidos],
          ["Leads não qualificados", r.desqualificados],
        ],
      },
      { nome: "Funil", colunas: ["Etapa", "Quantidade", "Conversão da etapa anterior (%)"],
        linhas: ind.funil.map((e) => [e.rotulo, e.quantidade, arred(e.conversao == null ? null : e.conversao * 100)]) },
      { nome: "Tempo por fase", colunas: ["Fase", "Média (dias)", "SLA (dias)", "Saídas no período"],
        linhas: ind.tempoPorFase.map((t) => [t.fase, arred(t.mediaDias), t.sla, t.amostras]) },
      { nome: "Por responsável", colunas: ["Pessoa", "Leads", "Diagnósticos", "Propostas", "Contratos", "Faturamento (R$)", "Atividades realizadas"],
        linhas: ind.pessoas.map((p) => [p.nome, p.leads, p.diagnosticos, p.propostas, p.contratos, p.faturamento, p.atividades]) },
      { nome: "Origens", colunas: ["Origem", "Leads", "Diagnósticos", "Contratos"],
        linhas: ind.origens.map((o) => [o.origem, o.leads, o.diagnosticos, o.contratos]) },
      { nome: "Motivos", colunas: ["Tipo", "Motivo", "Quantidade"],
        linhas: [...ind.motivosPerda.map((m) => ["Perda", m.motivo, m.quantidade]), ...ind.motivosDesqualificacao.map((m) => ["Desqualificação", m.motivo, m.quantidade])] },
      { nome: "Atividades", colunas: ["Tipo", "Realizadas", "Agendadas", "Canceladas"],
        linhas: ind.atividadesPorTipo.map((a) => [a.tipo, a.realizadas, a.agendadas, a.canceladas]) },
    ];
  } else {
    const config = await carregarConfiguracaoComercial();
    const { data: membros } = await supabase.from("membros").select("id, nome");
    let consulta = supabase.from("negocios")
      .select("titulo, valor, created_at, entrou_na_fase_em, ganho_em, encerrado_em, fase_id, responsavel_id, origem_id, motivo_id, ficticio, empresas(nome, cnpj, cidade, uf, telefone, email_principal)")
      .eq("funil_id", config.funil.id).order("created_at", { ascending: false }).limit(5000);
    if (responsavel) consulta = consulta.eq("responsavel_id", responsavel);
    const { data: negocios } = await consulta;
    const nome = (id: string | null, lista: { id: string; nome: string }[] | null) => (id && lista?.find((x) => x.id === id)?.nome) || "";
    const dia = (iso: string | null) => (iso ? diaBR(iso) : null);
    planilhas = [{
      nome: "Negócios",
      colunas: ["Negócio", "Empresa", "CNPJ", "Cidade", "UF", "Telefone", "E-mail", "Fase", "Responsável", "Origem", "Valor (R$)",
        "Criado em", "Na fase desde", "Ganho em", "Encerrado em", "Motivo", "Fictício"],
      linhas: (negocios ?? []).map((n) => [
        n.titulo, n.empresas?.nome ?? "", n.empresas?.cnpj ?? "", n.empresas?.cidade ?? "", n.empresas?.uf ?? "", n.empresas?.telefone ?? "",
        n.empresas?.email_principal ?? "", nome(n.fase_id, config.fases), nome(n.responsavel_id, membros), nome(n.origem_id, config.origens),
        n.valor, dia(n.created_at), dia(n.entrou_na_fase_em), dia(n.ganho_em), dia(n.encerrado_em), nome(n.motivo_id, config.motivos),
        n.ficticio ? "sim" : "",
      ]),
    }];
  }

  const base = `aprimora-${conteudo}-${periodo.de}-a-${periodo.ate}`;
  if (formato === "csv") {
    return new Response(gerarCsv(planilhas), {
      headers: { "Content-Type": "text/csv; charset=utf-8", "Content-Disposition": `attachment; filename="${base}.csv"`, "Cache-Control": "no-store" },
    });
  }
  const arquivo = await gerarXlsx(planilhas);
  return new Response(new Uint8Array(arquivo), {
    headers: {
      "Content-Type": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      "Content-Disposition": `attachment; filename="${base}.xlsx"`,
      "Cache-Control": "no-store",
    },
  });
}
