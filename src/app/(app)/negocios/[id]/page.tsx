import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { ArrowLeft, Building2 } from "lucide-react";
import { Cartao, CabecalhoCartao } from "@/components/ui/cartao";
import { Avatar, Selo } from "@/components/ui/selo";
import { NOME_MACROETAPA, situacaoSla } from "@/lib/crm";
import { carregarConfiguracaoComercial, carregarTodosMembros } from "@/lib/crm-servidor";
import { criarClienteServidor } from "@/lib/supabase/server";
import { diasDesde, formatarData, formatarDataHora, formatarMoeda, iniciais } from "@/lib/formatar";
import { obterUsuario } from "@/lib/usuario";
import { AtividadesDoNegocio } from "@/components/agenda/atividades-negocio";
import { AnexosDoNegocio } from "@/components/crm/anexos";
import { RegistrarLigacao } from "@/components/crm/registrar-ligacao";
import { AcoesTopoNegocio, FormCamposFase, FormNegocio } from "./componentes";

export const metadata: Metadata = { title: "Negócio" };

export default async function PaginaNegocio({ params }: PageProps<"/negocios/[id]">) {
  const { id } = await params;
  const supabase = await criarClienteServidor();
  const [usuario, config, todosMembros, { data: negocio }] = await Promise.all([
    obterUsuario(),
    carregarConfiguracaoComercial(),
    carregarTodosMembros(),
    supabase
      .from("negocios")
      .select("*, empresas(id, nome, cidade, uf, telefone, email_principal), negocio_servicos(servico_id, valor), negocio_participantes(membro_id), motivos(nome)")
      .eq("id", id)
      .maybeSingle(),
  ]);
  if (!negocio) notFound();

  const [{ data: contatos }, { data: historico }, { data: atividades }, { data: tipos }, { data: anexos }, { data: ligacoes }] = await Promise.all([
    supabase.from("contatos").select("id, nome, cargo, decisor, telefone, telefone_invalido, nao_contatar").eq("empresa_id", negocio.empresa_id).order("decisor", { ascending: false }),
    supabase.from("negocio_historico").select("id, fase_origem_id, fase_destino_id, autor_id, automatico, comentario, created_at, motivos(nome)")
      .eq("negocio_id", id).order("created_at", { ascending: false }),
    supabase.from("atividades").select("*, atividade_participantes(membro_id)").eq("negocio_id", id).order("inicio", { ascending: false }),
    supabase.from("tipos_atividade").select("*").eq("ativo", true).order("ordem"),
    supabase.from("anexos").select("id, nome, caminho, tamanho, enviado_por, created_at").eq("negocio_id", id).order("created_at", { ascending: false }),
    supabase.from("ligacoes").select("id, inicio, membro_id, duracao_seg, proximo_passo, comentario, retorno_em, decisor_nome, decisor_melhor_horario, origem, resultados_ligacao(nome), contatos(nome)")
      .eq("negocio_id", id).order("inicio", { ascending: false }),
  ]);

  const fase = config.fases.find((f) => f.id === negocio.fase_id);
  const participantes = negocio.negocio_participantes.map((p) => p.membro_id);
  const podeEditar = usuario.ehDiretorDe("comercial") || negocio.responsavel_id === usuario.id || participantes.includes(usuario.id);
  const nomeMembro = (mid: string | null) => todosMembros.find((m) => m.id === mid)?.nome ?? "—";
  const nomeFase = (fid: string | null) => config.todasFases.find((f) => f.id === fid)?.nome ?? "—";
  const dias = diasDesde(negocio.entrou_na_fase_em);
  const sla = fase ? situacaoSla(fase, dias) : "sem";

  // Campos das fases já percorridas e da fase atual (na ordem do funil)
  const fasesComCampos = config.fases
    .filter((f) => fase && (f.ordem <= fase.ordem || f.id === fase.id) && f.tipo !== "perda")
    .map((f) => ({ fase: f, campos: config.campos.filter((c) => c.fase_id === f.id) }))
    .filter((g) => g.campos.length > 0)
    .reverse();

  return (
    <div className="mx-auto max-w-6xl">
      <Link href="/funil" className="mb-3 inline-flex items-center gap-1 text-sm text-texto-suave hover:text-destaque">
        <ArrowLeft className="h-4 w-4" /> Funil
      </Link>

      <div className="mb-6 flex flex-wrap items-start justify-between gap-4">
        <div className="min-w-0">
          <div className="flex flex-wrap items-center gap-2">
            {fase && <Selo tom={fase.tipo === "ganho" ? "sucesso" : fase.tipo === "perda" ? "perigo" : "marca"}>{NOME_MACROETAPA[fase.macroetapa]} · {fase.nome}</Selo>}
            {sla === "estourado" && <Selo tom="destaque">SLA estourado ({dias} de {fase?.sla_dias} dias)</Selo>}
            {negocio.ficticio && <Selo>fictício</Selo>}
          </div>
          <h1 className="mt-2 text-2xl font-bold">{negocio.titulo}</h1>
          <Link href={`/empresas/${negocio.empresas.id}`} className="mt-1 inline-flex items-center gap-1 text-sm text-texto-suave hover:text-destaque">
            <Building2 className="h-4 w-4" /> {negocio.empresas.nome}{negocio.empresas.cidade ? ` · ${negocio.empresas.cidade}` : ""}
          </Link>
        </div>
        <div className="flex flex-wrap items-center gap-2">
        {podeEditar && fase?.tipo !== "ganho" && fase?.tipo !== "perda" && (
          <RegistrarLigacao negocioId={negocio.id} titulo={negocio.titulo} resultados={config.resultadosLigacao}
            contatos={contatos ?? []} contatoPadrao={negocio.contato_id} />
        )}
        <AcoesTopoNegocio
          negocioId={negocio.id}
          titulo={negocio.titulo}
          faseAtualId={negocio.fase_id}
          fases={config.fases}
          motivos={config.motivos}
          podeEditar={podeEditar}
          podeExcluir={usuario.ehDiretorDe("comercial")}
        />
        </div>
      </div>

      <div className="mb-6 grid grid-cols-2 gap-3 md:grid-cols-4">
        <Indicador rotulo="Valor" valor={formatarMoeda(negocio.valor)} />
        <Indicador rotulo="Na fase há" valor={`${dias} ${dias === 1 ? "dia" : "dias"}`} />
        <Indicador rotulo="Responsável" valor={negocio.responsavel_id ? nomeMembro(negocio.responsavel_id) : "Sem responsável"} />
        <Indicador rotulo="Criado em" valor={formatarData(negocio.created_at)} />
      </div>

      {negocio.motivos && (
        <Cartao className="mb-6 border-perigo/40 bg-perigo-suave p-4 text-sm">
          <strong>Motivo:</strong> {negocio.motivos.nome}{negocio.motivo_detalhe ? ` — ${negocio.motivo_detalhe}` : ""}
        </Cartao>
      )}
      {negocio.retorno_em && fase?.tipo === "pausa" && (
        <Cartao className="mb-6 p-4 text-sm">Volta para o funil em <strong>{formatarData(negocio.retorno_em)}</strong>.</Cartao>
      )}
      {negocio.retorno_em && fase?.tipo === "aberta" && (
        <Cartao className="mb-6 p-4 text-sm">Retornar a ligação em <strong>{formatarData(negocio.retorno_em)}</strong>.</Cartao>
      )}

      <div className="grid gap-6 lg:grid-cols-[1fr_340px]">
        <div className="space-y-6">
          <Cartao>
            <CabecalhoCartao titulo="Dados do negócio" descricao={podeEditar ? undefined : "Somente leitura: você não é responsável nem participante."} />
            <FormNegocio
              negocio={{
                id: negocio.id, titulo: negocio.titulo, valor: negocio.valor, responsavel_id: negocio.responsavel_id,
                origem_id: negocio.origem_id, origem_detalhe: negocio.origem_detalhe, contato_id: negocio.contato_id,
                data_coldcall_1: negocio.data_coldcall_1, data_coldcall_2: negocio.data_coldcall_2, dores_identificadas: negocio.dores_identificadas,
              }}
              servicosSelecionados={negocio.negocio_servicos.map((s) => s.servico_id)}
              valoresServicos={Object.fromEntries(negocio.negocio_servicos.map((s) => [s.servico_id, s.valor]))}
              participantes={participantes}
              membros={config.membrosComercial}
              origens={config.origens}
              servicos={config.servicos}
              contatos={contatos ?? []}
              podeEditar={podeEditar}
            />
          </Cartao>

          <Cartao>
            <CabecalhoCartao titulo="Ligações" descricao={`${(ligacoes ?? []).length} registrada${(ligacoes ?? []).length === 1 ? "" : "s"}`} />
            <ul className="divide-y divide-borda">
              {(ligacoes ?? []).map((l) => (
                <li key={l.id} className="px-5 py-3 text-sm">
                  <div className="flex flex-wrap items-center gap-2">
                    <Selo tom="marca">{l.resultados_ligacao?.nome ?? "Aguardando resultado"}</Selo>
                    <span className="text-xs text-texto-suave">
                      {formatarDataHora(l.inicio)} · {nomeMembro(l.membro_id)}
                      {l.contatos ? ` · com ${l.contatos.nome}` : ""}
                      {l.duracao_seg != null ? ` · ${Math.max(1, Math.round(l.duracao_seg / 60))} min` : ""}
                    </span>
                  </div>
                  {(l.decisor_nome || l.decisor_melhor_horario) && (
                    <p className="mt-1 text-xs">Decisor: {l.decisor_nome ?? "—"}{l.decisor_melhor_horario ? ` · melhor horário: ${l.decisor_melhor_horario}` : ""}</p>
                  )}
                  {l.retorno_em && <p className="mt-1 text-xs">Retornar em {formatarData(l.retorno_em)}</p>}
                  {l.proximo_passo && <p className="mt-1"><strong>Próximo passo:</strong> {l.proximo_passo}</p>}
                  {l.comentario && <p className="mt-1 whitespace-pre-line text-texto-suave">{l.comentario}</p>}
                </li>
              ))}
              {(ligacoes ?? []).length === 0 && <li className="px-5 py-3 text-sm text-texto-suave">Nenhuma ligação registrada.</li>}
            </ul>
          </Cartao>

          {fasesComCampos.map(({ fase: f, campos }) => (
            <Cartao key={f.id}>
              <CabecalhoCartao titulo={`Fase: ${f.nome}`} descricao={f.id === negocio.fase_id ? "Fase atual" : "Fase anterior"} />
              <FormCamposFase negocioId={negocio.id} campos={campos} valores={(negocio.campos ?? {}) as Record<string, unknown>} membros={todosMembros} podeEditar={podeEditar} />
            </Cartao>
          ))}
        </div>

        <aside className="space-y-6">
          <AtividadesDoNegocio
            negocioId={negocio.id}
            titulo={`${negocio.titulo}`}
            atividades={(atividades ?? []).map((a) => ({
              id: a.id, tipo_id: a.tipo_id, titulo: a.titulo, inicio: a.inicio, fim: a.fim, local: a.local, link_reuniao: a.link_reuniao,
              negocio_id: a.negocio_id, responsavel_id: a.responsavel_id, stakeholder: a.stakeholder, resumo: a.resumo,
              proximos_passos: a.proximos_passos, participantes: a.atividade_participantes.map((p) => p.membro_id), status: a.status,
            }))}
            tipos={tipos ?? []}
            membros={config.membrosComercial}
            podeEditar={podeEditar}
            usuarioId={usuario.id}
          />

          <AnexosDoNegocio
            negocioId={negocio.id}
            anexos={anexos ?? []}
            nomes={Object.fromEntries(todosMembros.map((m) => [m.id, m.nome]))}
            podeEnviar={podeEditar}
            usuarioId={usuario.id}
            ehDiretor={usuario.ehDiretorDe("comercial")}
          />

          <Cartao>
            <CabecalhoCartao titulo="Contatos da empresa" />
            <ul className="divide-y divide-borda">
              {(contatos ?? []).map((c) => (
                <li key={c.id} className="px-5 py-3 text-sm">
                  <p className="font-semibold">
                    {c.nome} {c.decisor && <Selo tom="destaque" className="ml-1">Decisor</Selo>}
                    {c.telefone_invalido && <Selo tom="perigo" className="ml-1">Telefone inválido</Selo>}
                    {c.nao_contatar && <Selo tom="perigo" className="ml-1">Não contatar</Selo>}
                  </p>
                  {c.cargo && <p className="text-texto-suave">{c.cargo}</p>}
                </li>
              ))}
              {(contatos ?? []).length === 0 && <li className="px-5 py-3 text-sm text-texto-suave">Nenhum contato cadastrado.</li>}
            </ul>
            <div className="border-t border-borda px-5 py-3 text-sm">
              <Link href={`/empresas/${negocio.empresas.id}`} className="font-semibold text-marca hover:text-destaque">Gerenciar contatos</Link>
            </div>
          </Cartao>

          <Cartao>
            <CabecalhoCartao titulo="Histórico" />
            <ol className="space-y-4 px-5 py-4">
              {(historico ?? []).map((h) => (
                <li key={h.id} className="flex gap-3 text-sm">
                  {h.automatico ? (
                    <span className="mt-0.5 inline-flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-superficie-2 text-[10px] font-bold text-texto-suave">auto</span>
                  ) : (
                    <Avatar iniciais={iniciais(nomeMembro(h.autor_id))} nome={nomeMembro(h.autor_id)} />
                  )}
                  <div className="min-w-0">
                    <p>
                      {h.fase_origem_id ? <>{nomeFase(h.fase_origem_id)} → </> : "Criado em "}
                      <strong>{nomeFase(h.fase_destino_id)}</strong>
                    </p>
                    {h.motivos && <p className="text-xs text-perigo">Motivo: {h.motivos.nome}</p>}
                    {h.comentario && <p className="text-xs text-texto-suave">{h.comentario}</p>}
                    <p className="text-xs text-texto-suave">{formatarDataHora(h.created_at)} · {h.automatico ? "Automático" : nomeMembro(h.autor_id)}</p>
                  </div>
                </li>
              ))}
            </ol>
          </Cartao>
        </aside>
      </div>
    </div>
  );
}

function Indicador({ rotulo, valor }: { rotulo: string; valor: string }) {
  return (
    <Cartao className="px-4 py-3">
      <p className="text-[11px] font-semibold uppercase tracking-wide text-texto-suave">{rotulo}</p>
      <p className="mt-0.5 truncate font-titulo text-lg font-bold">{valor}</p>
    </Cartao>
  );
}
