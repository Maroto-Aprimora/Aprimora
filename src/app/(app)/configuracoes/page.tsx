import { redirect } from "next/navigation";

/** Endereço antigo: as configurações agora ficam em cada área (funil, agenda, metas…). */
export default function PaginaConfiguracoesAntiga() {
  redirect("/funil/configuracoes");
}
