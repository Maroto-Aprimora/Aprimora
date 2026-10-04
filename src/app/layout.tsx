import type { Metadata, Viewport } from "next";
import { Montserrat, Open_Sans } from "next/font/google";
import { Toaster } from "sonner";
import { ProvedorTema } from "@/components/app/provedor-tema";
import "./globals.css";

const titulo = Montserrat({ variable: "--fonte-titulo", subsets: ["latin"] });
const texto = Open_Sans({ variable: "--fonte-texto", subsets: ["latin"] });

export const metadata: Metadata = {
  title: { default: "Portal Aprimora", template: "%s · Portal Aprimora" },
  description: "Portal interno da Aprimora — Empresa Júnior de Engenharia de Produção da UTFPR Londrina.",
  robots: { index: false, follow: false },
};

export const viewport: Viewport = {
  themeColor: "#24476f",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="pt-BR" suppressHydrationWarning className={`${titulo.variable} ${texto.variable} h-full antialiased`}>
      <body className="min-h-full font-sans">
        <ProvedorTema>
          {children}
          <Toaster richColors position="top-right" />
        </ProvedorTema>
      </body>
    </html>
  );
}
