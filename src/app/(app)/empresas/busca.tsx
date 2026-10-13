"use client";

import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { BarraVisoes, BotaoFiltros, CampoBusca, useParametros } from "@/components/app/barra-visoes";
import { Campo, Selecao } from "@/components/ui/campos";

/** Cabeçalho de Empresas e leads, igual ao do Funil: Kanban e Lista à esquerda; busca e filtro à direita. */
export function BarraEmpresas({ segmentos, acoes }: { segmentos: { id: string; nome: string }[]; acoes?: React.ReactNode }) {
  const router = useRouter();
  const { params, montar } = useParametros();
  const [q, setQ] = useState(params.get("q") ?? "");
  const aplicar = (m: Record<string, string | null>) => router.replace(montar({ ...m, pagina: null }), { scroll: false });

  useEffect(() => {
    if (q === (params.get("q") ?? "")) return;
    const t = setTimeout(() => aplicar({ q: q || null }), 350);
    return () => clearTimeout(t);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [q]);

  return (
    <BarraVisoes visoes={[{ chave: "kanban", rotulo: "Kanban" }, { chave: "lista", rotulo: "Lista" }]} padrao="kanban">
      <CampoBusca valor={q} aoMudar={setQ} placeholder="Nome, CNPJ ou telefone" />
      <BotaoFiltros ativos={params.get("segmento") ? 1 : 0} aoLimpar={() => aplicar({ segmento: null })}>
        <Campo rotulo="Segmento">
          <Selecao value={params.get("segmento") ?? ""} onChange={(e) => aplicar({ segmento: e.target.value || null })}>
            <option value="">Todos</option>
            {segmentos.map((s) => <option key={s.id} value={s.id}>{s.nome}</option>)}
          </Selecao>
        </Campo>
      </BotaoFiltros>
      {acoes}
    </BarraVisoes>
  );
}
