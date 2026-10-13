import { redirect } from "next/navigation";

/** A Caixa de aprovação passou a fazer parte de Tarefas (coluna "Para aprovar"). Links antigos continuam valendo. */
export default function PaginaAprovacoes() {
  redirect("/tarefas");
}
