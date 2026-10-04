import type { NextRequest } from "next/server";
import { atualizarSessao } from "@/lib/supabase/sessao";

export async function proxy(request: NextRequest) {
  return atualizarSessao(request);
}

export const config = {
  // Tudo, exceto arquivos estáticos e imagens.
  matcher: ["/((?!_next/static|_next/image|favicon.ico|icon.png|apple-icon.png|sw.js|manifest.webmanifest|.*\\.(?:svg|png|jpg|jpeg|gif|webp|ico)$).*)"],
};
