@AGENTS.md

# Portal Aprimora — notas para agentes

- Leia `docs/escopo/Planejamento-Estrategico-Comercial-v2.md` (PE-PA-002, v2 atual), `docs/tecnico/Documentacao-Tecnica-Portal-Aprimora.md` (DT-PA-001)
  e `docs/DESENVOLVIMENTO.md` para as convenções.
- Interface, nomes de domínio, comentários e mensagens em **português do Brasil**.
- Next.js 16 (App Router, `src/proxy.ts`), Tailwind v4 com tokens em `src/app/globals.css`
  (use `bg-marca`, `text-texto-suave`, `bg-destaque`…, nunca cores soltas).
- Supabase projeto `boxweeufsyaknialzedc`. Segurança no banco (RLS); auxiliares no schema `privado`.
  Toda mudança de banco = nova migração em `supabase/migrations` + tipos regenerados.
- Até a liberação ao time, commits direto na `main` (decisão do Diretor Comercial). Atualize a DT-PA-001 a cada entrega.
