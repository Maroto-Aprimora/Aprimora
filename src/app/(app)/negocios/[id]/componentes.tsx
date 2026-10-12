"use client";

import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";
import { toast } from "sonner";
import { Trash2 } from "lucide-react";
import { Botao } from "@/components/ui/botao";
import { AreaTexto, Campo, Entrada, Selecao } from "@/components/ui/campos";
import { useMoverNegocio } from "@/components/crm/mover-negocio";
import { NOME_AREA, type CampoFase, type Fase, type MembroResumo, type Motivo } from "@/lib/crm";
import type { Json } from "@/lib/supabase/database.types";
import { excluirNegocio, salvarCamposFase, salvarNegocio } from "../acoes";

export function AcoesTopoNegocio({
  negocioId, titulo, faseAtualId, fases, motivos, podeEditar, podeExcluir,
}: {
  negocioId: string; titulo: string; faseAtualId: string; fases: Fase[]; motivos: Motivo[]; podeEditar: boolean; podeExcluir: boolean;
}) {
  const router = useRouter();
  const [pendente, iniciar] = useTransition();
  const { mover, dialogo, pendente: movendo } = useMoverNegocio(motivos, () => router.refresh());
  const [destino, setDestino] = useState("");

  return (
    <div className="flex flex-wrap items-center gap-2">
      {podeEditar && (
        <>
          <select
            className="h-10 rounded-md border border-borda bg-superficie px-3 text-sm"
            value={destino}
            onChange={(e) => setDestino(e.target.value)}
            aria-label="Mover para a fase"
          >
            <option value="">Mover para…</option>
            {fases.filter((f) => f.id !== faseAtualId).map((f) => <option key={f.id} value={f.id}>{f.nome}</option>)}
          </select>
          <Botao
            disabled={!destino}
            carregando={movendo}
            onClick={() => {
              const f = fases.find((x) => x.id === destino);
              if (f) mover(negocioId, titulo, f);
              setDestino("");
            }}
          >
            Mover
          </Botao>
        </>
      )}
      {podeExcluir && (
        <Botao
          variante="fantasma"
          aria-label="Excluir negócio"
          carregando={pendente}
          onClick={() =>
            confirm("Excluir este negócio e todo o histórico? Esta ação não pode ser desfeita.") &&
            iniciar(async () => {
              const r = await excluirNegocio(negocioId);
              if (!r.ok) return void toast.error(r.erro);
              toast.success("Negócio excluído.");
              router.replace("/funil");
            })
          }
        >
          <Trash2 className="h-4 w-4" />
        </Botao>
      )}
      {dialogo}
    </div>
  );
}

type DadosNegocio = {
  id: string; titulo: string; valor: number | null; responsavel_id: string | null; origem_id: string | null;
  origem_detalhe: string | null; contato_id: string | null; data_coldcall_1: string | null; data_coldcall_2: string | null;
  dores_identificadas: string | null;
};

