import type { Metadata } from "next";
import { TituloPagina } from "@/components/ui/cartao";
import { carregarConfiguracaoComercial } from "@/lib/crm-servidor";
import { FormNovoLead } from "./form-novo-lead";

export const metadata: Metadata = { title: "Novo lead" };

export default async function PaginaNovoLead() {
  const config = await carregarConfiguracaoComercial();
  // Leads novos entram nas fases de prospecção e cadência (ou direto em Oportunidade, se já vierem quentes).
  const fasesIniciais = config.fases.filter((f) => ["prospeccao", "cadencia", "oportunidade"].includes(f.macroetapa));
  return (
    <div className="mx-auto max-w-5xl">
      <TituloPagina titulo="Novo lead" descricao="Cadastre a empresa, o decisor e em que ponto do funil o lead entra. Avisamos se a empresa já existir." />
      <FormNovoLead
        segmentos={config.segmentos}
        origens={config.origens}
        membros={config.membrosComercial}
        fases={fasesIniciais.map((f) => ({ id: f.id, nome: f.nome, chave: f.chave }))}
      />
    </div>
  );
}
