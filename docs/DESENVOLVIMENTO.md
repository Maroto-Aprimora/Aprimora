# Guia de desenvolvimento

## Rodar localmente

```bash
npm install
cp .env.example .env.local   # preencha com os dados do Supabase (Project Settings → API)
npm run dev                  # http://localhost:3000
```

Verificações antes de abrir um Pull Request:

```bash
npm run lint
npx tsc --noEmit
npm run build
```

## Estrutura

| Pasta | Conteúdo |
|---|---|
| `src/app/(auth)` | Telas públicas: entrar, primeiro acesso, esqueci minha senha |
| `src/app/(app)` | Telas logadas (cada pasta é uma página) |
| `src/app/auth/confirmar` | Destino dos links enviados por e-mail |
| `src/components/ui` | Componentes visuais básicos (botão, campos, cartão, diálogo…) |
| `src/components/app` | Componentes do portal (menu, tema…) |
| `src/lib/supabase` | Clientes do Supabase e tipos do banco |
| `src/lib/usuario.ts` | Usuário logado e cargos (use `obterUsuario()` nas páginas) |
| `src/proxy.ts` | Renova a sessão e protege as rotas (no Next.js 16 o antigo `middleware` chama-se `proxy`) |
| `supabase/migrations` | Todas as mudanças do banco, em ordem |
| `supabase/dados` | Dados fictícios para testes e o script para removê-los |
| `docs/` | Escopo, guias e decisões |

## Banco de dados (Supabase)

- **Toda mudança de banco é uma migração** em `supabase/migrations`, com data no nome. Nunca altere o banco de
  produção à mão sem registrar a migração aqui.
- As migrações deste repositório foram aplicadas com o conector do Supabase (MCP). Com a CLI, o equivalente é
  `supabase db push`.
- Depois de mudar o banco, **gere os tipos de novo** e substitua `src/lib/supabase/database.types.ts`
  (`supabase gen types typescript --project-id boxweeufsyaknialzedc`).
- **Segurança fica no banco (RLS)**, não só na tela. Cada tabela tem políticas; as funções auxiliares de
  permissão ficam no schema `privado`, que não é exposto pela API.
- Rode o **Security Advisor** do Supabase depois de cada migração. Ele deve ficar sem alertas.

### Regras de acesso (resumo)

| Quem | Pode |
|---|---|
| Qualquer pessoa | Nada. Só cria conta quem está em `pre_cadastros` |
| Membro ativo | Ler membros, empresas, negócios e configurações de todas as diretorias |
| Diretor de X | Gerir membros, cargos, configurações e todos os registros da diretoria X |
| Assessor / trainee | Criar leads; editar os negócios em que é responsável ou participante |
| Trainee | Não marca ganho e não exclui |

## Variáveis de ambiente

| Nome | Onde | Observação |
|---|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | Vercel + `.env.local` | Pública |
| `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | Vercel + `.env.local` | Pública (a segurança vem do RLS) |
| `NEXT_PUBLIC_SITE_URL` | Vercel (produção) | Endereço usado nos links de e-mail |

Nenhuma chave secreta (`service_role`) é usada pelo app até aqui.

## Fluxo de trabalho

- Uma branch por fase (`fase-0-fundacao`, `fase-1-crm`, …) com Pull Request revisado pelo Diretor Comercial
  antes de entrar na `main`.
- A Vercel publica uma pré-visualização de cada branch; a `main` é a produção.
- Mensagens de commit no padrão `feat:`, `fix:`, `docs:`.
