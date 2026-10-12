"use client";

import Link from "next/link";
import { useState } from "react";
import { ArrowRightLeft } from "lucide-react";
import { Avatar, Selo } from "@/components/ui/selo";
import { useMoverNegocio } from "@/components/crm/mover-negocio";
import { RegistrarLigacao } from "@/components/crm/registrar-ligacao";
import { NOME_MACROETAPA, situacaoSla, type Fase, type Motivo, type ResultadoLigacao } from "@/lib/crm";
import { diasDesde, formatarMoeda, iniciais } from "@/lib/formatar";
import { cn } from "@/lib/utils";

export type CartaoNegocio = {
  id: string; titulo: string; faseId: string; responsavel: string | null; valor: number | null;
  entrouNaFaseEm: string; cidade: string | null; ficticio: boolean; contatoId: string | null; ultimaLigacao: string | null;
};

const COR_MACRO: Record<string, string> = {
  prospeccao: "bg-azul-claro",
  cadencia: "bg-marca",
  oportunidade: "bg-destaque",
  venda: "bg-marca-forte",
  ganho: "bg-sucesso",
  pausa: "bg-texto-suave",
  perda: "bg-perigo",
};

export function Kanban({ fases, motivos, resultados, cartoes }: { fases: Fase[]; motivos: Motivo[]; resultados: ResultadoLigacao[]; cartoes: CartaoNegocio[] }) {
  const [itens, setItens] = useState(cartoes);
  const [anteriores, setAnteriores] = useState(cartoes);
  const [sobre, setSobre] = useState<string | null>(null);
  // Quando o servidor manda dados novos (filtro, revalidação), recomeça a partir deles.
  if (cartoes !== anteriores) {
    setAnteriores(cartoes);
    setItens(cartoes);
  }
  const { mover, dialogo } = useMoverNegocio(motivos, (id, faseId) =>
    setItens((xs) => xs.map((x) => (x.id === id ? { ...x, faseId, entrouNaFaseEm: new Date().toISOString() } : x))),
  );

  function soltar(faseId: string, negocioId: string) {
    setSobre(null);
    const cartao = itens.find((c) => c.id === negocioId);
    const destino = fases.find((f) => f.id === faseId);
    if (!cartao || !destino || cartao.faseId === faseId) return;
    mover(cartao.id, cartao.titulo, destino);
  }

  return (
    <>
      <div className="-mx-4 overflow-x-auto px-4 pb-4 sm:-mx-6 sm:px-6 lg:-mx-8 lg:px-8">
        <div className="flex min-w-max gap-3">
          {fases.map((fase) => {
            const daFase = itens.filter((c) => c.faseId === fase.id);
            const total = daFase.reduce((s, c) => s + (c.valor ?? 0), 0);
            const encerrada = fase.tipo !== "aberta";
            return (
              <section
                key={fase.id}
                onDragOver={(e) => { e.preventDefault(); setSobre(fase.id); }}
                onDragLeave={() => setSobre((s) => (s === fase.id ? null : s))}
                onDrop={(e) => soltar(fase.id, e.dataTransfer.getData("text/negocio"))}
                className={cn(
                  "flex w-72 shrink-0 flex-col rounded-xl border border-borda bg-superficie-2/60 transition-colors",
                  encerrada && "w-60",
                  sobre === fase.id && "border-destaque bg-destaque-suave",
                )}
              >
                <header className="rounded-t-xl border-b border-borda bg-superficie px-3 pb-2 pt-0">
                  <div className={cn("-mx-3 mb-2 h-1 rounded-t-xl", COR_MACRO[fase.macroetapa])} />
                  <p className="text-[10px] font-bold uppercase tracking-wider text-texto-suave">{NOME_MACROETAPA[fase.macroetapa]}</p>
                  <div className="flex items-baseline justify-between gap-2">
                    <h2 className="truncate text-sm font-bold" title={fase.descricao ?? undefined}>{fase.nome}</h2>
                    <span className="text-xs font-semibold text-texto-suave">{daFase.length}</span>
                  </div>
                  <div className="flex gap-2 text-[11px] text-texto-suave">
                    {total > 0 && <span>{formatarMoeda(total)}</span>}
                    {fase.sla_dias && <span>SLA {fase.sla_dias} dias</span>}
                  </div>
                </header>
                <div className="flex max-h-[calc(100vh-290px)] min-h-32 flex-col gap-2 overflow-y-auto p-2">
                  {daFase.map((c) => <Cartao key={c.id} cartao={c} fase={fase} fases={fases} resultados={resultados} aoMover={(d) => mover(c.id, c.titulo, d)} />)}
                  {daFase.length === 0 && <p className="py-6 text-center text-xs text-texto-suave">Nenhum negócio</p>}
                </div>
              </section>
            );
          })}
        </div>
      </div>
      {dialogo}
    </>
  );
}