export function FormNegocio({
  negocio, servicosSelecionados, valoresServicos, participantes, membros, origens, servicos, contatos, podeEditar,
}: {
  negocio: DadosNegocio; servicosSelecionados: string[]; valoresServicos: Record<string, number | null>; participantes: string[]; membros: MembroResumo[];
  origens: { id: string; nome: string }[]; servicos: { id: string; nome: string; area: keyof typeof NOME_AREA }[];
  contatos: { id: string; nome: string; cargo: string | null }[]; podeEditar: boolean;
}) {
  const [pendente, iniciar] = useTransition();
  const [marcados, setMarcados] = useState(() => new Set(servicosSelecionados));
  const temValorPorServico = Object.values(valoresServicos).some((v) => v != null);

  function enviar(form: FormData) {
    iniciar(async () => {
      const dados = Object.fromEntries(
        ["titulo", "valor", "responsavel_id", "origem_id", "origem_detalhe", "contato_id", "data_coldcall_1", "data_coldcall_2", "dores_identificadas"]
          .map((k) => [k, form.get(k)]),
      );
      const servicosMarcados = form.getAll("servicos").map(String);
      const valores = Object.fromEntries(servicosMarcados.map((id) => {
        const bruto = String(form.get(`valor_servico_${id}`) ?? "").trim();
        return [id, bruto ? Number(bruto.replace(/\./g, "").replace(",", ".")) : null];
      }));
      const r = await salvarNegocio(negocio.id, dados, servicosMarcados, form.getAll("participantes").map(String), valores);
      if (r.ok) toast.success("Negócio salvo.");
      else toast.error(r.erro);
    });
  }

  return (
    <form action={enviar}>
      <fieldset disabled={!podeEditar || pendente} className="grid gap-4 px-5 py-4 sm:grid-cols-2">
        <Campo rotulo="Título" obrigatorio className="sm:col-span-2"><Entrada name="titulo" defaultValue={negocio.titulo} required /></Campo>
        <Campo rotulo="Valor (R$)" dica={temValorPorServico ? "Soma dos valores por serviço (edite nos serviços abaixo)." : "Valor da proposta. Ou informe o valor de cada serviço abaixo."}>
          <Entrada name="valor" inputMode="decimal" defaultValue={negocio.valor ?? ""} placeholder="0" readOnly={temValorPorServico} />
        </Campo>
        <Campo rotulo="Responsável" dica="Vazio = distribuído pelo rodízio ao entrar em E-mail.">
          <Selecao name="responsavel_id" defaultValue={negocio.responsavel_id ?? ""}>
            <option value="">Sem responsável</option>
            {membros.map((m) => <option key={m.id} value={m.id}>{m.nome}</option>)}
          </Selecao>
        </Campo>
        <Campo rotulo="Origem do lead">
          <Selecao name="origem_id" defaultValue={negocio.origem_id ?? ""}>
            <option value="">—</option>
            {origens.map((o) => <option key={o.id} value={o.id}>{o.nome}</option>)}
          </Selecao>
        </Campo>
        <Campo rotulo="Detalhe da origem"><Entrada name="origem_detalhe" defaultValue={negocio.origem_detalhe ?? ""} placeholder="Ex.: indicação do cliente X" /></Campo>
        <Campo rotulo="Contato principal">
          <Selecao name="contato_id" defaultValue={negocio.contato_id ?? ""}>
            <option value="">—</option>
            {contatos.map((c) => <option key={c.id} value={c.id}>{c.nome}{c.cargo ? ` (${c.cargo})` : ""}</option>)}
          </Selecao>
        </Campo>
        <div className="grid grid-cols-2 gap-3">
          <Campo rotulo="Coldcall 1"><Entrada type="date" name="data_coldcall_1" defaultValue={negocio.data_coldcall_1 ?? ""} /></Campo>
          <Campo rotulo="Coldcall 2"><Entrada type="date" name="data_coldcall_2" defaultValue={negocio.data_coldcall_2 ?? ""} /></Campo>
        </div>
        <Campo rotulo="Dores identificadas" className="sm:col-span-2">
          <AreaTexto name="dores_identificadas" defaultValue={negocio.dores_identificadas ?? ""} />
        </Campo>

        <div className="sm:col-span-2">
          <p className="mb-2 text-xs font-semibold uppercase tracking-wide text-texto-suave">Serviços de interesse e valor de cada um (R$)</p>
          <div className="grid gap-x-4 gap-y-1.5 sm:grid-cols-2">
            {servicos.map((s) => (
              <div key={s.id} className="flex items-center gap-2 text-sm">
                <label className="flex min-w-0 flex-1 items-center gap-2">
                  <input type="checkbox" name="servicos" value={s.id} checked={marcados.has(s.id)}
                    onChange={(e) => setMarcados((atual) => {
                      const novo = new Set(atual);
                      if (e.target.checked) novo.add(s.id); else novo.delete(s.id);
                      return novo;
                    })} />
                  <span className="truncate">{s.nome} <span className="text-xs text-texto-suave">· {NOME_AREA[s.area]}</span></span>
                </label>
                {marcados.has(s.id) && (
                  <Entrada name={`valor_servico_${s.id}`} inputMode="decimal" defaultValue={valoresServicos[s.id] ?? ""}
                    placeholder="Valor" aria-label={`Valor de ${s.nome}`} className="h-8 w-28" />
                )}
              </div>
            ))}
          </div>
        </div>

        <div className="sm:col-span-2">
          <p className="mb-2 text-xs font-semibold uppercase tracking-wide text-texto-suave">Participantes (também podem editar)</p>
          <div className="flex flex-wrap gap-x-4 gap-y-1.5">
            {membros.map((m) => (
              <label key={m.id} className="flex items-center gap-2 text-sm">
                <input type="checkbox" name="participantes" value={m.id} defaultChecked={participantes.includes(m.id)} />
                {m.nome}
              </label>
            ))}
          </div>
        </div>
      </fieldset>
      {podeEditar && (
        <div className="flex justify-end border-t border-borda px-5 py-3">
          <Botao type="submit" carregando={pendente}>Salvar</Botao>
        </div>
      )}
    </form>
  );
}

