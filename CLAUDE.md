@AGENTS.md

# Portal Aprimora — notas para agentes

- Leia `docs/escopo/Escopo-Portal-Aprimora.pdf` (ou `docs/escopo/fonte/conteudo.js`) para entender o produto
  e `docs/DESENVOLVIMENTO.md` para as convenções.
- Interface, nomes de domínio, comentários e mensagens em **português do Brasil**.
- Next.js 16 (App Router, `src/proxy.ts`), Tailwind v4 com tokens em `src/app/globals.css`
  (use `bg-marca`, `text-texto-suave`, `bg-destaque`…, nunca cores soltas).
- Supabase projeto `boxweeufsyaknialzedc`. Segurança no banco (RLS); auxiliares no schema `privado`.
  Toda mudança de banco = nova migração em `supabase/migrations` + tipos regenerados.
- Uma branch por fase, PR para a `main`. Não publicar na Vercel automaticamente.
