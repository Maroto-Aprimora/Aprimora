import type { Metadata } from "next";
import Link from "next/link";
import { Plus } from "lucide-react";
import { classeBotao } from "@/components/ui/botao";
import { Cartao, CabecalhoCartao, TituloPagina } from "@/components/ui/cartao";
import { Selo } from "@/components/ui/selo";
import { NOME_MACROETAPA, situacaoSla } from "@/lib/crm";
import { carregarConfiguracaoComercial } from "@/lib/crm-servidor";
import { criarClienteServidor } from "@/lib/supabase/server";
import { diasDesde, formatarMoeda } from "@/lib/formatar";
import { obterUsuario } from "@/lib/usuario";

export const metadata: Metadata = { title: "Painel" };

export default async function PaginaPainel() {
  const [usuario, config, supabase] = await Promise.all([obterUsuario(), carregarConfiguracaoComercial(), criarClienteServidor()]);
  const inicioTrimestre = new Date(new Date().getFullYear(), Math.floor(new Date().getMonth() / 3) * 3, 1).toISOString();

  const [{ data: abertos }, { data: ganhos }, { count: novos }] = await Promise.all([
    supabase.from("negocios").select("id, titulo, fase_id, responsavel_id, valor, entrou_na_fase_em").eq("funil_id", config.funil.id).is("encerrado_em", null),
    supabase.from("negocios").select("valor").eq("funil_id", config.funil.id).gte("ganho_em", inicioTrimestre),
    supabase.from("negocios").select("id", { count: "exact", head: true }).eq("funil_id", config.funil.id).gte("created_at", inicioTrimestre),
  ]);

  const fases = new Map(config.fases.map((f) => [f.id, f]));
  const lista = abertos ?? [];
  const meus = lista.filter((n) => n.responsavel_id === usuario.id);
  const estourados = lista
    .map((n) => ({ ...n, fase: fases.get(n.fase_id)!, dias: diasDesde(n.entrou_na_fase_em) }))
    .filter((n) => n.fase && situacaoSla(n.fase, n.dias) === "estourado");
  const ponderado = lista.reduce((s, n) => s + (n.valor ?? 0) * (fases.get(n.fase_id)?.probabilidade ?? 0), 0);
  const receita = (ganhos ?? []).reduce((s, n) => s + (n.valor ?? 0), 0);

  const porMacro = config.fases
    .filter((f) => f.tipo === "aberta")
    .reduce<Record<string, number>>((acc, f) => {
      acc[f.macroetapa] = (acc[f.macroetapa] ?? 0) + lista.filter((n) => n.fase_id === f.id).length;
      return acc;
    }, {});
  const maiorMacro = Math.max(1, ...Object.values(porMacro));

  return (
    <>
      <TituloPagina
        titulo={`Olá, ${usuario.nome.split(" ")[0]}!`}
        descricao="Resumo do funil comercial. Indicadores completos (conversão, ciclo de venda, metas automáticas) chegam na Fase 3."
        acoes={usuario.cargoEm("comercial") && <Link href="/empresas/novo" className={classeBotao("destaque")}><Plus className="h-4 w-4" /> Novo lead</Link>}
      />
      <div className="mb-6 grid grid-cols-2 gap-3 lg:grid-cols-4">
        <Numero rotulo="Negócios ativos" valor={String(lista.length)} detalhe={`${meus.length} com você`} />
        <Numero rotulo="Leads novos no trimestre" valor={String(novos ?? 0)} />
        <Numero rotulo="Receita fechada no trimestre" valor={formatarMoeda(receita)} detalhe={`${(ganhos ?? []).length} projetos`} />
        <Numero rotulo="Pipeline ponderado" valor={formatarMoeda(ponderado)} detalhe="valor × probabilidade da fase" />
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        <Cartao>
          <CabecalhoCartao titulo="Funil por etapa" />
          <ul className="space-y-3 px-5 py-4">
            {Object.entries(porMacro).map(([macro, qtd]) => (
              <li key={macro} className="grid grid-cols-[130px_1fr_40px] items-center gap-3 text-sm">
                <span className="text-texto-suave">{NOME_MACROETAPA[macro as keyof typeof NOME_MACROETAPA]}</span>
                <div className="h-2.5 overflow-hidden rounded-full bg-superficie-2">
                  <div className="h-full rounded-full bg-marca" style={{ width: `${(qtd / maiorMacro) * 100}%` }} />
                </div>
                <span className="text-right font-semibold">{qtd}</span>
              </li>
            ))}
          </ul>
        </Cartao>

        <Cartao>
          <CabecalhoCartao titulo="SLA estourado" descricao="Negócios parados além do prazo da fase." />
          <ul className="divide-y divide-borda">
            {estourados.slice(0, 8).map((n) => (
              <li key={n.id} className="flex items-center justify-between gap-3 px-5 py-2.5 text-sm">
                <Link href={`/negocios/${n.id}`} className="font-semibold hover:text-destaque">{n.titulo}</Link>
                <Selo tom="destaque">{n.fase.nome} · {n.dias} dias</Selo>
              </li>
            ))}
            {estourados.length === 0 && <li className="px-5 py-4 text-sm text-texto-suave">Nenhum negócio com SLA estourado. 🎉</li>}
          </ul>
        </Cartao>
      </div>
    </>
  );
}

function Numero({ rotulo, valor, detalhe }: { rotulo: string; valor: string; detalhe?: string }) {
  return (
    <Cartao className="px-4 py-4">
      <p className="text-[11px] font-semibold uppercase tracking-wide text-texto-suave">{rotulo}</p>
      <p className="mt-1 font-titulo text-2xl font-bold text-marca">{valor}</p>
      {detalhe && <p className="text-xs text-texto-suave">{detalhe}</p>}
    </Cartao>
  );
}
