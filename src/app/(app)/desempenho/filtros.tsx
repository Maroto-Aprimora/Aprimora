"use client";

import { useRouter } from "next/navigation";
import { useParametros } from "@/components/app/barra-visoes";
import { Selecao } from "@/components/ui/campos";
import { cn } from "@/lib/utils";

const OPCOES = [["mes", "Este mês"], ["30d", "Últimos 30 dias"], ["trimestre", "Trimestre"], ["ano", "Ano"]] as const;

/** Período e (para o diretor) o membro. Ficam na URL. */
export function FiltrosDesempenho({ periodo, membro, membros }: { periodo: string; membro: string; membros: { id: string; nome: string }[] | null }) {
  const router = useRouter();
  const { montar } = useParametros();
  const ir = (m: Record<string, string | null>) => router.replace(montar(m), { scroll: false });
  return (
    <div className="mb-6 flex flex-wrap items-center gap-3">
      {membros && (
        <Selecao value={membro} onChange={(e) => ir({ m: e.target.value })} className="h-9 w-60" aria-label="Membro">
          {membros.map((m) => <option key={m.id} value={m.id}>{m.nome}</option>)}
        </Selecao>
      )}
      <div className="flex flex-wrap gap-2">
        {OPCOES.map(([valor, rotulo]) => (
          <button key={valor} type="button" onClick={() => ir({ periodo: valor })}
            className={cn("rounded-full border px-3 py-1 text-sm font-semibold",
              periodo === valor ? "border-marca bg-marca text-marca-texto" : "border-borda bg-superficie hover:bg-superficie-2")}>
            {rotulo}
          </button>
        ))}
      </div>
    </div>
  );
}
