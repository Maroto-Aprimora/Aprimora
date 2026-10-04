import { MenuLateral } from "@/components/app/menu-lateral";
import { NOME_CARGO } from "@/lib/formatar";
import { criarClienteServidor } from "@/lib/supabase/server";
import { obterUsuario } from "@/lib/usuario";

export default async function LayoutApp({ children }: { children: React.ReactNode }) {
  const [usuario, supabase] = await Promise.all([obterUsuario(), criarClienteServidor()]);
  const { data: diretorias } = await supabase.from("diretorias").select("slug, nome").order("ordem");
  const principal = usuario.cargos.find((c) => c.diretoria === "comercial") ?? usuario.cargos[0];
  const descricao = principal
    ? `${NOME_CARGO[principal.cargo]} · ${diretorias?.find((d) => d.slug === principal.diretoria)?.nome ?? principal.diretoria}`
    : "Sem diretoria";

  return (
    <div className="min-h-screen lg:flex">
      <MenuLateral
        nome={usuario.nome}
        descricaoCargo={descricao}
        diretorias={diretorias ?? []}
        minhasDiretorias={usuario.cargos.map((c) => c.diretoria)}
        ehDiretor={usuario.ehDiretor}
        diretorDe={usuario.cargos.filter((c) => c.cargo === "diretor").map((c) => c.diretoria)}
      />
      <main className="min-w-0 flex-1 px-4 py-6 sm:px-6 lg:px-8">{children}</main>
    </div>
  );
}
