"use client";

import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { BarraVisoes, BotaoFiltros, CampoBusca, useParametros } from "@/components/app/barra-visoes";
import { Campo, Selecao } from "@/components/ui/campos";

/** Cabeçalho de Empresas e leads no padrão do Funil: busca e filtros (segmento, cidade, responsável) à direita. */
const FILTROS = ["segmento", "cidade", "resp"] as const;

export function BarraEmpresas({ segmentos, cidades, membros, acoes }: {
  segmentos: { id: string; nome: string }[]; cidades: string[]; membros: { id: string; nome: string }[]; acoes?: React.ReactNode;
}) {
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
    <BarraVisoes visoes={[{ chave: "lista", rotulo: "Lista" }]} padrao="lista">
      <CampoBusca valor={q} aoMudar={setQ} placeholder="Nome, CNPJ ou telefone" />
      <BotaoFiltros ativos={FILTROS.filter((c) => params.get(c)).length} aoLimpar={() => aplicar(Object.fromEntries(FILTROS.map((c) => [c, null])))}>
        <Campo rotulo="Segmento">
          <Selecao value={params.get("segmento") ?? ""} onChange={(e) => aplicar({ segmento: e.target.value || null })}>
            <option value="">Todos</option>
            {segmentos.map((s) => <option key={s.id} value={s.id}>{s.nome}</option>)}
          </Selecao>
        </Campo>
        <Campo rotulo="Cidade">
          <Selecao value={params.get("cidade") ?? ""} onChange={(e) => aplicar({ cidade: e.target.value || null })}>
            <option value="">Todas</option>
            {cidades.map((c) => <option key={c} value={c}>{c}</option>)}
          </Selecao>
        </Campo>
        <Campo rotulo="Responsável">
          <Selecao value={params.get("resp") ?? ""} onChange={(e) => aplicar({ resp: e.target.value || null })}>
            <option value="">Todos</option>
            {membros.map((m) => <option key={m.id} value={m.id}>{m.nome}</option>)}
          </Selecao>
        </Campo>
      </BotaoFiltros>
      {acoes}
    </BarraVisoes>
  );
}
