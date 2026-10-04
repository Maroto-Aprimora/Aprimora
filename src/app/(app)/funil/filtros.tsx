"use client";

import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { useEffect, useState } from "react";
import { ChevronDown, SlidersHorizontal, X } from "lucide-react";
import { Botao } from "@/components/ui/botao";
import { Entrada, Selecao } from "@/components/ui/campos";
import type { MembroResumo } from "@/lib/crm";
import { cn } from "@/lib/utils";

const CHAVES = ["q", "resp", "origem", "segmento"] as const;

/** Filtros guardados na URL (dá para compartilhar o link já filtrado). O painel recolhe para dar espaço ao quadro. */
export function FiltrosFunil({ membros, origens, segmentos }: {
  membros: MembroResumo[]; origens: { id: string; nome: string }[]; segmentos: { id: string; nome: string }[];
}) {
  const router = useRouter();
  const caminho = usePathname();
  const params = useSearchParams();
  const [busca, setBusca] = useState(params.get("q") ?? "");
  const ativos = CHAVES.filter((c) => params.get(c)).length;
  const [aberto, setAberto] = useState(ativos > 0);

  function aplicar(mudancas: Record<string, string>) {
    const novo = new URLSearchParams(params.toString());
    for (const [chave, valor] of Object.entries(mudancas)) {
      if (valor) novo.set(chave, valor);
      else novo.delete(chave);
    }
    router.replace(`${caminho}?${novo.toString()}`, { scroll: false });
  }

  useEffect(() => {
    if (busca === (params.get("q") ?? "")) return;
    const t = setTimeout(() => aplicar({ q: busca }), 350);
    return () => clearTimeout(t);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [busca]);

  return (
    <div className="mb-4">
      <div className="flex flex-wrap items-center gap-2">
        <Botao variante="secundario" tamanho="sm" onClick={() => setAberto((v) => !v)} aria-expanded={aberto}>
          <SlidersHorizontal className="h-4 w-4" /> Filtros
          {ativos > 0 && <span className="rounded-full bg-destaque px-1.5 text-[11px] font-bold text-white">{ativos}</span>}
          <ChevronDown className={cn("h-4 w-4 transition-transform", aberto && "rotate-180")} />
        </Botao>
        {ativos > 0 && (
          <button type="button" className="inline-flex items-center gap-1 text-sm text-texto-suave hover:text-destaque"
            onClick={() => { setBusca(""); aplicar(Object.fromEntries(CHAVES.map((c) => [c, ""]))); }}>
            <X className="h-3.5 w-3.5" /> Limpar filtros
          </button>
        )}
      </div>
      {aberto && (
        <div className="mt-3 flex flex-wrap gap-2 rounded-xl border border-borda bg-superficie p-3">
          <Entrada className="w-64" placeholder="Buscar empresa…" value={busca} onChange={(e) => setBusca(e.target.value)} />
          <Selecao className="w-56" value={params.get("resp") ?? ""} onChange={(e) => aplicar({ resp: e.target.value })} aria-label="Responsável">
            <option value="">Todos os responsáveis</option>
            <option value="meus">Meus negócios</option>
            <option value="sem">Sem responsável</option>
            {membros.map((m) => <option key={m.id} value={m.id}>{m.nome}</option>)}
          </Selecao>
          <Selecao className="w-48" value={params.get("origem") ?? ""} onChange={(e) => aplicar({ origem: e.target.value })} aria-label="Origem">
            <option value="">Todas as origens</option>
            {origens.map((o) => <option key={o.id} value={o.id}>{o.nome}</option>)}
          </Selecao>
          <Selecao className="w-56" value={params.get("segmento") ?? ""} onChange={(e) => aplicar({ segmento: e.target.value })} aria-label="Segmento">
            <option value="">Todos os segmentos</option>
            {segmentos.map((s) => <option key={s.id} value={s.id}>{s.nome}</option>)}
          </Selecao>
        </div>
      )}
    </div>
  );
}
