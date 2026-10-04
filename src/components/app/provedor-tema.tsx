"use client";

import { ThemeProvider } from "next-themes";

/** Tema claro por padrão; o usuário pode trocar para escuro no menu. */
export function ProvedorTema({ children }: { children: React.ReactNode }) {
  return (
    <ThemeProvider attribute="class" defaultTheme="light" enableSystem={false} disableTransitionOnChange>
      {children}
    </ThemeProvider>
  );
}
