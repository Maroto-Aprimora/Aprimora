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
| Agenda | Todos os membros veem; edita quem é responsável/participante ou o diretor; R.G só diretores criam |
| Tarefas | Só o diretor cria, edita e exclui; o responsável só muda o andamento (gatilho `proteger_tarefa`) |
| Notificações | Cada pessoa vê só as suas; só pode marcar como lida |
| Data de entrada | Só o diretor altera (`proteger_membro`) |
| Auditoria | Só diretores leem |

### Regras automáticas do funil (no banco)

| Regra | Onde |
|---|---|
| Entrada de leads → Enriquecimento automaticamente | `fases.auto_mover_para` + gatilho `depois_de_salvar_negocio` |
| Rodízio de responsável ao entrar em E-mail | `fases.distribui_responsavel` + `privado.proximo_do_rodizio` |
| Campos obrigatórios para avançar | `fase_campos.obrigatorio` + gatilho `antes_de_salvar_negocio` |
| Motivo obrigatório nas perdas | `fases.exige_motivo` |
| Trainee não marca ganho | gatilho `antes_de_salvar_negocio` |
| Histórico de toda movimentação | tabela `negocio_historico` (só gatilhos escrevem) |
| SLA (Oportunidade: 15 dias → volta para E-mail) e retorno da Reciclagem | `privado.aplicar_slas()` via pg_cron, todo dia às 8h05 (Brasília) |

### Agenda, tarefas e notificações (Fase 2)

| Regra | Onde |
|---|---|
| Reuniões fixas (R.I, R.G) | tabela `reunioes_recorrentes`; as datas são **calculadas** (`ocorrenciasRecorrentes` em `src/lib/agenda.ts`), então mudar o horário em Configurações vale para as próximas semanas |
| Tipos de atividade (cor, exige confirmação, ligada a lead) | tabela `tipos_atividade`, editável em Configurações |
| "Lead atribuído a você" | gatilho `notificar_responsavel_negocio` (dispara também quando o rodízio escolhe o responsável) |
| SLA a 80% / estourado, tarefa vencendo hoje, R.I/R.G do dia, visita de amanhã sem confirmação (para o diretor) | `privado.gerar_notificacoes_diarias()` via pg_cron às 8h10 (Brasília) |
| Notificação não se repete | `notificacoes (membro_id, chave)` único + `privado.notificar` |
| Transferir carteira de quem sai | `public.transferir_carteira(de, para, diretoria)` (só diretor; registra na auditoria) |
| Membros novos | `membros.data_entrada` ≥ data do último `processos_seletivos` |

### Push no celular (Web Push)

1. Cada notificação inserida dispara o gatilho `enviar_push`, que faz `net.http_post` para `push_url`
   (guardado em `privado.config`) com o cabeçalho `x-push-segredo`.
2. A rota `src/app/api/push/route.ts` confere o segredo (`PUSH_SEGREDO`) e envia para todos os aparelhos da pessoa
   (`push_assinaturas`) usando as chaves VAPID.
3. A pessoa ativa no sino → "Receber notificações neste aparelho". No iPhone é preciso instalar o portal na tela de
   início antes.

Para trocar o segredo ou o domínio: atualize `privado.config` (`push_url`, `push_segredo`) **e** a variável
`PUSH_SEGREDO` na Vercel com o mesmo valor. Novas chaves VAPID: `npx web-push generate-vapid-keys` (quem já ativou
precisa ativar de novo). As pré-visualizações têm proteção da Vercel, então o push só funciona em produção.

## Dados fictícios

`supabase/dados/dados_ficticios.sql` cria 50 empresas e negócios de teste (marcados com `ficticio = true`).
Antes de importar os dados reais do Pipefy, rode `supabase/dados/remover_dados_ficticios.sql`.

## Variáveis de ambiente

| Nome | Onde | Observação |
|---|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | Vercel + `.env.local` | Pública |
| `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | Vercel + `.env.local` | Pública (a segurança vem do RLS) |
| `NEXT_PUBLIC_SITE_URL` | Vercel (produção) | Endereço usado nos links de e-mail |

| `NEXT_PUBLIC_VAPID_PUBLIC_KEY` | Vercel | Pública (chave do Web Push) |
| `VAPID_PRIVATE_KEY` | Vercel (sensível) | Secreta — nunca no repositório |
| `PUSH_SEGREDO` | Vercel (sensível) | Igual a `push_segredo` em `privado.config` |

Nenhuma chave `service_role` é usada pelo app.

## Fluxo de trabalho

- Uma branch por fase (`fase-0-fundacao`, `fase-1-crm`, …) com Pull Request revisado pelo Diretor Comercial
  antes de entrar na `main`.
- A Vercel publica uma pré-visualização de cada branch; a `main` é a produção.
- Mensagens de commit no padrão `feat:`, `fix:`, `docs:`.
