import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { Cartao, CabecalhoCartao, TituloPagina } from "@/components/ui/cartao";
import { NOME_AREA } from "@/lib/crm";
import { criarClienteServidor } from "@/lib/supabase/server";
import { obterUsuario } from "@/lib/usuario";
import { hojeBR } from "@/lib/datas";
import { CamposDaFase, LinhaFase, ListaSimples } from "./componentes";
import { ProcessosSeletivos, ReunioesRecorrentes, TiposAtividade } from "./agenda";

export const metadata: Metadata = { title: "Configurações" };

export default async function PaginaConfiguracoes() {
  const usuario = await obterUsuario();
  if (!usuario.ehDiretorDe("comercial")) redirect("/painel");
  const supabase = await criarClienteServidor();
  const { data: funil } = await supabase.from("funis").select("id").eq("diretoria", "comercial").eq("chave", "comercial").single();
  const [
    { data: fases }, { data: campos }, { data: motivos }, { data: origens }, { data: segmentos }, { data: servicos },
    { data: tipos }, { data: reunioes }, { data: processos },
  ] = await Promise.all([
    supabase.from("fases").select("*").eq("funil_id", funil!.id).order("ordem"),
    supabase.from("fase_campos").select("*").order("ordem"),
    supabase.from("motivos").select("*").eq("diretoria", "comercial").order("ordem"),
    supabase.from("origens").select("*").eq("diretoria", "comercial").order("ordem"),
    supabase.from("segmentos").select("*").eq("diretoria", "comercial").order("nome"),
    supabase.from("servicos").select("*").eq("diretoria", "comercial").order("ordem"),
    supabase.from("tipos_atividade").select("*").or("diretoria.is.null,diretoria.eq.comercial").order("ordem"),
    supabase.from("reunioes_recorrentes").select("*").or("diretoria.is.null,diretoria.eq.comercial").order("dia_semana"),
    supabase.from("processos_seletivos").select("id, nome, data").order("data", { ascending: false }),
  ]);
  const listaFases = fases ?? [];

  return (
    <>
      <TituloPagina titulo="Configurações do Comercial" descricao="Ajuste o funil sem precisar de programação. As mudanças valem na hora para toda a diretoria." />

      <Cartao className="mb-6">
        <CabecalhoCartao titulo="Fases do funil" descricao="SLA: dias máximos na fase. “Mover” leva o negócio automaticamente para a fase de destino quando o SLA estoura (verificado todo dia às 8h)." />
        <div className="overflow-x-auto">
          <table className="w-full min-w-[980px] text-sm">
            <thead className="bg-superficie-2 text-left text-xs uppercase tracking-wide text-texto-suave">
              <tr>
                <th className="px-3 py-2">Fase</th><th className="px-3 py-2">SLA (dias)</th><th className="px-3 py-2">Ao estourar</th>
                <th className="px-3 py-2">Destino</th><th className="px-3 py-2">Prob. %</th><th className="px-3 py-2">Rodízio</th>
                <th className="px-3 py-2">Ativa</th><th className="px-3 py-2" />
              </tr>
            </thead>
            <tbody className="divide-y divide-borda">
              {listaFases.map((f) => <LinhaFase key={f.id} fase={f} fases={listaFases.map((x) => ({ id: x.id, nome: x.nome }))} />)}
            </tbody>
          </table>
        </div>
      </Cartao>

      <Cartao className="mb-6">
        <CabecalhoCartao titulo="Campos de cada fase" descricao="Campos obrigatórios precisam estar preenchidos para o negócio avançar para uma fase seguinte." />
        <div className="grid gap-4 p-5 md:grid-cols-2 xl:grid-cols-3">
          {listaFases.filter((f) => f.tipo !== "perda").map((f) => (
            <CamposDaFase key={f.id} fase={{ id: f.id, nome: f.nome }} campos={(campos ?? []).filter((c) => c.fase_id === f.id)} />
          ))}
        </div>
      </Cartao>

      <ReunioesRecorrentes reunioes={reunioes ?? []} tipos={(tipos ?? []).filter((t) => !t.ligada_a_lead)} hoje={hojeBR()} />

      <div className="mb-6 grid gap-6 lg:grid-cols-2">
        <TiposAtividade tipos={tipos ?? []} />
        <ProcessosSeletivos processos={processos ?? []} />
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        <ListaSimples titulo="Motivos de perda" tabela="motivos" extra={{ tipo: "perda" }} itens={(motivos ?? []).filter((m) => m.tipo === "perda")} />
        <ListaSimples titulo="Motivos de desqualificação" tabela="motivos" extra={{ tipo: "desqualificacao" }} itens={(motivos ?? []).filter((m) => m.tipo === "desqualificacao")} />
        <ListaSimples titulo="Origens de lead" tabela="origens" itens={origens ?? []} />
        <ListaSimples titulo="Segmentos" tabela="segmentos" itens={segmentos ?? []} />
        <ListaSimples
          titulo="Serviços (Carta de Serviços)"
          tabela="servicos"
          itens={(servicos ?? []).map((s) => ({ ...s, detalhe: NOME_AREA[s.area] }))}
          semCriar
          className="lg:col-span-2"
        />
      </div>
    </>
  );
}
