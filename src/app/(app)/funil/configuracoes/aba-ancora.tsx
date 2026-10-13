"use client";

import { useRouter } from "next/navigation";
import { useEffect } from "react";

/** Links antigos (avisos de "Agente com erro") apontam para #agentes: abre a aba Agentes. */
export function AbaPeloAncora() {
  const router = useRouter();
  useEffect(() => {
    if (window.location.hash === "#agentes" && !window.location.search.includes("ver=")) router.replace("/funil/configuracoes?ver=agentes");
  }, [router]);
  return null;
}