function Cartao({ cartao, fase, fases, resultados, aoMover }: {
  cartao: CartaoNegocio; fase: Fase; fases: Fase[]; resultados: ResultadoLigacao[]; aoMover: (destino: Fase) => void;
}) {
  const [escolhendo, setEscolhendo] = useState(false);
  const dias = diasDesde(cartao.entrouNaFaseEm);
  const sla = situacaoSla(fase, dias);

  return (
    <article
      draggable
      onDragStart={(e) => { e.dataTransfer.setData("text/negocio", cartao.id); e.dataTransfer.effectAllowed = "move"; }}
      className={cn(
        "group cursor-grab rounded-lg border bg-superficie p-3 shadow-sm transition hover:shadow-md active:cursor-grabbing",
        sla === "estourado" ? "border-destaque ring-1 ring-destaque/40" : "border-borda",
      )}
    >
      <div className="flex items-start justify-between gap-2">
        <Link href={`/negocios/${cartao.id}`} className="text-sm font-semibold leading-snug hover:text-destaque">{cartao.titulo}</Link>
        {cartao.responsavel && <Avatar iniciais={iniciais(cartao.responsavel)} nome={cartao.responsavel} className="h-6 w-6 text-[10px]" />}
      </div>
      {cartao.cidade && <p className="mt-0.5 text-xs text-texto-suave">{cartao.cidade}</p>}
      <div className="mt-2 flex flex-wrap items-center gap-1.5">
        {cartao.valor != null && <Selo tom="marca">{formatarMoeda(cartao.valor)}</Selo>}
        <Selo tom={sla === "estourado" ? "destaque" : sla === "atencao" ? "destaque" : "neutro"}>
          {dias} {dias === 1 ? "dia" : "dias"}{sla === "estourado" ? " · SLA estourado" : ""}
        </Selo>
        {!cartao.responsavel && fase.tipo === "aberta" && <Selo>Sem responsável</Selo>}
        {cartao.ultimaLigacao && <Selo title="Resultado da última ligação">☎ {cartao.ultimaLigacao}</Selo>}
        {cartao.ficticio && <Selo className="opacity-70">fictício</Selo>}
        {fase.tipo === "aberta" && (
          <RegistrarLigacao compacto negocioId={cartao.id} titulo={cartao.titulo} resultados={resultados}
            contatoPadrao={cartao.contatoId} className="ml-auto" />
        )}
        <button
          onClick={() => setEscolhendo((v) => !v)}
          className={cn("rounded p-1 text-texto-suave opacity-70 hover:bg-superficie-2 hover:opacity-100", fase.tipo !== "aberta" && "ml-auto")}
          aria-label="Mover para outra fase"
          title="Mover para outra fase"
        >
          <ArrowRightLeft className="h-3.5 w-3.5" />
        </button>
      </div>
      {escolhendo && (
        <select
          autoFocus
          className="mt-2 w-full rounded-md border border-borda bg-superficie px-2 py-1 text-xs"
          defaultValue=""
          onChange={(e) => {
            const destino = fases.find((f) => f.id === e.target.value);
            setEscolhendo(false);
            if (destino) aoMover(destino);
          }}
        >
          <option value="" disabled>Mover para…</option>
          {fases.filter((f) => f.id !== fase.id).map((f) => <option key={f.id} value={f.id}>{f.nome}</option>)}
        </select>
      )}
    </article>
  );
}
