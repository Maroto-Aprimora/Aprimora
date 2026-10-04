import { cn } from "@/lib/utils";

export function Cartao({ className, ...props }: React.HTMLAttributes<HTMLDivElement>) {
  return <div className={cn("rounded-xl border border-borda bg-superficie shadow-sm", className)} {...props} />;
}

export function CabecalhoCartao({ titulo, descricao, acoes }: { titulo: string; descricao?: string; acoes?: React.ReactNode }) {
  return (
    <div className="flex flex-wrap items-start justify-between gap-3 border-b border-borda px-5 py-4">
      <div>
        <h2 className="text-base font-bold text-texto">{titulo}</h2>
        {descricao && <p className="mt-0.5 text-sm text-texto-suave">{descricao}</p>}
      </div>
      {acoes}
    </div>
  );
}

export function TituloPagina({ titulo, descricao, acoes }: { titulo: string; descricao?: string; acoes?: React.ReactNode }) {
  return (
    <div className="mb-6 flex flex-wrap items-end justify-between gap-4">
      <div>
        <h1 className="text-2xl font-bold text-texto">{titulo}</h1>
        {descricao && <p className="mt-1 max-w-2xl text-sm text-texto-suave">{descricao}</p>}
      </div>
      {acoes && <div className="flex flex-wrap gap-2">{acoes}</div>}
    </div>
  );
}

export function Vazio({ titulo, descricao, acao }: { titulo: string; descricao?: string; acao?: React.ReactNode }) {
  return (
    <div className="flex flex-col items-center justify-center gap-2 px-6 py-12 text-center">
      <p className="font-semibold text-texto">{titulo}</p>
      {descricao && <p className="max-w-md text-sm text-texto-suave">{descricao}</p>}
      {acao && <div className="mt-2">{acao}</div>}
    </div>
  );
}
