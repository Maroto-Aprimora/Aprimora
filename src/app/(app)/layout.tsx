import { MenuLateral } from "@/components/app/menu-lateral";
import { NOME_CARGO } from "@/lib/formatar";
import { obterUsuario } from "@/lib/usuario";

export default async function LayoutApp({ children }: { children: React.ReactNode }) {
  const usuario = await obterUsuario();
  const principal = usuario.cargos.find((c) => c.diretoria === "comercial") ?? usuario.cargos[0];
  const descricao = principal
    ? `${NOME_CARGO[principal.cargo]} · ${principal.diretoria === "comercial" ? "Comercial" : principal.diretoria}`
    : "Sem diretoria";

  return (
    <div className="min-h-screen lg:flex">
      <MenuLateral nome={usuario.nome} descricaoCargo={descricao} ehDiretorComercial={usuario.ehDiretorDe("comercial")} />
      <main className="min-w-0 flex-1 px-4 py-6 sm:px-6 lg:px-8">{children}</main>
    </div>
  );
}
