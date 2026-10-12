"use client";

import { useState, useTransition } from "react";
import { toast } from "sonner";
import { Plus, Trash2 } from "lucide-react";
import { Botao } from "@/components/ui/botao";
import { Campo, Entrada, Selecao } from "@/components/ui/campos";
import { Dialogo } from "@/components/ui/dialogo";
import { Cartao, CabecalhoCartao } from "@/components/ui/cartao";
import { Selo } from "@/components/ui/selo";
import type { Tables } from "@/lib/supabase/database.types";
import { cn } from "@/lib/utils";
import { NOME_PRAZO_TAREFA } from "@/lib/crm";
import {
  excluirCampo, excluirFase, excluirFeriado, excluirPassoCadencia, salvarCampo, salvarFase, salvarFeriado, salvarItem,
  salvarParametrosCadencia, salvarPassoCadencia, salvarResultadoLigacao,
} from "./acoes";

const NOME_TIPO: Record<string, string> = {
  texto: "Texto", texto_longo: "Texto longo", data: "Data", numero: "Número", moeda: "Moeda", membros: "Membros",
  selecao: "Seleção", booleano: "Sim/Não", link: "Link",
};

export function LinhaFase({ fase, fases, negociosNaFase, destinosPossiveis }: {
  fase: Tables<"fases">; fases: { id: string; nome: string }[]; negociosNaFase: number; destinosPossiveis: { id: string; nome: string }[];
}) {
  const [pendente, iniciar] = useTransition();
  const [excluindo, setExcluindo] = useState(false);
  return (
    <tr>
      <td className="px-3 py-2" colSpan={8}>
        <form
          className="grid grid-cols-[minmax(180px,1.4fr)_90px_120px_minmax(160px,1fr)_80px_70px_60px_120px] items-center gap-2"
          action={(form) => iniciar(async () => {
            const sla = String(form.get("sla_dias") ?? "");
            const acao = String(form.get("acao_sla") ?? "");
            const destino = String(form.get("fase_destino_sla") ?? "");
            const r = await salvarFase(fase.id, {
              nome: String(form.get("nome")),
              descricao: fase.descricao,
              sla_dias: sla ? Number(sla) : null,
              acao_sla: acao ? (acao as "mover") : null,
              fase_destino_sla: destino || null,
              probabilidade: Number(form.get("probabilidade") || 0) / 100,
              distribui_responsavel: form.get("distribui") === "on",
              ativa: form.get("ativa") === "on",
            });
            if (r.ok) toast.success(`Fase "${String(form.get("nome"))}" salva.`);
            else toast.error(r.erro);
          })}
        >
          <div className="flex items-center gap-2">
            <Selo tom={fase.tipo === "ganho" ? "sucesso" : fase.tipo === "perda" ? "perigo" : fase.tipo === "pausa" ? "neutro" : "marca"}>{fase.ordem}</Selo>
            <Entrada name="nome" defaultValue={fase.nome} className="h-9" />
          </div>
          <Entrada name="sla_dias" type="number" min={1} defaultValue={fase.sla_dias ?? ""} className="h-9" placeholder="—" />
          <Selecao name="acao_sla" defaultValue={fase.acao_sla ?? ""} className="h-9">
            <option value="">Nada</option>
            <option value="alertar">Alertar</option>
            <option value="mover">Mover</option>
          </Selecao>
          <Selecao name="fase_destino_sla" defaultValue={fase.fase_destino_sla ?? ""} className="h-9"
            title={fase.tipo === "pausa" ? "Para onde o lead volta na data de retorno" : undefined}>
            <option value="">—</option>
            {fases.filter((f) => f.id !== fase.id).map((f) => <option key={f.id} value={f.id}>{f.nome}</option>)}
          </Selecao>
          <Entrada name="probabilidade" type="number" min={0} max={100} defaultValue={Math.round(fase.probabilidade * 100)} className="h-9" />
          <input type="checkbox" name="distribui" defaultChecked={fase.distribui_responsavel} className="mx-auto h-4 w-4" title="Distribui responsável por rodízio" />
          <input type="checkbox" name="ativa" defaultChecked={fase.ativa} className="mx-auto h-4 w-4" />
          <div className="flex items-center gap-1">
            <Botao type="submit" tamanho="sm" variante="secundario" carregando={pendente}>Salvar</Botao>
            <Botao type="button" tamanho="icone" variante="fantasma" aria-label={`Excluir a fase ${fase.nome}`} title="Excluir fase"
              onClick={() => setExcluindo(true)}>
              <Trash2 className="h-4 w-4" />
            </Botao>
          </div>
        </form>
        {excluindo && (
          <Dialogo aberto aoFechar={() => setExcluindo(false)} titulo={`Excluir a fase "${fase.nome}"`}
            descricao="A coluna some do funil e das configurações. O histórico dos negócios que passaram por ela é mantido.">
            <form className="space-y-4" action={(f) => iniciar(async () => {
              const r = await excluirFase(fase.id, String(f.get("destino") ?? "") || null);
              if (!r.ok) return void toast.error(r.erro);
              toast.success(r.movidos ? `Fase excluída. ${r.movidos} negócio(s) movido(s).` : "Fase excluída.");
              setExcluindo(false);
            })}>
              {negociosNaFase > 0 ? (
                <Campo rotulo={`${negociosNaFase} negócio(s) estão nesta fase. Mover para`} obrigatorio>
                  <Selecao name="destino" required defaultValue="">
                    <option value="" disabled>Escolha a fase…</option>
                    {destinosPossiveis.map((d) => <option key={d.id} value={d.id}>{d.nome}</option>)}
                  </Selecao>
                </Campo>
              ) : (
                <p className="text-sm text-texto-suave">Nenhum negócio está nesta fase agora.</p>
              )}
              <div className="flex justify-end gap-2">
                <Botao type="button" variante="secundario" onClick={() => setExcluindo(false)}>Cancelar</Botao>
                <Botao type="submit" variante="perigo" carregando={pendente}>Excluir fase</Botao>
              </div>
            </form>
          </Dialogo>
        )}
      </td>
    </tr>
  );
}

