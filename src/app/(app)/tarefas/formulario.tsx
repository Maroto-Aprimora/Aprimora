"use client";

import { useTransition } from "react";
import { toast } from "sonner";
import { Botao } from "@/components/ui/botao";
import { AreaTexto, Campo, Entrada, Selecao } from "@/components/ui/campos";
import { Dialogo } from "@/components/ui/dialogo";
import type { MembroResumo } from "@/lib/crm";
import { salvarTarefa } from "./acoes";
import { NOME_PRIORIDADE, type Tarefa } from "./lista";

/** Criar ou editar tarefa. O diretor atribui a qualquer pessoa; os demais criam tarefas pessoais. */
export function DialogoTarefa({ tarefa, aoFechar, membros, negocios, diretorias, ehDiretor, usuarioId }: {
  tarefa: Tarefa | null; aoFechar: () => void; membros: MembroResumo[]; negocios: { id: string; titulo: string }[];
  diretorias: { slug: string; nome: string }[]; ehDiretor: boolean; usuarioId: string;
}) {
  const [pendente, iniciar] = useTransition();
  const t = tarefa;
  return (
    <Dialogo aberto aoFechar={aoFechar} titulo={t ? "Editar tarefa" : ehDiretor ? "Nova tarefa" : "Nova tarefa pessoal"}>
      <form className="grid gap-4 sm:grid-cols-2" action={(form) => iniciar(async () => {
        const g = (k: string) => String(form.get(k) ?? "");
        const r = await salvarTarefa(t ? t.id : null,
          { titulo: g("titulo"), descricao: g("descricao"), prazo: g("prazo"), prioridade: g("prioridade"), negocio_id: g("negocio_id"),
            diretoria: g("diretoria") || (t ? t.diretoria : diretorias[0]?.slug) || "" },
          form.getAll("responsaveis").map(String));
        if (!r.ok) return void toast.error(r.erro);
        toast.success("Tarefa salva.");
        aoFechar();
      })}>
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
        {ehDiretor ? (
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
        ) : (
          <p className="text-sm text-texto-suave sm:col-span-2">Tarefa pessoal: você é o responsável. <input type="hidden" name="responsaveis" value={usuarioId} /></p>
        )}
        <div className="flex justify-end gap-2 sm:col-span-2">
          <Botao type="button" variante="secundario" onClick={aoFechar}>Cancelar</Botao>
          <Botao type="submit" carregando={pendente}>Salvar</Botao>
        </div>
      </form>
    </Dialogo>
  );
}
