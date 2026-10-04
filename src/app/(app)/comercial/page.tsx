import type { Metadata } from "next";
import Link from "next/link";
import { Plus } from "lucide-react";
import { classeBotao } from "@/components/ui/botao";
import { Cartao, CabecalhoCartao, TituloPagina } from "@/components/ui/cartao";
import { Selo } from "@/components/ui/selo";
import { NOME_MACROETAPA } from "@/lib/crm";
import { formatarMoeda } from "@/lib/formatar";
import { resumoComercial } from "@/lib/resumo-comercial";
import { obterUsuario } from "@/lib/usuario";

export const metadata: Metadata = { title: "Painel comercial" };

export default async function PaginaPainelComercial() {
  const usuario = await obterUsuario();
  const r = await resumoComercial(usuario.id);
  const maiorMacro = Math.max(1, ...Object.values(r.porMacro));

  return (
    <>
      <TituloPagina
        titulo="Painel comercial"
        descricao="Resumo do funil comercial. Indicadores completos (conversão, ciclo de venda, metas automáticas) chegam na Fase 3."
        acoes={usuario.cargoEm("comercial") && <Link href="/empresas/novo" className={classeBotao("destaque")}><Plus className="h-4 w-4" /> Novo lead</Link>}
      />
      <div className="mb-6 grid grid-cols-2 gap-3 lg:grid-cols-4">
        <Numero rotulo="Negócios ativos" valor={String(r.ativos)} detalhe={`${r.meus} com você`} />
        <Numero rotulo="Leads novos no trimestre" valor={String(r.novos)} />
        <Numero rotulo="Receita fechada no trimestre" valor={formatarMoeda(r.receita)} detalhe={`${r.ganhos} projetos`} />
        <Numero rotulo="Pipeline ponderado" valor={formatarMoeda(r.ponderado)} detalhe="valor × probabilidade da fase" />
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        <Cartao>
          <CabecalhoCartao titulo="Funil por etapa" />
          <ul className="space-y-3 px-5 py-4">
            {Object.entries(r.porMacro).map(([macro, qtd]) => (
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
            {r.estourados.slice(0, 8).map((n) => (
              <li key={n.id} className="flex items-center justify-between gap-3 px-5 py-2.5 text-sm">
                <Link href={`/negocios/${n.id}`} className="font-semibold hover:text-destaque">{n.titulo}</Link>
                <Selo tom="destaque">{n.fase.nome} · {n.dias} dias</Selo>
              </li>
            ))}
            {r.estourados.length === 0 && <li className="px-5 py-4 text-sm text-texto-suave">Nenhum negócio com SLA estourado. 🎉</li>}
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
