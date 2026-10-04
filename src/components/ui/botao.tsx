import { cn } from "@/lib/utils";

const variantes = {
  primario: "bg-marca text-marca-texto hover:bg-marca-forte",
  destaque: "bg-destaque text-white hover:brightness-95",
  secundario: "border border-borda bg-superficie text-texto hover:bg-superficie-2",
  fantasma: "text-texto-suave hover:bg-superficie-2 hover:text-texto",
  perigo: "bg-perigo text-white hover:brightness-95",
} as const;

const tamanhos = {
  sm: "h-8 px-3 text-xs",
  md: "h-10 px-4 text-sm",
  icone: "h-9 w-9",
} as const;

export type BotaoProps = React.ButtonHTMLAttributes<HTMLButtonElement> & {
  variante?: keyof typeof variantes;
  tamanho?: keyof typeof tamanhos;
  carregando?: boolean;
};

export function Botao({ variante = "primario", tamanho = "md", carregando, className, children, disabled, ...props }: BotaoProps) {
  return (
    <button
      className={cn(
        "inline-flex items-center justify-center gap-2 rounded-md font-semibold transition-colors",
        "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-destaque",
        "disabled:cursor-not-allowed disabled:opacity-55",
        variantes[variante],
        tamanhos[tamanho],
        className,
      )}
      disabled={disabled || carregando}
      {...props}
    >
      {carregando && <span className="h-4 w-4 animate-spin rounded-full border-2 border-current border-t-transparent" aria-hidden />}
      {children}
    </button>
  );
}

/** Mesmo visual do botão, para links (<Link className={classeBotao()} />). */
export function classeBotao(variante: keyof typeof variantes = "primario", tamanho: keyof typeof tamanhos = "md") {
  return cn(
    "inline-flex items-center justify-center gap-2 rounded-md font-semibold transition-colors",
    variantes[variante],
    tamanhos[tamanho],
  );
}
