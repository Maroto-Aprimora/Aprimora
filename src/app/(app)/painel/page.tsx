import type { Metadata } from "next";
import Link from "next/link";
import { CalendarDays, ListChecks } from "lucide-react";
import { Cartao, CabecalhoCartao, TituloPagina } from "@/components/ui/cartao";
import { Selo } from "@/components/ui/selo";
import { COR_TIPO } from "@/lib/agenda";
import { hojeBR, horaBR, somarDias } from "@/lib/datas";
import { formatarData } from "@/lib/formatar";
import { criarClienteServidor } from "@/lib/supabase/server";
import { obterUsuario } from "@/lib/usuario";
import { cn } from "@/lib/utils";

export const metadata: Metadata = { title: "Início" };

/** Início: o dia de quem está logado (agenda e tarefas). A fila completa do dia chega no PR 5 da Fase 0. */
export default async function PaginaInicio() {
  const [usuario, supabase] = await Promise.all([obterUsuario(), criarClienteServidor()]);
  const hoje = hojeBR();
  const inicioHoje = new Date(`${hoje}T00:00:00-03:00`).toISOString();
  const inicioAmanha = new Date(`${somarDias(hoje, 1)}T00:00:00-03:00`).toISOString();

  const [{ data: atividadesHoje }, { data: tarefas }, { data: tipos }] = await Promise.all([
    supabase.from("atividades").select("id, titulo, inicio, tipo_id, responsavel_id, negocio_id, status, atividade_participantes(membro_id)")
      .gte("inicio", inicioHoje).lt("inicio", inicioAmanha).neq("status", "cancelada").order("inicio"),
    supabase.from("tarefas").select("id, titulo, prazo, status, negocio_id, tarefa_responsaveis!inner(membro_id)")
      .eq("tarefa_responsaveis.membro_id", usuario.id).neq("status", "concluida")
      .order("prazo", { ascending: true, nullsFirst: false }).limit(50),
    supabase.from("tipos_atividade").select("id, cor"),
  ]);

  const minhasAtividades = (atividadesHoje ?? []).filter((a) =>
    a.responsavel_id === usuario.id || a.atividade_participantes.some((p) => p.membro_id === usuario.id));
  const corDe = (id: string) => (tipos ?? []).find((t) => t.id === id)?.cor ?? "marca";

  return (
    <>
      <TituloPagina titulo={`Olá, ${usuario.nome.split(" ")[0]}!`} descricao="Suas tarefas e compromissos de hoje." />

      <div className="grid gap-6 lg:grid-cols-2">
        <Cartao>
          <CabecalhoCartao titulo="Minhas tarefas" acoes={<LinkCartao href="/tarefas" icone={ListChecks}>Tarefas</LinkCartao>} />
          <ul className="divide-y divide-borda">
            {(tarefas ?? []).map((t) => {
              const atrasada = t.prazo && t.prazo < hoje;
              return (
                <li key={t.id} className="flex items-center justify-between gap-3 px-5 py-2.5 text-sm">
                  {t.negocio_id ? <Link href={`/negocios/${t.negocio_id}`} className="min-w-0 truncate hover:text-destaque">{t.titulo}</Link>
                    : <span className="min-w-0 truncate">{t.titulo}</span>}
                  {t.prazo ? (
                    <Selo tom={atrasada ? "perigo" : t.prazo === hoje ? "destaque" : "neutro"}>
                      {atrasada ? "Atrasada" : t.prazo === hoje ? "Vence hoje" : formatarData(t.prazo)}
                    </Selo>
                  ) : <Selo>Sem prazo</Selo>}
                </li>
              );
            })}
            {(tarefas ?? []).length === 0 && <li className="px-5 py-3 text-sm text-texto-suave">Nenhuma tarefa aberta com você.</li>}
          </ul>
        </Cartao>

        <Cartao>
          <CabecalhoCartao titulo="Hoje na agenda" acoes={<LinkCartao href="/agenda?pessoa=eu" icone={CalendarDays}>Agenda</LinkCartao>} />
          <ul className="divide-y divide-borda">
            {minhasAtividades.map((a) => (
              <li key={a.id} className="flex items-center gap-3 px-5 py-2.5 text-sm">
                <span className={cn("h-2.5 w-2.5 shrink-0 rounded-full", COR_TIPO[corDe(a.tipo_id)])} />
                <span className="w-12 shrink-0 font-semibold">{horaBR(a.inicio)}</span>
                {a.negocio_id ? <Link href={`/negocios/${a.negocio_id}`} className="min-w-0 flex-1 truncate hover:text-destaque">{a.titulo}</Link>
                  : <span className="min-w-0 flex-1 truncate">{a.titulo}</span>}
                {a.status === "pendente" && <Selo>a confirmar</Selo>}
              </li>
            ))}
            {minhasAtividades.length === 0 && <li className="px-5 py-3 text-sm text-texto-suave">Nenhuma atividade sua hoje.</li>}
          </ul>
        </Cartao>
      </div>
    </>
  );
}

function LinkCartao({ href, icone: Icone, children }: { href: string; icone: React.ComponentType<{ className?: string }>; children: React.ReactNode }) {
  return (
    <Link href={href} className="inline-flex items-center gap-1 text-sm font-semibold text-marca hover:text-destaque">
      <Icone className="h-4 w-4" />{children}
    </Link>
  );
}
