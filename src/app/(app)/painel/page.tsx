import type { Metadata } from "next";
import { Cartao, TituloPagina } from "@/components/ui/cartao";
import { obterUsuario } from "@/lib/usuario";

export const metadata: Metadata = { title: "Painel" };

export default async function PaginaPainel() {
  const usuario = await obterUsuario();
  return (
    <>
      <TituloPagina titulo={`Olá, ${usuario.nome.split(" ")[0]}!`} descricao="Bem-vindo(a) ao Portal Aprimora." />
      <Cartao className="p-6 text-sm text-texto-suave">Os indicadores do funil aparecem aqui a partir da Fase 1.</Cartao>
    </>
  );
}
