import type { Metadata } from "next";
import Link from "next/link";
import { Plus } from "lucide-react";
import { classeBotao } from "@/components/ui/botao";
import { Cartao, Vazio } from "@/components/ui/cartao";
import { Avatar, Selo } from "@/components/ui/selo";
import { NOME_MACROETAPA } from "@/lib/crm";
import { iniciais } from "@/lib/formatar";
import { cn } from "@/lib/utils";
import { carregarConfiguracaoComercial } from "@/lib/crm-servidor";
import { criarClienteServidor } from "@/lib/supabase/server";
import { BarraEmpresas } from "./busca";

export const metadata: Metadata = { title: "Empresas e leads" };

const POR_PAGINA = 50;
const LIMITE_KANBAN = 600;

// Colunas do Kanban: a etapa do negócio mais recente de cada empresa
const COLUNAS = [["sem", "Sem negócio"], ...Object.entries(NOME_MACROETAPA)] as [string, string][];
const COR: Record<string, string> = {
  sem: "bg-texto-suave", prospeccao: "bg-azul-claro", cadencia: "bg-marca", oportunidade: "bg-destaque", venda: "bg-marca-forte",
  ganho: "bg-sucesso", pausa: "bg-texto-suave", perda: "bg-perigo",
};

export default async function PaginaEmpresas({ searchParams }: PageProps<"/empresas">) {
  const sp = await searchParams;
  const q = typeof sp.q === "string" ? sp.q.trim() : "";
  const segmento = typeof sp.segmento === "string" ? sp.segmento : "";
  const pagina = Math.max(1, Number(sp.pagina) || 1);
  const ver = sp.ver === "lista" ? "lista" : "kanban";

  const [config, supabase] = await Promise.all([carregarConfiguracaoComercial(), criarClienteServidor()]);
  let consulta = supabase
    .from("empresas")
    .select("id, nome, cidade, uf, cnpj, segmento_id, ficticio, negocios(id, fase_id, responsavel_id, updated_at)", { count: "exact" })
    .order("nome")
    .range(ver === "lista" ? (pagina - 1) * POR_PAGINA : 0, ver === "lista" ? pagina * POR_PAGINA - 1 : LIMITE_KANBAN - 1);
  if (q) {
    const normal = q.toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "");
    const digitos = q.replace(/\D/g, "");
    consulta = digitos.length >= 8
      ? consulta.or(`cnpj_digitos.like.%${digitos}%,telefone_digitos.like.%${digitos}%`)
      : consulta.ilike("nome_normalizado", `%${normal}%`);
  }
  if (segmento) consulta = consulta.eq("segmento_id", segmento);
  const { data: empresas, count } = await consulta;

  const nomeFase = new Map(config.fases.map((f) => [f.id, f]));
  const nomeMembro = new Map(config.membrosComercial.map((m) => [m.id, m.nome]));
  const nomeSegmento = new Map(config.segmentos.map((s) => [s.id, s.nome]));
  const totalPaginas = Math.max(1, Math.ceil((count ?? 0) / POR_PAGINA));

  const recenteDe = (e: NonNullable<typeof empresas>[number]) => [...e.negocios].sort((a, b) => b.updated_at.localeCompare(a.updated_at))[0];
  const colunaDe = (e: NonNullable<typeof empresas>[number]) => {
    const r = recenteDe(e);
    return r ? nomeFase.get(r.fase_id)?.macroetapa ?? "sem" : "sem";
  };

  return (
    <>
      <h1 className="mb-1 text-2xl font-bold text-texto">Empresas e leads</h1>
      <p className="mb-3 max-w-2xl text-sm text-texto-suave">Toda a base da diretoria. Antes de prospectar, busque aqui para ver se a empresa já foi contatada e por quem.</p>
      <BarraEmpresas segmentos={config.segmentos}
        acoes={<Link href="/empresas/novo" className={classeBotao("destaque", "sm")}><Plus className="h-4 w-4" /> Novo lead</Link>} />
      {ver === "kanban" ? (
        (empresas ?? []).length === 0 ? (
          <Cartao><Vazio titulo="Nenhuma empresa encontrada" descricao={q ? "Ela ainda não foi cadastrada. Que tal cadastrar agora?" : undefined}
            acao={<Link href="/empresas/novo" className={classeBotao()}>Cadastrar lead</Link>} /></Cartao>
        ) : (
          <>
            <div className="-mx-4 overflow-x-auto px-4 pb-4 sm:-mx-6 sm:px-6 lg:-mx-8 lg:px-8">
              <div className="flex min-w-max gap-3">
                {COLUNAS.map(([chave, titulo]) => {
                  const daColuna = (empresas ?? []).filter((e) => colunaDe(e) === chave);
                  return (
                    <section key={chave} className="flex w-64 shrink-0 flex-col rounded-xl border border-borda bg-superficie-2/60">
                      <header className="rounded-t-xl border-b border-borda bg-superficie px-3 pb-2 pt-0">
                        <div className={cn("-mx-3 mb-2 h-1 rounded-t-xl", COR[chave])} />
                        <div className="flex items-baseline justify-between gap-2">
                          <h2 className="truncate text-sm font-bold">{titulo}</h2>
                          <span className="text-xs font-semibold text-texto-suave">{daColuna.length}</span>
                        </div>
                      </header>
                      <div className="flex max-h-[calc(100vh-280px)] min-h-24 flex-col gap-2 overflow-y-auto p-2">
                        {daColuna.map((e) => {
                          const r = recenteDe(e);
                          const resp = r?.responsavel_id ? nomeMembro.get(r.responsavel_id) : undefined;
                          return (
                            <Link key={e.id} href={`/empresas/${e.id}`}
                              className="flex items-center gap-2.5 rounded-xl border border-borda bg-superficie p-2.5 shadow-sm transition hover:border-marca/40 hover:shadow-md">
                              <span className={cn("flex h-9 w-9 shrink-0 items-center justify-center rounded-lg text-xs font-bold text-white", COR[chave])}>{iniciais(e.nome)}</span>
                              <span className="min-w-0 flex-1">
                                <span className="block truncate text-sm font-semibold">{e.nome}</span>
                                <span className="block truncate text-xs text-texto-suave">
                                  {[e.cidade, e.segmento_id ? nomeSegmento.get(e.segmento_id) : null].filter(Boolean).join(" · ") || "—"}
                                </span>
                                {r && <Selo className="mt-1">{nomeFase.get(r.fase_id)?.nome}</Selo>}
                                {e.ficticio && <Selo className="ml-1 mt-1 opacity-70">fictício</Selo>}
                              </span>
                              {resp && <Avatar iniciais={iniciais(resp)} nome={resp} className="h-6 w-6 text-[10px]" />}
                            </Link>
                          );
                        })}
                        {daColuna.length === 0 && <p className="py-5 text-center text-xs text-texto-suave">Nenhuma empresa</p>}
                      </div>
                    </section>
                  );
                })}
              </div>
            </div>
            {(count ?? 0) > LIMITE_KANBAN && (
              <p className="text-sm text-texto-suave">Mostrando {LIMITE_KANBAN} de {count} empresas. Use a busca, o filtro ou a Lista para ver as demais.</p>
            )}
          </>
        )
      ) : (
      <>
      <Cartao className="overflow-hidden">
        {(empresas ?? []).length === 0 ? (
          <Vazio titulo="Nenhuma empresa encontrada" descricao={q ? "Ela ainda não foi cadastrada. Que tal cadastrar agora?" : undefined}
            acao={<Link href="/empresas/novo" className={classeBotao()}>Cadastrar lead</Link>} />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="bg-superficie-2 text-left text-xs uppercase tracking-wide text-texto-suave">
                <tr>
                  <th className="px-4 py-3">Empresa</th>
                  <th className="px-4 py-3">Segmento</th>
                  <th className="px-4 py-3">Cidade</th>
                  <th className="px-4 py-3">Negócio mais recente</th>
                  <th className="px-4 py-3">Responsável</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-borda">
                {(empresas ?? []).map((e) => {
                  const recente = [...e.negocios].sort((a, b) => b.updated_at.localeCompare(a.updated_at))[0];
                  const fase = recente ? nomeFase.get(recente.fase_id) : undefined;
                  return (
                    <tr key={e.id} className="hover:bg-superficie-2/60">
                      <td className="px-4 py-3">
                        <Link href={`/empresas/${e.id}`} className="font-semibold hover:text-destaque">{e.nome}</Link>
                        {e.ficticio && <Selo className="ml-2 opacity-70">fictício</Selo>}
                        {e.cnpj && <p className="text-xs text-texto-suave">{e.cnpj}</p>}
                      </td>
                      <td className="px-4 py-3 text-texto-suave">{e.segmento_id ? nomeSegmento.get(e.segmento_id) : "—"}</td>
                      <td className="px-4 py-3 text-texto-suave">{e.cidade ? `${e.cidade}${e.uf ? `/${e.uf}` : ""}` : "—"}</td>
                      <td className="px-4 py-3">
                        {fase ? (
                          <Link href={`/negocios/${recente!.id}`}>
                            <Selo tom={fase.tipo === "ganho" ? "sucesso" : fase.tipo === "perda" ? "perigo" : "marca"}>{fase.nome}</Selo>
                          </Link>
                        ) : "—"}
                        {e.negocios.length > 1 && <span className="ml-1 text-xs text-texto-suave">+{e.negocios.length - 1}</span>}
                      </td>
                      <td className="px-4 py-3 text-texto-suave">{recente?.responsavel_id ? nomeMembro.get(recente.responsavel_id) ?? "—" : "—"}</td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </Cartao>
      <div className="mt-4 flex items-center justify-between text-sm text-texto-suave">
        <span>{count ?? 0} empresas</span>
        <div className="flex gap-2">
          {pagina > 1 && <Link className={classeBotao("secundario", "sm")} href={{ query: { ...sp, pagina: pagina - 1 } }}>Anterior</Link>}
          <span className="px-2 py-1">Página {pagina} de {totalPaginas}</span>
          {pagina < totalPaginas && <Link className={classeBotao("secundario", "sm")} href={{ query: { ...sp, pagina: pagina + 1 } }}>Próxima</Link>}
        </div>
      </div>
      </>
      )}
    </>
  );
}
