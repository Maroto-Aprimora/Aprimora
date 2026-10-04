"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useState, useTransition } from "react";
import { toast } from "sonner";
import { Pencil, Plus, Trash2 } from "lucide-react";
import { Botao } from "@/components/ui/botao";
import { AreaTexto, Campo, Entrada, Selecao } from "@/components/ui/campos";
import { Cartao, Vazio } from "@/components/ui/cartao";
import { Dialogo } from "@/components/ui/dialogo";
import { Avatar, Selo } from "@/components/ui/selo";
import type { MembroResumo } from "@/lib/crm";
import { formatarData, iniciais } from "@/lib/formatar";
import { cn } from "@/lib/utils";
import { excluirTarefa, mudarStatusTarefa, salvarTarefa } from "./acoes";

type Tarefa = {
  id: string; titulo: string; descricao: string | null; prazo: string | null; prioridade: "baixa" | "media" | "alta";
  status: "pendente" | "em_andamento" | "concluida"; negocioId: string | null; negocioTitulo: string | null; responsaveis: string[];
  diretoria: string; podeGerir: boolean;
};

const NOME_PRIORIDADE = { alta: "Alta", media: "Média", baixa: "Baixa" } as const;
const NOME_STATUS = { pendente: "Pendente", em_andamento: "Em andamento", concluida: "Concluída" } as const;
const FILTROS = [["minhas", "Minhas"], ["abertas", "Todas abertas"], ["concluidas", "Concluídas"], ["todas", "Todas"]] as const;

