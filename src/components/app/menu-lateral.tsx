"use client";

import Image from "next/image";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useState } from "react";
import { Building2, CalendarDays, History, KanbanSquare, LayoutDashboard, ListChecks, LogOut, Menu, Settings, Target, Users, X } from "lucide-react";
import { cn } from "@/lib/utils";
import { sair } from "@/app/acoes-sessao";
import { AlternarTema } from "./alternar-tema";
import { Sino } from "./sino";

type Item = { href: string; rotulo: string; icone: React.ComponentType<{ className?: string }>; soDiretor?: boolean };

const ITENS: Item[] = [
  { href: "/painel", rotulo: "Painel", icone: LayoutDashboard },
  { href: "/funil", rotulo: "Funil", icone: KanbanSquare },
  { href: "/empresas", rotulo: "Empresas e leads", icone: Building2 },
  { href: "/agenda", rotulo: "Agenda", icone: CalendarDays },
  { href: "/tarefas", rotulo: "Tarefas", icone: ListChecks },
  { href: "/metas", rotulo: "Metas", icone: Target },
  { href: "/membros", rotulo: "Membros", icone: Users },
  { href: "/auditoria", rotulo: "Auditoria", icone: History, soDiretor: true },
  { href: "/configuracoes", rotulo: "Configurações", icone: Settings, soDiretor: true },
];

export function MenuLateral({ nome, descricaoCargo, ehDiretorComercial }: { nome: string; descricaoCargo: string; ehDiretorComercial: boolean }) {
  const caminho = usePathname();
  const [aberto, setAberto] = useState(false);
  const itens = ITENS.filter((i) => !i.soDiretor || ehDiretorComercial);

  return (
    <>
      <header className="sticky top-0 z-30 flex items-center justify-between border-b border-borda bg-superficie px-4 py-3 lg:hidden">
        <button onClick={() => setAberto(true)} aria-label="Abrir menu" className="rounded p-1 hover:bg-superficie-2">
          <Menu className="h-6 w-6" />
        </button>
        <span className="font-titulo font-bold text-marca">Portal Aprimora</span>
        <Sino />
      </header>

      {aberto && <div className="fixed inset-0 z-40 bg-black/40 lg:hidden" onClick={() => setAberto(false)} />}

      <aside
        className={cn(
          "fixed inset-y-0 left-0 z-50 flex w-64 flex-col bg-menu text-menu-texto transition-transform lg:sticky lg:top-0 lg:h-screen lg:translate-x-0",
          aberto ? "translate-x-0" : "-translate-x-full",
        )}
      >
        <div className="flex items-center justify-between px-5 pb-4 pt-5">
          <Link href="/painel" className="flex items-center gap-2" onClick={() => setAberto(false)}>
            <Image src="/logo-branca.png" alt="" width={44} height={34} className="h-9 w-auto" />
            <span className="font-titulo text-[15px] font-bold leading-tight text-white">
              Portal<br /><span className="tracking-[0.2em] text-[#f5a66a]">APRIMORA</span>
            </span>
          </Link>
          <div className="hidden lg:block"><Sino claro /></div>
          <button className="lg:hidden" onClick={() => setAberto(false)} aria-label="Fechar menu">
            <X className="h-5 w-5" />
          </button>
        </div>
        <div className="mx-5 h-px bg-gradient-to-r from-[#e8833a] to-transparent" />

        <nav className="mt-4 flex-1 space-y-1 px-3">
          {itens.map(({ href, rotulo, icone: Icone }) => {
            const ativo = caminho === href || caminho.startsWith(href + "/");
            return (
              <Link
                key={href}
                href={href}
                onClick={() => setAberto(false)}
                className={cn(
                  "flex items-center gap-3 rounded-md px-3 py-2 text-sm transition-colors",
                  ativo ? "bg-menu-ativo font-semibold text-white shadow-[inset_3px_0_0_#e8833a]" : "hover:bg-white/10",
                )}
              >
                <Icone className="h-4 w-4" />
                {rotulo}
              </Link>
            );
          })}
        </nav>

        <div className="border-t border-white/10 px-5 py-4">
          <p className="truncate text-sm font-semibold text-white">{nome}</p>
          <p className="truncate text-xs text-[#f5a66a]">{descricaoCargo}</p>
          <div className="mt-3 flex items-center gap-2">
            <AlternarTema />
            <form action={sair} className="flex-1">
              <button className="flex w-full items-center justify-center gap-2 rounded-md border border-white/20 px-3 py-1.5 text-xs font-semibold hover:bg-white/10">
                <LogOut className="h-3.5 w-3.5" /> Sair
              </button>
            </form>
          </div>
        </div>
      </aside>
    </>
  );
}