export function FormCamposFase({
  negocioId, campos, valores, membros, podeEditar,
}: {
  negocioId: string; campos: CampoFase[]; valores: Record<string, unknown>; membros: MembroResumo[]; podeEditar: boolean;
}) {
  const [pendente, iniciar] = useTransition();

  function enviar(form: FormData) {
    const novos: Record<string, Json> = {};
    for (const c of campos) {
      if (c.tipo === "membros") novos[c.chave] = form.getAll(c.chave).map(String);
      else if (c.tipo === "booleano") novos[c.chave] = form.get(c.chave) === "on";
      else novos[c.chave] = String(form.get(c.chave) ?? "").trim();
    }
    iniciar(async () => {
      const r = await salvarCamposFase(negocioId, novos);
      if (r.ok) toast.success("Campos salvos.");
      else toast.error(r.erro);
    });
  }

  return (
    <form action={enviar}>
      <fieldset disabled={!podeEditar || pendente} className="grid gap-4 px-5 py-4 sm:grid-cols-2">
        {campos.map((c) => {
          const valor = valores[c.chave];
          const longo = c.tipo === "texto_longo" || c.tipo === "membros";
          return (
            <Campo key={c.id} rotulo={c.rotulo} obrigatorio={c.obrigatorio} dica={c.obrigatorio ? "Obrigatório para avançar de fase." : c.ajuda ?? undefined}
              className={longo ? "sm:col-span-2" : undefined}>
              {c.tipo === "texto_longo" ? (
                <AreaTexto name={c.chave} defaultValue={String(valor ?? "")} />
              ) : c.tipo === "data" ? (
                <Entrada type="date" name={c.chave} defaultValue={String(valor ?? "")} />
              ) : c.tipo === "numero" || c.tipo === "moeda" ? (
                <Entrada inputMode="decimal" name={c.chave} defaultValue={String(valor ?? "")} />
              ) : c.tipo === "link" ? (
                <Entrada type="url" name={c.chave} defaultValue={String(valor ?? "")} placeholder="https://drive.google.com/…" />
              ) : c.tipo === "selecao" ? (
                <Selecao name={c.chave} defaultValue={String(valor ?? "")}>
                  <option value="">—</option>
                  {(Array.isArray(c.opcoes) ? c.opcoes : []).map((o) => <option key={String(o)} value={String(o)}>{String(o)}</option>)}
                </Selecao>
              ) : c.tipo === "booleano" ? (
                <input type="checkbox" name={c.chave} defaultChecked={valor === true} className="h-5 w-5" />
              ) : c.tipo === "membros" ? (
                <div className="flex flex-wrap gap-x-4 gap-y-1.5">
                  {membros.map((m) => (
                    <label key={m.id} className="flex items-center gap-2 text-sm">
                      <input type="checkbox" name={c.chave} value={m.id} defaultChecked={Array.isArray(valor) && valor.includes(m.id)} />
                      {m.nome}
                    </label>
                  ))}
                </div>
              ) : (
                <Entrada name={c.chave} defaultValue={String(valor ?? "")} />
              )}
            </Campo>
          );
        })}
      </fieldset>
      {podeEditar && (
        <div className="flex justify-end border-t border-borda px-5 py-3">
          <Botao type="submit" variante="secundario" carregando={pendente}>Salvar campos</Botao>
        </div>
      )}
    </form>
  );
}
