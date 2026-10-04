"use client";

import { Moon, Sun } from "lucide-react";
import { useTheme } from "next-themes";
import { useSyncExternalStore } from "react";

const assinarNada = () => () => {};

export function AlternarTema() {
  const { resolvedTheme, setTheme } = useTheme();
  // Evita diferença entre servidor e navegador: o tema só é conhecido no cliente.
  const noCliente = useSyncExternalStore(assinarNada, () => true, () => false);
  const escuro = noCliente && resolvedTheme === "dark";
  return (
    <button
      onClick={() => setTheme(escuro ? "light" : "dark")}
      className="rounded-md border border-white/20 p-1.5 hover:bg-white/10"
      aria-label={escuro ? "Usar tema claro" : "Usar tema escuro"}
      title={escuro ? "Tema claro" : "Tema escuro"}
    >
      {escuro ? <Sun className="h-3.5 w-3.5" /> : <Moon className="h-3.5 w-3.5" />}
    </button>
  );
}
