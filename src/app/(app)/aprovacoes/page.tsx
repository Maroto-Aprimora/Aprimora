import type { Metadata } from "next";
import Link from "next/link";
import { Cartao, TituloPagina, Vazio } from "@/components/ui/cartao";
import { Selo } from "@/components/ui/selo";
import { formatarDataHora } from "@/lib/formatar";
import { criarClienteServidor } from "@/lib/supabase/server";
import { obterUsuario } from "@/lib/usuario";
import { cn } from "@/lib/utils";
import { CartaoAprovacao, type ItemAprovacao } from "./item";

export const metadata: Metadata = { title: "Caixa de aprovação" };

/**
 * Caixa de aprovação (PE-PA-002, Seção 6): o que os agentes prepararam e espera o ok de um membro.
 * Cada membro vê os seus itens; o diretor comercial vê todos (filtro "todos").
 */
export default async function PaginaAprovacoes({ searchParams }: PageProps<"/aprovacoes">) {
  const sp = await searchParams;
  const [usuario, supabase] = await Promise.all([obterUsuario(), criarClienteServidor()]);
  const ehDiretor = usuario.ehDiretorDe("comercial");
  const todos = ehDiretor && sp.ver === "todos";

  let consulta = supabase.from("aprovacoes")
    .select("id, titulo, resumo, tipo, conteudo, status, created_at, decidido_em, responsavel_id, agentes(nome), negocios(id, titulo), membros!aprovacoes_responsavel_id_fkey(nome)")
    .order("created_at", { ascending: false }).limit(100);
  if (!todos) consulta = consulta.eq("responsavel_id", usuario.id);
  const { data } = await consulta;
  const itens = data ?? [];
  const pendentes: ItemAprovacao[] = itens.filter((a) => a.status === "pendente").reverse().map((a) => ({
    id: a.id, titulo: a.titulo, resumo: a.resumo, agente: a.agentes?.nome ?? "Agente", tipo: a.tipo, criadoEm: a.created_at,
    conteudo: (a.conteudo ?? {}) as Record<string, unknown>, negocio: a.negocios, responsavel: a.membros?.nome ?? null,
  }));
  const decididos = itens.filter((a) => a.status !== "pendente").slice(0, 20);

  return (
    <div className="mx-auto max-w-4xl">
      <TituloPagina titulo="Caixa de aprovação"
        descricao="O que os agentes prepararam para você: leia, ajuste se precisar e aprove ou descarte. Nada sai para o lead sem aprovação." />

      {ehDiretor && (
        <div className="mb-4 flex gap-2">
          {[["", "Meus"], ["todos", "Todos da equipe"]].map(([v, rotulo]) => (
            <Link key={v} href={v ? `/aprovacoes?ver=${v}` : "/aprovacoes"}
              className={cn("rounded-full border px-3 py-1 text-sm font-semibold",
                (v === "todos") === todos ? "border-marca bg-marca text-marca-texto" : "border-borda bg-superficie hover:bg-superficie-2")}>
              {rotulo}
            </Link>
          ))}
        </div>
      )}

      <div className="space-y-4">
        {pendentes.map((item) => <CartaoAprovacao key={item.id} item={item} mostrarResponsavel={todos} />)}
        {pendentes.length === 0 && (
          <Cartao>
            <Vazio titulo="Nada para aprovar"
              descricao="Quando os agentes prepararem e-mails, dados de leads ou sugestões para você, eles aparecem aqui e você recebe uma notificação." />
          </Cartao>
        )}
      </div>

      {decididos.length > 0 && (
        <>
          <h2 className="mb-3 mt-8 font-titulo text-lg font-bold">Decididos recentemente</h2>
          <Cartao>
            <ul className="divide-y divide-borda">
              {decididos.map((a) => (
                <li key={a.id} className="flex items-center gap-3 px-5 py-2.5 text-sm">
                  <Selo tom={a.status === "aprovada" ? "sucesso" : "neutro"}>{a.status === "aprovada" ? "Aprovado" : "Descartado"}</Selo>
                  <span className="min-w-0 flex-1 truncate">{a.titulo}</span>
                  <span className="text-xs text-texto-suave">{a.agentes?.nome} · {a.decidido_em ? formatarDataHora(a.decidido_em) : ""}</span>
                </li>
              ))}
            </ul>
          </Cartao>
        </>
      )}
    </div>
  );
}