export function CamposDaFase({ fase, campos }: { fase: { id: string; nome: string }; campos: Tables<"fase_campos">[] }) {
  const [pendente, iniciar] = useTransition();
  const [novo, setNovo] = useState(false);
  return (
    <div className="rounded-lg border border-borda">
      <div className="flex items-center justify-between border-b border-borda px-3 py-2">
        <p className="text-sm font-bold">{fase.nome}</p>
        <button className="text-xs font-semibold text-marca hover:text-destaque" onClick={() => setNovo((v) => !v)}>
          {novo ? "Cancelar" : "+ Campo"}
        </button>
      </div>
      <ul className="divide-y divide-borda text-sm">
        {campos.map((c) => (
          <li key={c.id} className="flex items-center justify-between gap-2 px-3 py-1.5">
            <span className="min-w-0 truncate">{c.rotulo} <span className="text-xs text-texto-suave">· {NOME_TIPO[c.tipo]}</span></span>
            <span className="flex shrink-0 items-center gap-2">
              <label className="flex items-center gap-1 text-xs text-texto-suave" title="Obrigatório para avançar">
                <input type="checkbox" defaultChecked={c.obrigatorio} disabled={pendente}
                  onChange={(e) => iniciar(async () => {
                    const r = await salvarCampo(c.id, { fase_id: fase.id, rotulo: c.rotulo, tipo: c.tipo, obrigatorio: e.target.checked, opcoes: Array.isArray(c.opcoes) ? c.opcoes.map(String) : null });
                    if (!r.ok) toast.error(r.erro);
                  })} />
                obrig.
              </label>
              <button aria-label="Excluir campo" className="text-texto-suave hover:text-perigo" disabled={pendente}
                onClick={() => confirm(`Excluir o campo "${c.rotulo}"? Os valores já preenchidos ficam guardados no negócio.`)
                  && iniciar(async () => { const r = await excluirCampo(c.id); if (!r.ok) toast.error(r.erro); })}>
                <Trash2 className="h-3.5 w-3.5" />
              </button>
            </span>
          </li>
        ))}
        {campos.length === 0 && !novo && <li className="px-3 py-2 text-xs text-texto-suave">Sem campos específicos.</li>}
      </ul>
      {novo && (
        <form className="space-y-2 border-t border-borda p-3" action={(form) => iniciar(async () => {
          const tipo = String(form.get("tipo")) as Tables<"fase_campos">["tipo"];
          const opcoes = String(form.get("opcoes") ?? "").split(";").map((s) => s.trim()).filter(Boolean);
          const r = await salvarCampo(null, { fase_id: fase.id, rotulo: String(form.get("rotulo")), tipo, obrigatorio: form.get("obrigatorio") === "on", opcoes: tipo === "selecao" ? opcoes : null });
          if (!r.ok) return void toast.error(r.erro);
          toast.success("Campo criado.");
          setNovo(false);
        })}>
          <Entrada name="rotulo" placeholder="Nome do campo" required className="h-9" />
          <Selecao name="tipo" defaultValue="texto" className="h-9">
            {Object.entries(NOME_TIPO).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
          </Selecao>
          <Entrada name="opcoes" placeholder="Opções da seleção, separadas por ;" className="h-9" />
          <label className="flex items-center gap-2 text-xs"><input type="checkbox" name="obrigatorio" /> Obrigatório para avançar</label>
          <Botao type="submit" tamanho="sm" carregando={pendente}>Adicionar</Botao>
        </form>
      )}
    </div>
  );
}

type Item = { id: string; nome: string; ativo: boolean; detalhe?: string; descricao?: string | null };

export function ListaSimples({
  titulo, tabela, itens, extra, semCriar, className,
}: {
  titulo: string; tabela: "motivos" | "origens" | "segmentos" | "servicos"; itens: Item[];
  extra?: { tipo?: "perda" | "desqualificacao" }; semCriar?: boolean; className?: string;
}) {
  const [pendente, iniciar] = useTransition();
  const salvar = (id: string | null, nome: string, ativo: boolean, msg: string) =>
    iniciar(async () => {
      const r = await salvarItem(tabela, id, { nome, ativo, ...extra });
      if (r.ok) toast.success(msg);
      else toast.error(r.erro);
    });

  return (
    <Cartao className={className}>
      <CabecalhoCartao titulo={titulo} descricao="Itens inativos deixam de aparecer nos formulários, mas o histórico é mantido." />
      <ul className="divide-y divide-borda">
        {itens.map((i) => (
          <li key={i.id} className="flex items-center gap-2 px-5 py-2">
            <form className="flex flex-1 items-center gap-2" action={(form) => salvar(i.id, String(form.get("nome")), i.ativo, "Salvo.")}>
              <Entrada name="nome" defaultValue={i.nome} className={cn("h-9", !i.ativo && "opacity-50")} />
              {i.detalhe && <Selo>{i.detalhe}</Selo>}
              <Botao type="submit" tamanho="sm" variante="fantasma" disabled={pendente}>Salvar</Botao>
            </form>
            <label className="flex items-center gap-1 text-xs text-texto-suave">
              <input type="checkbox" defaultChecked={i.ativo} disabled={pendente} onChange={(e) => salvar(i.id, i.nome, e.target.checked, e.target.checked ? "Ativado." : "Desativado.")} />
              ativo
            </label>
          </li>
        ))}
      </ul>
      {!semCriar && (
        <form className="flex gap-2 border-t border-borda px-5 py-3" action={(form) => { salvar(null, String(form.get("nome")), true, "Adicionado."); }}>
          <Entrada name="nome" placeholder="Novo item" className="h-9" required />
          <Botao type="submit" tamanho="sm" carregando={pendente}><Plus className="h-3.5 w-3.5" /> Adicionar</Botao>
        </form>
      )}
    </Cartao>
  );
}

type Opcao = { id: string; nome: string };

/** Um resultado de ligação: nome, ação no card e tarefa criada (PE-PA-002, Seção 3.1). */
export function ResultadoLigacaoForm({
  resultado, fases, motivos, tiposAtividade,
}: {
  resultado: Tables<"resultados_ligacao"> | null;
  fases: (Opcao & { exige_motivo: Tables<"fases">["exige_motivo"] })[];
  motivos: (Opcao & { tipo: Tables<"motivos">["tipo"] })[];
  tiposAtividade: Opcao[];
}) {
  const [pendente, iniciar] = useTransition();
  const [destino, setDestino] = useState(resultado?.fase_destino_id ?? "");
  const exigeMotivo = fases.find((f) => f.id === destino)?.exige_motivo ?? null;
  const marca = (nome: string, rotulo: string, valor: boolean | undefined) => (
    <label className="flex items-center gap-1.5 text-xs"><input type="checkbox" name={nome} defaultChecked={valor} /> {rotulo}</label>
  );

  return (
    <form
      className={cn("grid gap-2 px-5 py-3 md:grid-cols-[minmax(160px,1fr)_minmax(160px,1fr)_minmax(200px,1.3fr)_auto]", resultado && !resultado.ativo && "opacity-60")}
      action={(form) => iniciar(async () => {
        const txt = (k: string) => String(form.get(k) ?? "") || null;
        const r = await salvarResultadoLigacao(resultado?.id ?? null, {
          nome: String(form.get("nome") ?? ""),
          ativo: resultado ? form.get("ativo") === "on" : true,
          fase_destino_id: txt("fase_destino_id"),
          motivo_id: exigeMotivo ? txt("motivo_id") : null,
          conta_tentativa: form.get("conta_tentativa") === "on",
          exige_retorno: form.get("exige_retorno") === "on",
          registra_decisor: form.get("registra_decisor") === "on",
          marca_telefone_invalido: form.get("marca_telefone_invalido") === "on",
          tipo_atividade_id: txt("tipo_atividade_id"),
          tarefa_titulo: txt("tarefa_titulo"),
          tarefa_prazo: txt("tarefa_prazo") as "mesmo_dia" | null,
        });
        if (r.ok) toast.success(resultado ? "Resultado salvo." : "Resultado criado.");
        else toast.error(r.erro);
      })}
    >
      <div className="space-y-2">
        <Entrada name="nome" defaultValue={resultado?.nome} placeholder="Nome do resultado" required className="h-9 font-semibold" />
        <div className="flex flex-wrap gap-x-3 gap-y-1">
          {resultado && marca("ativo", "ativo", resultado.ativo)}
          {marca("conta_tentativa", "conta como tentativa", resultado?.conta_tentativa)}
        </div>
      </div>
      <div className="space-y-2">
        <Selecao name="fase_destino_id" value={destino} onChange={(e) => setDestino(e.target.value)} className="h-9" aria-label="O que acontece com o card">
          <option value="">Fica na fase</option>
          {fases.map((f) => <option key={f.id} value={f.id}>Vai para {f.nome}</option>)}
        </Selecao>
        {exigeMotivo && (
          <Selecao name="motivo_id" defaultValue={resultado?.motivo_id ?? ""} className="h-9" aria-label="Motivo">
            <option value="">Motivo: perguntar</option>
            {motivos.filter((m) => m.tipo === exigeMotivo).map((m) => <option key={m.id} value={m.id}>Motivo: {m.nome}</option>)}
          </Selecao>
        )}
        <div className="flex flex-wrap gap-x-3 gap-y-1">
          {marca("exige_retorno", "pede data de retorno", resultado?.exige_retorno)}
          {marca("registra_decisor", "pede decisor e horário", resultado?.registra_decisor)}
          {marca("marca_telefone_invalido", "marca telefone inválido", resultado?.marca_telefone_invalido)}
        </div>
      </div>
      <div className="space-y-2">
        <Entrada name="tarefa_titulo" defaultValue={resultado?.tarefa_titulo ?? ""} placeholder="Tarefa criada (vazio = nenhuma)" className="h-9" />
        <div className="grid grid-cols-2 gap-2">
          <Selecao name="tarefa_prazo" defaultValue={resultado?.tarefa_prazo ?? ""} className="h-9" aria-label="Prazo da tarefa">
            <option value="">Prazo…</option>
            {Object.entries(NOME_PRAZO_TAREFA).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
          </Selecao>
          <Selecao name="tipo_atividade_id" defaultValue={resultado?.tipo_atividade_id ?? ""} className="h-9" aria-label="Compromisso na agenda">
            <option value="">Sem compromisso</option>
            {tiposAtividade.map((t) => <option key={t.id} value={t.id}>Agenda: {t.nome}</option>)}
          </Selecao>
        </div>
      </div>
      <div className="flex items-start">
        <Botao type="submit" tamanho="sm" variante="secundario" carregando={pendente}>{resultado ? "Salvar" : <><Plus className="h-3.5 w-3.5" /> Adicionar</>}</Botao>
      </div>
    </form>
  );
}

export function ListaFeriados({ feriados }: { feriados: Tables<"feriados">[] }) {
  const [pendente, iniciar] = useTransition();
  const hoje = new Date().toISOString().slice(0, 10);
  const proximos = feriados.filter((f) => f.data >= hoje);
  return (
    <Cartao>
      <CabecalhoCartao titulo="Feriados" descricao="Tarefas automáticas que cairiam em fim de semana ou feriado vão para o próximo dia útil." />
      <ul className="max-h-72 divide-y divide-borda overflow-y-auto">
        {proximos.map((f) => (
          <li key={f.data} className="flex items-center justify-between gap-2 px-5 py-2 text-sm">
            <span><strong className="mr-2 tabular-nums">{f.data.split("-").reverse().join("/")}</strong>{f.nome}</span>
            <button aria-label={`Excluir ${f.nome}`} className="text-texto-suave hover:text-perigo" disabled={pendente}
              onClick={() => iniciar(async () => { const r = await excluirFeriado(f.data); if (!r.ok) toast.error(r.erro); })}>
              <Trash2 className="h-3.5 w-3.5" />
            </button>
          </li>
        ))}
        {proximos.length === 0 && <li className="px-5 py-2 text-sm text-texto-suave">Nenhum feriado futuro cadastrado.</li>}
      </ul>
      <form className="flex gap-2 border-t border-borda px-5 py-3" action={(form) => iniciar(async () => {
        const r = await salvarFeriado({ data: String(form.get("data")), nome: String(form.get("nome")) });
        if (r.ok) toast.success("Feriado salvo.");
        else toast.error(r.erro);
      })}>
        <Entrada type="date" name="data" required className="h-9 w-40" />
        <Entrada name="nome" placeholder="Nome" required className="h-9" />
        <Botao type="submit" tamanho="sm" carregando={pendente}><Plus className="h-3.5 w-3.5" /> Adicionar</Botao>
      </form>
    </Cartao>
  );
}

/** Cadência padrão: os toques (dia, canal) e o prazo até a Reciclagem. */
export function Cadencia({ passos, parametros }: {
  passos: Tables<"cadencia_passos">[]; parametros: Tables<"parametros_comercial"> | null;
}) {
  const [pendente, iniciar] = useTransition();
  const linha = (p: Tables<"cadencia_passos"> | null) => (
    <form key={p?.id ?? "novo"} className={cn("grid items-center gap-2 px-5 py-2 sm:grid-cols-[80px_130px_1fr_auto_auto]", p && !p.ativo && "opacity-60")}
      action={(form) => iniciar(async () => {
        const r = await salvarPassoCadencia(p?.id ?? null, {
          dia: Number(form.get("dia") ?? 0), canal: String(form.get("canal")) as "email",
          titulo: String(form.get("titulo") ?? ""), so_sem_contato: form.get("so_sem_contato") === "on",
          ativo: p ? form.get("ativo") === "on" : true,
        });
        if (r.ok) toast.success(p ? "Toque salvo." : "Toque adicionado.");
        else toast.error(r.erro);
      })}>
      <div className="flex items-center gap-1"><span className="text-sm font-semibold text-texto-suave">D</span>
        <Entrada name="dia" type="number" min={0} defaultValue={p?.dia ?? ""} required className="h-9" aria-label="Dia" /></div>
      <Selecao name="canal" defaultValue={p?.canal ?? "email"} className="h-9" aria-label="Canal">
        <option value="email">E-mail</option>
        <option value="ligacao">Ligação</option>
      </Selecao>
      <Entrada name="titulo" defaultValue={p?.titulo ?? ""} placeholder="Título da tarefa" required className="h-9" />
      <div className="flex gap-3">
        <label className="flex items-center gap-1 text-xs" title="Só cria a tarefa se ainda não houve contato efetivo">
          <input type="checkbox" name="so_sem_contato" defaultChecked={p?.so_sem_contato} /> só sem contato</label>
        {p && <label className="flex items-center gap-1 text-xs"><input type="checkbox" name="ativo" defaultChecked={p.ativo} /> ativo</label>}
      </div>
      <div className="flex items-center gap-1">
        <Botao type="submit" tamanho="sm" variante="secundario" carregando={pendente}>{p ? "Salvar" : <><Plus className="h-3.5 w-3.5" /> Adicionar</>}</Botao>
        {p && (
          <button type="button" aria-label="Excluir toque" className="p-1 text-texto-suave hover:text-perigo" disabled={pendente}
            onClick={() => confirm(`Excluir o toque D${p.dia}?`) && iniciar(async () => { const r = await excluirPassoCadencia(p.id); if (!r.ok) toast.error(r.erro); })}>
            <Trash2 className="h-3.5 w-3.5" />
          </button>
        )}
      </div>
    </form>
  );

  return (
    <Cartao className="mb-6">
      <CabecalhoCartao titulo="Cadência padrão"
        descricao="D0 é a entrada do card em E-mail. Todo dia útil às 7h30 o responsável recebe as tarefas dos toques do dia (fim de semana e feriado vão para o próximo dia útil). Contato efetivo numa ligação pausa a contagem." />
      <div className="divide-y divide-borda">
        {passos.map((p) => linha(p))}
        {linha(null)}
      </div>
      {parametros && (
        <form className="flex flex-wrap items-end gap-3 border-t border-borda px-5 py-3 text-sm"
          action={(form) => iniciar(async () => {
            const r = await salvarParametrosCadencia({
              cadencia_dias_reciclagem: Number(form.get("cadencia_dias_reciclagem")), reciclagem_retorno_dias: Number(form.get("reciclagem_retorno_dias")),
            });
            if (r.ok) toast.success("Prazos salvos.");
            else toast.error(r.erro);
          })}>
          <Campo rotulo="Sem resposta, vai para Reciclagem no dia">
            <Entrada name="cadencia_dias_reciclagem" type="number" min={1} defaultValue={parametros.cadencia_dias_reciclagem} className="h-9 w-28" />
          </Campo>
          <Campo rotulo="Retorno da Reciclagem em (dias)">
            <Entrada name="reciclagem_retorno_dias" type="number" min={1} defaultValue={parametros.reciclagem_retorno_dias} className="h-9 w-28" />
          </Campo>
          <Botao type="submit" tamanho="sm" variante="secundario" carregando={pendente}>Salvar prazos</Botao>
        </form>
      )}
    </Cartao>
  );
}
