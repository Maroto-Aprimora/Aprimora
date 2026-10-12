import type { Metadata } from "next";
import { TituloPagina } from "@/components/ui/cartao";
import { carregarConfiguracaoComercial, carregarTodosMembros } from "@/lib/crm-servidor";
import { hojeBR } from "@/lib/datas";
import { criarClienteServidor } from "@/lib/supabase/server";
import { obterUsuario } from "@/lib/usuario";
import { ListaTarefas } from "./lista";

export const metadata: Metadata = { title: "Tarefas" };

export default async function PaginaTarefas({ searchParams }: PageProps<"/tarefas">) {
  const sp = await searchParams;
  const filtro = typeof sp.filtro === "string" ? sp.filtro : "minhas";
  const [usuario, config, supabase, membros] = await Promise.all([obterUsuario(), carregarConfiguracaoComercial(), criarClienteServidor(), carregarTodosMembros()]);
  const [{ data: tarefas }, { data: negocios }, { data: diretorias }] = await Promise.all([
    supabase.from("tarefas").select("*, tarefa_responsaveis(membro_id), negocios(titulo)")
      .order("status").order("prazo", { ascending: true, nullsFirst: false }).limit(500),
    supabase.from("negocios").select("id, titulo").eq("funil_id", config.funil.id).is("encerrado_em", null).order("titulo").limit(500),
    supabase.from("diretorias").select("slug, nome").order("ordem"),
  ]);

  const lista = (tarefas ?? []).map((t) => ({
    id: t.id, titulo: t.titulo, descricao: t.descricao, prazo: t.prazo, prioridade: t.prioridade, status: t.status,
    negocioId: t.negocio_id, negocioTitulo: t.negocios?.titulo ?? null, responsaveis: t.tarefa_responsaveis.map((r) => r.membro_id),
    diretoria: t.diretoria, origem: t.origem,
    podeGerir: usuario.ehDiretorDe(t.diretoria) || (t.origem === "manual" && t.criado_por === usuario.id),
  }));
  const ehDiretor = usuario.ehDiretor;
  // Onde a pessoa pode criar: as diretorias que dirige; quem não é diretor cria tarefas pessoais no Comercial
  const dirigidas = (diretorias ?? []).filter((d) => usuario.ehDiretorDe(d.slug));
  const minhasDiretorias = dirigidas.length ? dirigidas : (diretorias ?? []).filter((d) => d.slug === "comercial");
  const visiveis = filtro === "todas" ? lista
    : filtro === "concluidas" ? lista.filter((t) => t.status === "concluida")
    : lista.filter((t) => t.status !== "concluida" && (filtro === "abertas" || t.responsaveis.includes(usuario.id)));

  return (
    <>
      <TituloPagina
        titulo="Tarefas"
        descricao={ehDiretor ? "Distribua tarefas para a equipe e acompanhe o andamento." : "Suas tarefas: as do diretor, as criadas pelo sistema e as que você cria para si."}
      />
      <ListaTarefas
        tarefas={visiveis}
        filtro={filtro}
        hoje={hojeBR()}
        membros={membros}
        diretorias={minhasDiretorias}
        nomesDiretorias={Object.fromEntries((diretorias ?? []).map((d) => [d.slug, d.nome]))}
        negocios={negocios ?? []}
        ehDiretor={ehDiretor}
        usuarioId={usuario.id}
      />
    </>
  );
}