export function ListaTarefas({
  tarefas, filtro, hoje, membros, negocios, ehDiretor, usuarioId, diretorias, nomesDiretorias,
}: {
  tarefas: Tarefa[]; filtro: string; hoje: string; membros: MembroResumo[]; negocios: { id: string; titulo: string }[];
  ehDiretor: boolean; usuarioId: string; diretorias: { slug: string; nome: string }[]; nomesDiretorias: Record<string, string>;
}) {
  const router = useRouter();
  const caminho = usePathname();
  const [editando, setEditando] = useState<Tarefa | "nova" | null>(null);
  const [pendente, iniciar] = useTransition();
  const nome = (id: string) => membros.find((m) => m.id === id)?.nome ?? "—";

  return (
    <>
      <div className="mb-4 flex flex-wrap items-center justify-between gap-2">
        <div className="flex flex-wrap gap-2">
          {FILTROS.map(([chave, rotulo]) => (
            <button key={chave} onClick={() => router.replace(`${caminho}?filtro=${chave}`)}
              className={cn("rounded-full border px-3 py-1 text-sm font-semibold",
                filtro === chave ? "border-marca bg-marca text-marca-texto" : "border-borda bg-superficie hover:bg-superficie-2")}>
              {rotulo}
            </button>
          ))}
        </div>
        {ehDiretor && <Botao variante="destaque" onClick={() => setEditando("nova")}><Plus className="h-4 w-4" /> Nova tarefa</Botao>}
      </div>

      <Cartao>
        {tarefas.length === 0 ? (
          <Vazio titulo="Nenhuma tarefa por aqui" descricao={filtro === "minhas" ? "Você não tem tarefas abertas." : undefined} />
        ) : (
          <ul className="divide-y divide-borda">
            {tarefas.map((t) => {
              const atrasada = t.prazo && t.prazo < hoje && t.status !== "concluida";
              const podeMudar = t.podeGerir || t.responsaveis.includes(usuarioId);
              return (
                <li key={t.id} className="flex flex-wrap items-start gap-3 px-5 py-3">
                  <input type="checkbox" className="mt-1 h-4 w-4" checked={t.status === "concluida"} disabled={!podeMudar || pendente}
                    aria-label="Concluir tarefa"
                    onChange={(e) => iniciar(async () => {
                      const r = await mudarStatusTarefa(t.id, e.target.checked ? "concluida" : "pendente");
                      if (!r.ok) toast.error(r.erro);
                    })} />
                  <div className="min-w-0 flex-1">
                    <p className={cn("font-semibold", t.status === "concluida" && "text-texto-suave line-through")}>{t.titulo}</p>
                    {t.descricao && <p className="text-sm text-texto-suave">{t.descricao}</p>}
                    <div className="mt-1 flex flex-wrap items-center gap-1.5">
                      {t.prazo && <Selo tom={atrasada ? "perigo" : t.prazo === hoje ? "destaque" : "neutro"}>{atrasada ? "Atrasada · " : t.prazo === hoje ? "Hoje · " : ""}{formatarData(t.prazo)}</Selo>}
                      <Selo tom={t.prioridade === "alta" ? "destaque" : "neutro"}>{NOME_PRIORIDADE[t.prioridade]}</Selo>
                      <Selo>{nomesDiretorias[t.diretoria] ?? t.diretoria}</Selo>
                      {t.negocioId && <Link href={`/negocios/${t.negocioId}`}><Selo tom="marca">{t.negocioTitulo}</Selo></Link>}
                    </div>
                  </div>
                  <div className="flex items-center gap-2">
                    <div className="flex -space-x-1.5">
                      {t.responsaveis.map((r) => <Avatar key={r} iniciais={iniciais(nome(r))} nome={nome(r)} className="ring-2 ring-superficie" />)}
                    </div>
                    {podeMudar && t.status !== "concluida" && (
                      <Selecao className="h-8 w-36 text-xs" value={t.status} disabled={pendente}
                        onChange={(e) => iniciar(async () => {
                          const r = await mudarStatusTarefa(t.id, e.target.value as Tarefa["status"]);
                          if (!r.ok) toast.error(r.erro);
                        })}>
                        {Object.entries(NOME_STATUS).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
                      </Selecao>
                    )}
                    {t.podeGerir && (
                      <>
                        <Botao tamanho="icone" variante="fantasma" aria-label="Editar tarefa" onClick={() => setEditando(t)}><Pencil className="h-4 w-4" /></Botao>
                        <Botao tamanho="icone" variante="fantasma" aria-label="Excluir tarefa" disabled={pendente}
                          onClick={() => confirm("Excluir esta tarefa?") && iniciar(async () => {
                            const r = await excluirTarefa(t.id);
                            if (r.ok) toast.success("Tarefa excluída.");
                            else toast.error(r.erro);
                          })}>
                          <Trash2 className="h-4 w-4" />
                        </Botao>
                      </>
                    )}
                  </div>
                </li>
              );
            })}
          </ul>
        )}
      </Cartao>

      {editando && (
        <Dialogo aberto aoFechar={() => setEditando(null)} titulo={editando === "nova" ? "Nova tarefa" : "Editar tarefa"}>
          <form className="grid gap-4 sm:grid-cols-2" action={(form) => iniciar(async () => {
            const g = (k: string) => String(form.get(k) ?? "");
            const r = await salvarTarefa(editando === "nova" ? null : editando.id,
              { titulo: g("titulo"), descricao: g("descricao"), prazo: g("prazo"), prioridade: g("prioridade"), negocio_id: g("negocio_id"),
                diretoria: g("diretoria") || (editando === "nova" ? diretorias[0]?.slug : editando.diretoria) || "" },
              form.getAll("responsaveis").map(String));
            if (!r.ok) return void toast.error(r.erro);
            toast.success("Tarefa salva.");
            setEditando(null);
          })}>
            {(() => {
              const t = editando === "nova" ? null : editando;
              return (
                <>
                  <Campo rotulo="Título" obrigatorio className="sm:col-span-2"><Entrada name="titulo" defaultValue={t?.titulo ?? ""} required /></Campo>
                  <Campo rotulo="Descrição" className="sm:col-span-2"><AreaTexto name="descricao" defaultValue={t?.descricao ?? ""} className="min-h-16" /></Campo>
                  {!t && diretorias.length > 1 && (
                    <Campo rotulo="Diretoria" className="sm:col-span-2">
                      <Selecao name="diretoria" defaultValue={diretorias[0]?.slug}>
                        {diretorias.map((d) => <option key={d.slug} value={d.slug}>{d.nome}</option>)}
                      </Selecao>
                    </Campo>
                  )}
                  <Campo rotulo="Prazo"><Entrada type="date" name="prazo" defaultValue={t?.prazo ?? ""} /></Campo>
                  <Campo rotulo="Prioridade">
                    <Selecao name="prioridade" defaultValue={t?.prioridade ?? "media"}>
                      {Object.entries(NOME_PRIORIDADE).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
                    </Selecao>
                  </Campo>
                  <Campo rotulo="Negócio relacionado (opcional)" className="sm:col-span-2">
                    <Selecao name="negocio_id" defaultValue={t?.negocioId ?? ""}>
                      <option value="">—</option>
                      {negocios.map((n) => <option key={n.id} value={n.id}>{n.titulo}</option>)}
                    </Selecao>
                  </Campo>
                  <div className="sm:col-span-2">
                    <p className="mb-2 text-xs font-semibold uppercase tracking-wide text-texto-suave">Responsáveis <span className="text-destaque">*</span></p>
                    <div className="flex flex-wrap gap-x-4 gap-y-1.5">
                      {membros.map((m) => (
                        <label key={m.id} className="flex items-center gap-2 text-sm">
                          <input type="checkbox" name="responsaveis" value={m.id} defaultChecked={t?.responsaveis.includes(m.id)} />
                          {m.nome}
                        </label>
                      ))}
                    </div>
                  </div>
                  <div className="flex justify-end gap-2 sm:col-span-2">
                    <Botao type="button" variante="secundario" onClick={() => setEditando(null)}>Cancelar</Botao>
                    <Botao type="submit" carregando={pendente}>Salvar</Botao>
                  </div>
                </>
              );
            })()}
          </form>
        </Dialogo>
      )}
    </>
  );
}
