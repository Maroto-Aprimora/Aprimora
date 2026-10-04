import type { Metadata } from "next";
import { Cartao } from "@/components/ui/cartao";
import { FormSenha } from "./form-senha";

export const metadata: Metadata = { title: "Definir senha" };

export default function PaginaDefinirSenha() {
  return (
    <div className="mx-auto max-w-md pt-6">
      <Cartao className="p-6">
        <h1 className="text-xl font-bold">Defina sua senha</h1>
        <p className="mt-1 text-sm text-texto-suave">Use pelo menos 8 caracteres. Você vai usá-la para entrar no portal.</p>
        <FormSenha />
      </Cartao>
    </div>
  );
}
