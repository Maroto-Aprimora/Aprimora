import { gerarCsv, gerarXlsx, type Planilha } from "@/lib/exportar";
import { criarClienteServidor } from "@/lib/supabase/server";
import { hojeBR } from "@/lib/datas";
import { consultarLeads, lerFiltros, NOME_SITUACAO } from "../dados";

/** Exporta os Leads StockFacil (com os filtros da página) em .xlsx ou .csv. Só o Diretor Comercial (RLS). */
export async function GET(request: Request) {
  const url = new URL(request.url);
  const sp = Object.fromEntries(url.searchParams.entries());
  const supabase = await criarClienteServidor();
  const { data: sessao } = await supabase.auth.getClaims();
  if (!sessao?.claims?.sub) return new Response("Não autorizado", { status: 401 });

  const { data: leads } = await consultarLeads(supabase, lerFiltros(sp), 20000);
  const planilhas: Planilha[] = [{
    nome: "Leads StockFacil",
    colunas: ["Nome", "Categoria", "Situação", "Telefone", "WhatsApp", "Endereço", "Bairro", "Site", "E-mails", "Nota", "Avaliações",
      "Google Maps", "Observações", "Encontrado em"],
    linhas: (leads ?? []).map((l) => {
      const dig = (l.telefone_digitos ?? "").replace(/^0+/, "");
      const celular = dig.length === 11 && dig[2] === "9";
      return [
        l.nome, l.categoria ?? "", NOME_SITUACAO[l.situacao] ?? l.situacao, l.telefone ?? "",
        celular ? `https://wa.me/55${dig}` : "", l.endereco ?? "", l.bairro ?? "", l.site ?? "", l.emails ?? "",
        l.nota != null ? Number(l.nota) : null, l.avaliacoes, l.link_maps ?? "", l.observacoes ?? "",
        l.created_at.slice(0, 10),
      ];
    }),
  }];
  const base = `leads-stockfacil-${hojeBR()}`;
  if (sp.formato === "csv") {
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
