# Guia de desenvolvimento

> **Antes de mudar qualquer coisa, leia:**
> - [`docs/tecnico/Documentacao-Tecnica-Portal-Aprimora.md`](tecnico/Documentacao-Tecnica-Portal-Aprimora.md)
>   (DT-PA-001): como o sistema é hoje. Atualize as seções afetadas, a matriz (Seção 18) e o histórico a cada entrega.
> - [`docs/escopo/Planejamento-Estrategico-Comercial-v2.md`](escopo/Planejamento-Estrategico-Comercial-v2.md)
>   (PE-PA-002): o que construir na v2 (portal exclusivo do Comercial) e em que ordem (roadmap da Seção 9).

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
| `supabase/testes` | Banco local que imita o Supabase, roteiros de teste das migrações e comparação dos indicadores |
| `docs/` | Escopo, guias, decisões e roteiros de teste dos portões (`docs/testes/`) |

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
| Pontuação | Cada um vê a sua; diretores veem todas; só a Vice-Presidência (slug `rh`) lança e cancela |
| Metas | Todos leem; o diretor da diretoria cria, edita e exclui (Metas → Configurações) |

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

### Navegação e configurações (Fase 2b)

- Menu: **Painel, Agenda e Tarefas são gerais**; abaixo vêm seções retráteis por diretoria, na ordem
  Presidência, Vice-Presidência (antigo RH, slug `rh`), Projetos, Comercial e Marketing.
- Cada configuração fica na sua área: funil em `/funil/configuracoes` (botão **Config** ao lado de *Novo lead*),
  agenda em `/agenda/configuracoes`, metas em `/metas/configuracoes`, processos seletivos em Membros.
- `/painel` é o resumo geral (agenda, tarefas, pontuação, projetos e um cartão por diretoria);
  `/comercial` é o painel do Comercial.
- Pontuação (`pontuacoes`): soma dos lançamentos não cancelados, limitada a 0–12, marco em 6. Lançamentos não
  são editados nem apagados (gatilho `proteger_pontuacao`); a pessoa é notificada a cada lançamento.

### Indicadores, metas automáticas e anexos (Fase 3)

- Cálculo no banco desde a v2: `public.indicadores_comerciais(de, ate, responsavel?)` e
  `public.valor_indicador_meta(chave, de, ate, membro?)`, a partir do `negocio_historico`: um negócio "chegou" a uma
  fase no período quando há registro de entrada nela dentro do período (conta uma vez por fase). Por pessoa vale o
  responsável da época (`negocio_historico.responsavel_id`). `src/lib/indicadores.ts` só chama essas funções.
- Ao mudar uma regra de indicador, rode `supabase/testes/comparar_indicadores.sh` (compara com o cálculo da Fase 3).
  Leads = negócios criados no período; contratos/faturamento = `ganho_em` no período.
- Painel comercial (`/comercial`): filtro de período (`?periodo=mes|trimestre|30d|ano|personalizado&de=&ate=`)
  e de responsável (`?resp=`). Exportação em `/comercial/exportar?conteudo=indicadores|negocios&formato=xlsx|csv`.
- Metas: `metas.indicador` aponta para uma chave de `src/lib/indicadores-catalogo.ts`. Com indicador,
  realizado = cálculo automático + `realizado_manual` (ajuste para o que aconteceu antes do portal).
- Anexos: bucket privado `anexos` (até 10 MB por arquivo, 1 GB no plano gratuito), caminho
  `negocios/<negocio_id>/<uuid>-<nome>`, metadados na tabela `anexos`. Download por link assinado de 60 s.
- `supabase/dados/historico_ficticio.sql` gera histórico de teste para os negócios fictícios.

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

### v2 · Fase 0: processo padronizado (PE-PA-002)

| Regra | Onde |
|---|---|
| Resultado de ligação: lista fechada com a ação de cada resultado (fase, motivo, retorno, telefone inválido, compromisso, tarefa) | `resultados_ligacao` (editável em Config. do funil) + gatilho `aplicar_resultado_ligacao` |
| O resultado é aplicado uma vez; trocar exige nova ligação | gatilho `antes_de_salvar_ligacao` (`resultado_aplicado_em`) |
| Card só avança pela ligação (nunca volta) e negócio encerrado não reabre | `aplicar_resultado_ligacao` |
| Tarefas do sistema: uma por regra (`tarefas.chave` única), sempre em dia útil | `privado.criar_tarefa`, `privado.dia_util`, tabela `feriados` |
| Toda tarefa atribuída notifica (sino + push), menos a manual criada para si | gatilho `notificar_tarefa_atribuida` |
| "Outro" exige comentário; "Pediu para não ser contatado" marca `nao_contatar` | `motivos.exige_comentario`, `motivos.marca_nao_contatar` |
| Remarcar: a original fica `remarcada` (com a data original) e nasce outra na data nova | `public.remarcar_atividade` |
| Valor por serviço: com algum valor preenchido, o valor do negócio é a soma | gatilho `somar_valor_servicos` |
| Cadência: D0 = entrada em E-mail; cada toque de `cadencia_passos` vira tarefa no dia (dias corridos, ajustados para dia útil) | `privado.gerar_tarefas_diarias()` via pg_cron às 07h30 (Brasília) |
| D21 sem contato efetivo (ligação cujo resultado não é só tentativa) → Reciclagem com retorno em 90 dias | idem; prazos em `parametros_comercial` |
| Follow-up ao entrar em Oportunidade; "Retomar contato" ao voltar da Reciclagem | gatilho `tarefas_ao_mudar_fase` em `negocio_historico` |
| Tarefa pessoal: qualquer membro cria para si (origem `manual`, `criado_por` = ele) e só ele é responsável | RLS de `tarefas`/`tarefa_responsaveis`, `privado.tarefa_pessoal` |

**Testes de banco locais.** Há um Postgres 16 no ambiente de desenvolvimento. As migrações são testadas antes num
banco local com imitações mínimas do Supabase (`auth.uid()`, `cron`, `net`, `storage`) e com roteiros de dados
fictícios; só depois vão para o projeto `boxweeufsyaknialzedc`. Exclusões em massa (`delete`) não passam pelo conector
MCP: rode-as no SQL Editor (ex.: `20261012130100_motivos_e_origens_v2_apagar_antigos.sql`).

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
| `N8N_SEGREDO` | Vercel (sensível) | Igual a `PORTAL_N8N_SEGREDO` no n8n da VPS (rotas `/api/n8n/*`) |

Nenhuma chave `service_role` é usada pelo app.

## Fluxo de trabalho

- Até o portal ser liberado ao time (fim das fases da v2), os commits vão direto para a `main`, por decisão do
  Diretor Comercial. Cada entrega deve passar em `lint`, `tsc` e `build` antes do push.
- A Vercel publica uma pré-visualização de cada branch; a `main` é a produção.
- Mensagens de commit no padrão `feat:`, `fix:`, `docs:`.
