import Image from "next/image";

/** Layout das telas de acesso: painel azul com a marca + formulário. */
export default function LayoutAcesso({ children }: { children: React.ReactNode }) {
  return (
    <main className="grid min-h-screen lg:grid-cols-[1.1fr_1fr]">
      <section className="relative hidden overflow-hidden bg-[#24476f] lg:flex lg:flex-col lg:items-center lg:justify-center">
        <div className="absolute right-0 top-0 h-56 w-56 bg-[#97b9c6] opacity-90 [clip-path:polygon(0_0,100%_0,50%_100%)]" />
        <div className="absolute bottom-0 left-0 h-72 w-72 bg-[#e8833a] [clip-path:polygon(0_100%,0_0,100%_100%)]" />
        <Image src="/logo-quadrada.jpg" alt="Aprimora" width={300} height={300} priority />
        <p className="mt-4 font-titulo text-xs tracking-[0.3em] text-[#97b9c6]">SOLUÇÕES EM PRODUÇÃO E GESTÃO EMPRESARIAL</p>
      </section>
      <section className="flex items-center justify-center px-6 py-12">
        <div className="w-full max-w-sm">
          <div className="mb-8 flex items-center gap-3 lg:hidden">
            <Image src="/logo-quadrada.jpg" alt="" width={44} height={44} className="rounded-md" />
            <span className="font-titulo text-lg font-bold text-marca">Portal Aprimora</span>
          </div>
          {children}
        </div>
      </section>
    </main>
  );
}
