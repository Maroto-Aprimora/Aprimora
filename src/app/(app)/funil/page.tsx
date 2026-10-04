import type { Metadata } from "next";
import Link from "next/link";
import { Plus, Settings } from "lucide-react";
import { classeBotao } from "@/components/ui/botao";
import { TituloPagina } from "@/components/ui/cartao";
import { carregarConfiguracaoComercial } from "@/lib/crm-servidor";
import { criarClienteServidor } from "@/lib/supabase/server";
import { obterUsuario } from "@/lib/usuario";
import { FiltrosFunil } from "./filtros";
import { Kanban, type CartaoNegocio } from "./kanban";

export const metadata: Metadata = { title: "Funil" };

const DIAS_ENCERRADOS = 90;

/** Data a partir da qual negócios encerrados (ganhos e perdas) ainda aparecem no quadro. */
function limiteEncerrados() {
  return new Date(Date.now() - DIAS_ENCERRADOS * 86_400_000).toISOString();
}

export default async function PaginaFunil({ searchParams }: PageProps<"/funil">) {
  const filtros = await searchParams;
  const resp = typeof filtros.resp === "string" ? filtros.resp : "";
  const busca = typeof filtros.q === "string" ? filtros.q.trim() : "";
  const origem = typeof filtros.origem === "string" ? filtros.origem : "";
  const segmento = typeof filtros.segmento === "string" ? filtros.segmento : "";

  const [usuario, config, supabase] = await Promise.all([obterUsuario(), carregarConfiguracaoComercial(), criarClienteServidor()]);

  let consulta = supabase
    .from("negocios")
    .select("id, titulo, fase_id, responsavel_id, valor, entrou_na_fase_em, encerrado_em, ficticio, empresas!inner(nome, cidade, nome_normalizado)")
    .eq("funil_id", config.funil.id)
    .or(`encerrado_em.is.null,encerrado_em.gte.${limiteEncerrados()}`)
    .order("entrou_na_fase_em", { ascending: true })
    .limit(1000);
  if (resp === "meus") consulta = consulta.eq("responsavel_id", usuario.id);
  else if (resp === "sem") consulta = consulta.is("responsavel_id", null);
  else if (resp) consulta = consulta.eq("responsavel_id", resp);
  if (origem) consulta = consulta.eq("origem_id", origem);
  if (segmento) consulta = consulta.eq("empresas.segmento_id", segmento);
  if (busca) consulta = consulta.ilike("empresas.nome_normalizado", `%${busca.toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "")}%`);

  const { data } = await consulta;
  const nomes = new Map(config.membrosComercial.map((m) => [m.id, m.nome]));
  const cartoes: CartaoNegocio[] = (data ?? []).map((n) => ({
    id: n.id,
    titulo: n.titulo,
    faseId: n.fase_id,
    responsavel: n.responsavel_id ? nomes.get(n.responsavel_id) ?? "—" : null,
    valor: n.valor,
    entrouNaFaseEm: n.entrou_na_fase_em,
    cidade: n.empresas.cidade,
    ficticio: n.ficticio,
  }));

  return (
    <>
      <TituloPagina
        titulo="Funil comercial"
        descricao="Arraste os cards entre as fases. Negócios ganhos e perdidos aparecem por 90 dias."
        acoes={<>
          {usuario.ehDiretorDe("comercial") && <Link href="/funil/configuracoes" className={classeBotao("secundario")}><Settings className="h-4 w-4" /> Config</Link>}
          <Link href="/empresas/novo" className={classeBotao("destaque")}><Plus className="h-4 w-4" /> Novo lead</Link>
        </>}
      />
      <FiltrosFunil membros={config.membrosComercial} origens={config.origens} segmentos={config.segmentos} />
      <Kanban fases={config.fases} motivos={config.motivos} cartoes={cartoes} />
    </>
  );
}
