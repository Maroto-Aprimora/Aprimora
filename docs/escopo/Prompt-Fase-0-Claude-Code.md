# Prompt para o Claude Code — Portal Aprimora v2 (Comercial)

> Cole o texto abaixo (da linha "Contexto" até o fim) como primeira mensagem de uma sessão do Claude Code aberta no
> repositório `Maroto-Aprimora/Aprimora`. Antes, coloque o arquivo `Planejamento-Estrategico-Comercial-v2.md` em
> `docs/escopo/` (ou peça ao Claude Code para criá-lo a partir do anexo).

---

## Contexto

Você vai evoluir o Portal Aprimora (Next.js 16 + Supabase, PWA) seguindo dois documentos do repositório:

1. `docs/tecnico/Documentacao-Tecnica-Portal-Aprimora.md`: como o sistema é **hoje** (DT-PA-001).
2. `docs/escopo/Planejamento-Estrategico-Comercial-v2.md`: o que construir e em que ordem (PE-PA-002).

Leia os dois inteiros, mais `docs/DESENVOLVIMENTO.md` e `n8n/README.md`, antes de qualquer mudança. O portal passa a
ser **exclusivo da Diretoria Comercial**. O trabalho segue o roadmap da Seção 9 do PE-PA-002, **uma fase por vez**.
Agora vamos executar **apenas a Fase 0 (Fundação do processo)**.

## Regras do repositório (obrigatórias)

- Código de domínio, tabelas, colunas, mensagens e interface em **português do Brasil**, seguindo os nomes existentes.
- Toda mudança de banco é uma **nova migração** em `supabase/migrations/` (nome com data). Depois, regenere
  `src/lib/supabase/database.types.ts`.
- **RLS em toda tabela nova.** Funções auxiliares no schema `privado`, `security definer` com `set search_path = ''`.
  O app nunca usa `service_role`.
- Regras de negócio críticas ficam em **gatilhos** no banco. Gravações pelo app passam por Server Actions validadas com Zod.
- Configuração em vez de código: listas (resultados de ligação, motivos, origens, passos da cadência) são **tabelas
  editáveis pelo diretor** em `/funil/configuracoes`, com os valores do PE-PA-002 como dados iniciais.
- Uma branch por item abaixo → Pull Request para `main` → o CI (lint, typegen + tsc, build) precisa passar. Não faça
  merge; o Diretor Comercial revisa.
- **Não aplique migrações no projeto Supabase de produção nem apague dados sem minha aprovação explícita.**
- Ao final de cada PR, atualize a DT-PA-001 (seções afetadas, matriz da Seção 18 e histórico).

## Fase 0: entregas (um PR cada, nesta ordem)

**PR 0: Documentação.** Adicionar `docs/escopo/Planejamento-Estrategico-Comercial-v2.md` (se ainda não estiver) e um
link para ele em `docs/DESENVOLVIMENTO.md`. O repositório foi transferido de `AgenciaValkz/Aprimora` para
`Maroto-Aprimora/Aprimora`: troque todas as referências ao nome antigo (DT-PA-001, README, `docs/`, `n8n/`, CI) e
confira se algum fluxo, webhook ou script depende da URL antiga.

**PR 1: Portal exclusivo do Comercial.** O PE-PA-002 diz que as demais diretorias "são deletadas", mas Membros,
Pontuação, Auditoria e Painel geral continuam. **Antes de codar, me apresente um plano** separando (a) o que sai da
interface (seções de Projetos e Marketing, cartões "Em breve", itens de menu) e (b) o que mudaria no banco
(`diretorias`, cargos, RLS). Só execute a parte de banco depois que eu aprovar.

**PR 2: Resultado de ligação (Seção 3.1).**
- Tabela de configuração `resultados_ligacao` (nome, ordem, ativo, fase de destino opcional, se conta como tentativa,
  se exige data de retorno, tipo de tarefa a criar), com os 9 resultados do PE-PA-002 como dados iniciais.
- Tabela `ligacoes` (negocio_id, contato_id, membro_id, inicio, duracao_seg, resultado_id, proximo_passo, retorno_em,
  comentario, origem `manual|agente`, e colunas reservadas para a Fase 2: api4com_id, gravacao_url, transcricao, resumo).
- Gatilho: ao registrar a ligação, aplicar a ação do resultado (mover fase via a mesma regra de `mover_negocio`, marcar
  telefone inválido, criar tarefa).
- Registro rápido da ligação no negócio e no card do funil (celular primeiro).

**PR 3: Motivos e origens (Seções 3.3 e 3.4).** Substituir os dados de `motivos` (perda e desqualificação) e `origens`
pelas listas do PE-PA-002, sem apagar registros referenciados (desativar os antigos). Comentário obrigatório quando o
motivo for "Outro". Motivo "Pediu para não ser contatado" marca `nao_contatar` no contato.

**PR 4: Remarcação e valor por serviço.** Novo valor `remarcada` em `status_atividade` (com a data original
preservada) e coluna `valor` em `negocio_servicos`, com a soma refletida no `valor` do negócio quando preenchida.

**PR 5: Tarefas automáticas e página inicial (Seções 4 e 6).**
- `tarefas` ganha `origem` (`manual|sistema|agente`) e vínculo com negócio/atividade. O sistema cria tarefas para
  qualquer responsável por função `privado` chamada nos gatilhos (o RLS de criação manual continua só para diretor).
- Gatilhos e job diário (pg_cron) criam tarefas para: retorno de ligação, follow-up de Oportunidade, retorno da
  Reciclagem, compromissos do dia e o próximo toque da cadência (tabela configurável `cadencia_passos` com os passos da
  Seção 3.2; e-mails continuam manuais até a Fase 3).
- Toda tarefa criada gera notificação (sino + push, mecanismo existente).
- `/painel` vira **Início (Minhas tarefas)**: a fila do dia de cada membro, com ações em um toque (concluir, registrar
  ligação, abrir o negócio).

**PR 6: Indicadores no banco (Seção 7).**
- `negocio_historico` passa a gravar o responsável da época; o desempenho por membro usa esse campo.
- Mover os cálculos de `src/lib/indicadores.ts` para views/funções SQL, mantendo os números atuais iguais (compare antes
  e depois com dados fictícios).
- Novos indicadores: propostas remarcadas, ticket por solução, pipeline ponderado, % dentro do SLA e destinos de saída,
  motivos de perda, coldcall (por resultado e % que vira diagnóstico).

## Como trabalhar

1. Comece lendo os documentos e me devolva um **plano curto da Fase 0** (arquivos e migrações por PR, riscos, dúvidas).
   Espere meu ok.
2. Execute um PR por vez. Para cada um: descreva o que mudou, como testar e o que atualizou na DT-PA-001.
3. Se algo no PE-PA-002 conflitar com o código atual, pare e pergunte em vez de decidir sozinho.
