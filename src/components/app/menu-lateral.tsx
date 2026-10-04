"use client";

import Image from "next/image";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useState } from "react";
import {
  BarChart3, Building2, CalendarDays, ChevronDown, History, KanbanSquare, LayoutDashboard, ListChecks, LogOut, Menu, Settings, Target, Trophy, Users, X,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { sair } from "@/app/acoes-sessao";
import { AlternarTema } from "./alternar-tema";
import { Sino } from "./sino";

type Icone = React.ComponentType<{ className?: string }>;
type Item = { href: string; rotulo: string; icone: Icone };
type Grupo = { slug: string; itens: Item[] };

export type DadosMenu = {
  nome: string;
  descricaoCargo: string;
  diretorias: { slug: string; nome: string }[];
  minhasDiretorias: string[];
  ehDiretor: boolean;
  diretorDe: string[];
};

/** Seções gerais (de toda a Aprimora) e as seções de cada diretoria. */
function montarMenu({ ehDiretor, diretorDe }: DadosMenu): { gerais: Item[]; grupos: Grupo[] } {
  return {
    gerais: [
      { href: "/painel", rotulo: "Painel", icone: LayoutDashboard },
      { href: "/agenda", rotulo: "Agenda", icone: CalendarDays },
      { href: "/tarefas", rotulo: "Tarefas", icone: ListChecks },
    ],
    grupos: [
      { slug: "presidencia", itens: ehDiretor ? [{ href: "/auditoria", rotulo: "Auditoria", icone: History }] : [] },
      { slug: "rh", itens: [
        { href: "/membros", rotulo: "Membros", icone: Users },
        { href: "/vice-presidencia/pontuacao", rotulo: "Pontuação", icone: Trophy },
      ] },
      { slug: "projetos", itens: [] },
      { slug: "comercial", itens: [
        { href: "/comercial", rotulo: "Painel comercial", icone: BarChart3 },
        { href: "/funil", rotulo: "Funil", icone: KanbanSquare },
        { href: "/empresas", rotulo: "Empresas e leads", icone: Building2 },
        { href: "/metas", rotulo: "Metas", icone: Target },
        ...(diretorDe.includes("comercial") ? [{ href: "/funil/configuracoes", rotulo: "Config. do funil", icone: Settings }] : []),
      ] },
      { slug: "marketing", itens: [] },
    ],
  };
}

const ativoEm = (caminho: string, href: string) => caminho === href || caminho.startsWith(href + "/");

export function MenuLateral(dados: DadosMenu) {
  const { nome, descricaoCargo, diretorias, minhasDiretorias } = dados;
  const caminho = usePathname();
  const [aberto, setAberto] = useState(false);
  // Grupos abertos por padrão: as diretorias da pessoa e a do endereço atual. O clique inverte o padrão.
  const [invertidos, setInvertidos] = useState<Set<string>>(new Set());
  const { gerais, grupos } = montarMenu(dados);
  const nomeDe = (slug: string) => diretorias.find((d) => d.slug === slug)?.nome ?? slug;
  // Item mais específico vence (ex.: /funil/configuracoes em vez de /funil)
  const todos = [...gerais, ...grupos.flatMap((g) => g.itens)];
  const hrefAtivo = todos.filter((i) => ativoEm(caminho, i.href)).sort((a, b) => b.href.length - a.href.length)[0]?.href;

  const linkItem = ({ href, rotulo, icone: Icone }: Item, recuado = false) => (
    <Link
      key={href}
      href={href}
      onClick={() => setAberto(false)}
      className={cn(
        "flex items-center gap-3 rounded-md px-3 py-2 text-sm transition-colors",
        recuado && "pl-6",
        href === hrefAtivo ? "bg-menu-ativo font-semibold text-white shadow-[inset_3px_0_0_#e8833a]" : "hover:bg-white/10",
      )}
    >
      <Icone className="h-4 w-4" />
      {rotulo}
    </Link>
  );

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

        <nav className="mt-4 flex-1 space-y-1 overflow-y-auto px-3 pb-4">
          {gerais.map((i) => linkItem(i))}
          <div className="mx-2 my-3 h-px bg-white/10" />
          {grupos.map((g) => {
            const padrao = minhasDiretorias.includes(g.slug) || g.itens.some((i) => i.href === hrefAtivo);
            const estaAberto = invertidos.has(g.slug) ? !padrao : padrao;
            return (
              <div key={g.slug}>
                <button
                  type="button"
                  onClick={() => setInvertidos((atual) => {
                    const novo = new Set(atual);
                    if (novo.has(g.slug)) novo.delete(g.slug);
                    else novo.add(g.slug);
                    return novo;
                  })}
                  aria-expanded={estaAberto}
                  className="flex w-full items-center justify-between rounded-md px-3 py-2 text-xs font-bold uppercase tracking-wider text-menu-texto/80 hover:bg-white/10"
                >
                  {nomeDe(g.slug)}
                  <ChevronDown className={cn("h-4 w-4 transition-transform", !estaAberto && "-rotate-90")} />
                </button>
                {estaAberto && (
                  <div className="space-y-1 pb-1">
                    {g.itens.length ? g.itens.map((i) => linkItem(i, true)) : <p className="py-1.5 pl-6 text-xs italic text-menu-texto/60">Em breve</p>}
                  </div>
                )}
              </div>
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
