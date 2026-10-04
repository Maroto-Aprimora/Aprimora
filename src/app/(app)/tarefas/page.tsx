import type { Metadata } from "next";
import { TituloPagina } from "@/components/ui/cartao";
import { carregarConfiguracaoComercial } from "@/lib/crm-servidor";
import { hojeBR } from "@/lib/datas";
import { criarClienteServidor } from "@/lib/supabase/server";
import { obterUsuario } from "@/lib/usuario";
import { ListaTarefas } from "./lista";

export const metadata: Metadata = { title: "Tarefas" };

export default async function PaginaTarefas({ searchParams }: PageProps<"/tarefas">) {
  const sp = await searchParams;
  const filtro = typeof sp.filtro === "string" ? sp.filtro : "minhas";
  const [usuario, config, supabase] = await Promise.all([obterUsuario(), carregarConfiguracaoComercial(), criarClienteServidor()]);
  const [{ data: tarefas }, { data: negocios }] = await Promise.all([
    supabase.from("tarefas").select("*, tarefa_responsaveis(membro_id), negocios(titulo)").eq("diretoria", "comercial")
      .order("status").order("prazo", { ascending: true, nullsFirst: false }).limit(500),
    supabase.from("negocios").select("id, titulo").eq("funil_id", config.funil.id).is("encerrado_em", null).order("titulo").limit(500),
  ]);

  const lista = (tarefas ?? []).map((t) => ({
    id: t.id, titulo: t.titulo, descricao: t.descricao, prazo: t.prazo, prioridade: t.prioridade, status: t.status,
    negocioId: t.negocio_id, negocioTitulo: t.negocios?.titulo ?? null, responsaveis: t.tarefa_responsaveis.map((r) => r.membro_id),
  }));
  const ehDiretor = usuario.ehDiretorDe("comercial");
  const visiveis = filtro === "todas" ? lista
    : filtro === "concluidas" ? lista.filter((t) => t.status === "concluida")
    : lista.filter((t) => t.status !== "concluida" && (filtro === "abertas" || t.responsaveis.includes(usuario.id)));

  return (
    <>
      <TituloPagina
        titulo="Tarefas"
        descricao={ehDiretor ? "Distribua tarefas para a equipe e acompanhe o andamento." : "Tarefas atribuídas pelo diretor. Atualize o andamento conforme avança."}
      />
      <ListaTarefas
        tarefas={visiveis}
        filtro={filtro}
        hoje={hojeBR()}
        membros={config.membrosComercial}
        negocios={negocios ?? []}
        ehDiretor={ehDiretor}
        usuarioId={usuario.id}
      />
    </>
  );
}
