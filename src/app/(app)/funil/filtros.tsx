"use client";

import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { useEffect, useState } from "react";
import { Entrada, Selecao } from "@/components/ui/campos";
import type { MembroResumo } from "@/lib/crm";

/** Filtros guardados na URL (dá para compartilhar o link já filtrado). */
export function FiltrosFunil({ membros, origens }: { membros: MembroResumo[]; origens: { id: string; nome: string }[] }) {
  const router = useRouter();
  const caminho = usePathname();
  const params = useSearchParams();
  const [busca, setBusca] = useState(params.get("q") ?? "");

  function aplicar(chave: string, valor: string) {
    const novo = new URLSearchParams(params.toString());
    if (valor) novo.set(chave, valor);
    else novo.delete(chave);
    router.replace(`${caminho}?${novo.toString()}`, { scroll: false });
  }

  useEffect(() => {
    if (busca === (params.get("q") ?? "")) return;
    const t = setTimeout(() => aplicar("q", busca), 350);
    return () => clearTimeout(t);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [busca]);

  return (
    <div className="mb-4 flex flex-wrap gap-2">
      <Entrada className="w-64" placeholder="Buscar empresa…" value={busca} onChange={(e) => setBusca(e.target.value)} />
      <Selecao className="w-56" value={params.get("resp") ?? ""} onChange={(e) => aplicar("resp", e.target.value)}>
        <option value="">Todos os responsáveis</option>
        <option value="meus">Meus negócios</option>
        <option value="sem">Sem responsável</option>
        {membros.map((m) => <option key={m.id} value={m.id}>{m.nome}</option>)}
      </Selecao>
      <Selecao className="w-48" value={params.get("origem") ?? ""} onChange={(e) => aplicar("origem", e.target.value)}>
        <option value="">Todas as origens</option>
        {origens.map((o) => <option key={o.id} value={o.id}>{o.nome}</option>)}
      </Selecao>
    </div>
  );
}
