import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { ArrowLeft } from "lucide-react";
import { Cartao, CabecalhoCartao } from "@/components/ui/cartao";
import { Selo } from "@/components/ui/selo";
import { carregarConfiguracaoComercial } from "@/lib/crm-servidor";
import { criarClienteServidor } from "@/lib/supabase/server";
import { formatarData, formatarMoeda } from "@/lib/formatar";
import { obterUsuario } from "@/lib/usuario";
import { Contatos, EditarEmpresa, NovoNegocio } from "./componentes";

export const metadata: Metadata = { title: "Empresa" };

export default async function PaginaEmpresa({ params }: PageProps<"/empresas/[id]">) {
  const { id } = await params;
  const supabase = await criarClienteServidor();
  const [usuario, config, { data: empresa }] = await Promise.all([
    obterUsuario(),
    carregarConfiguracaoComercial(),
    supabase.from("empresas").select("*, contatos(*), negocios(id, titulo, fase_id, responsavel_id, valor, created_at, negocio_participantes(membro_id))").eq("id", id).maybeSingle(),
  ]);
  if (!empresa) notFound();

  const fases = new Map(config.fases.map((f) => [f.id, f]));
  const nomeMembro = new Map(config.membrosComercial.map((m) => [m.id, m.nome]));
  const participa = empresa.negocios.some((n) => n.responsavel_id === usuario.id || n.negocio_participantes.some((p) => p.membro_id === usuario.id));
  const podeEditar = usuario.ehDiretorDe("comercial") || empresa.criado_por === usuario.id || participa;
  const podeCriar = usuario.cargoEm("comercial") !== null;
  const segmento = config.segmentos.find((s) => s.id === empresa.segmento_id)?.nome;

  const linhas: [string, string | null][] = [
    ["Razão social", empresa.razao_social], ["CNPJ", empresa.cnpj], ["Segmento", segmento ?? null], ["Telefone", empresa.telefone],
    ["E-mail principal", empresa.email_principal], ["E-mail secundário", empresa.email_secundario], ["E-mail terciário", empresa.email_terciario],
    ["Site", empresa.site], ["Rede social", empresa.rede_social], ["Endereço", empresa.endereco],
    ["Cidade", empresa.cidade ? `${empresa.cidade}${empresa.uf ? `/${empresa.uf}` : ""}` : null],
  ];

  return (
    <div className="mx-auto max-w-6xl">
      <Link href="/empresas" className="mb-3 inline-flex items-center gap-1 text-sm text-texto-suave hover:text-destaque">
        <ArrowLeft className="h-4 w-4" /> Empresas
      </Link>
      <div className="mb-6 flex flex-wrap items-start justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold">{empresa.nome} {empresa.ficticio && <Selo className="align-middle">fictício</Selo>}</h1>
          <p className="text-sm text-texto-suave">Cadastrada em {formatarData(empresa.created_at)}</p>
        </div>
        <div className="flex gap-2">
          {podeEditar && <EditarEmpresa empresa={empresa} segmentos={config.segmentos} podeExcluir={usuario.ehDiretorDe("comercial")} />}
          {podeCriar && (
            <NovoNegocio
              empresaId={empresa.id}
              titulo={empresa.nome}
              fases={config.fases.filter((f) => f.tipo === "aberta").map((f) => ({ id: f.id, nome: f.nome }))}
              origens={config.origens}
              membros={config.membrosComercial}
            />
          )}
        </div>
      </div>

      <div className="grid gap-6 lg:grid-cols-[1fr_380px]">
        <div className="space-y-6">
          <Cartao>
            <CabecalhoCartao titulo="Negócios" descricao="Histórico de oportunidades com esta empresa." />
            <ul className="divide-y divide-borda">
              {empresa.negocios.map((n) => {
                const f = fases.get(n.fase_id);
                return (
                  <li key={n.id} className="flex flex-wrap items-center justify-between gap-3 px-5 py-3">
                    <div>
                      <Link href={`/negocios/${n.id}`} className="font-semibold hover:text-destaque">{n.titulo}</Link>
                      <p className="text-xs text-texto-suave">
                        Criado em {formatarData(n.created_at)} · {n.responsavel_id ? nomeMembro.get(n.responsavel_id) ?? "—" : "sem responsável"}
                      </p>
                    </div>
                    <div className="flex items-center gap-2">
                      {n.valor != null && <Selo tom="marca">{formatarMoeda(n.valor)}</Selo>}
                      {f && <Selo tom={f.tipo === "ganho" ? "sucesso" : f.tipo === "perda" ? "perigo" : "neutro"}>{f.nome}</Selo>}
                    </div>
                  </li>
                );
              })}
              {empresa.negocios.length === 0 && <li className="px-5 py-4 text-sm text-texto-suave">Nenhum negócio ainda.</li>}
            </ul>
          </Cartao>
          <Contatos empresaId={empresa.id} contatos={empresa.contatos} podeEditar={podeEditar || podeCriar} />
        </div>

        <Cartao>
          <CabecalhoCartao titulo="Dados da empresa" />
          <dl className="divide-y divide-borda text-sm">
            {linhas.map(([rotulo, valor]) => (
              <div key={rotulo} className="grid grid-cols-[130px_1fr] gap-2 px-5 py-2.5">
                <dt className="text-texto-suave">{rotulo}</dt>
                <dd className="break-words">{valor || "—"}</dd>
              </div>
            ))}
            {empresa.observacoes && (
              <div className="px-5 py-3">
                <dt className="text-texto-suave">Observações</dt>
                <dd className="mt-1 whitespace-pre-wrap">{empresa.observacoes}</dd>
              </div>
            )}
          </dl>
        </Cartao>
      </div>
    </div>
  );
}
