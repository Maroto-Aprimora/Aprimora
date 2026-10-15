"use client";

import { Printer } from "lucide-react";
import { Botao } from "@/components/ui/botao";

export function BotaoImprimir() {
  return <Botao variante="destaque" onClick={() => window.print()}><Printer className="h-4 w-4" /> Salvar em PDF</Botao>;
}
