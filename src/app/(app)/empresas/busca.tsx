"use client";

import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { useEffect, useState } from "react";
import { Entrada, Selecao } from "@/components/ui/campos";

export function BuscaEmpresas({ segmentos }: { segmentos: { id: string; nome: string }[] }) {
  const router = useRouter();
  const caminho = usePathname();
  const params = useSearchParams();
  const [q, setQ] = useState(params.get("q") ?? "");

  function aplicar(chave: string, valor: string) {
    const novo = new URLSearchParams(params.toString());
    if (valor) novo.set(chave, valor);
    else novo.delete(chave);
    novo.delete("pagina");
    router.replace(`${caminho}?${novo.toString()}`, { scroll: false });
  }

  useEffect(() => {
    if (q === (params.get("q") ?? "")) return;
    const t = setTimeout(() => aplicar("q", q), 350);
    return () => clearTimeout(t);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [q]);

  return (
    <div className="mb-4 flex flex-wrap gap-2">
      <Entrada className="w-80" placeholder="Buscar por nome, CNPJ ou telefone…" value={q} onChange={(e) => setQ(e.target.value)} />
      <Selecao className="w-56" value={params.get("segmento") ?? ""} onChange={(e) => aplicar("segmento", e.target.value)}>
        <option value="">Todos os segmentos</option>
        {segmentos.map((s) => <option key={s.id} value={s.id}>{s.nome}</option>)}
      </Selecao>
    </div>
  );
}
