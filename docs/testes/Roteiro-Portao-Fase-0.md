# Roteiro de teste — portão da Fase 0 (v2)

O PE-PA-002 define o portão da Fase 0 como "resultado de ligação e motivo de perda registrados em todos os casos".
Como o portal só será liberado ao time no fim das fases, o portão vira este roteiro, executado pelo Diretor Comercial
com **dados fictícios** (marcados `ficticio = true`, removíveis com `supabase/dados/remover_dados_ficticios.sql`).

Os testes automáticos de banco que já passaram estão em `supabase/testes/` (resultados de ligação, motivos,
remarcação, valor por serviço, tarefas e cadência, e a comparação dos indicadores com o cálculo anterior).

## Preparação

1. Rodar `supabase/dados/dados_ficticios.sql` e `supabase/dados/historico_ficticio.sql` no SQL Editor do Supabase.
2. Garantir que pelo menos um assessor de teste participa do rodízio (Membros → rodízio).

## Roteiro

Marque cada item ao conferir.

### Resultado de ligação (Seção 3.1)
- [ ] No funil, o ícone de telefone no card abre o registro; os 9 resultados aparecem.
- [ ] "Não atendeu": o card fica na fase; nasce a tarefa "Próxima ligação da cadência" para daqui a 7 dias (dia útil).
- [ ] "Decisor indisponível, retornar" sem data é recusado; com data, o card fica na fase e a tarefa vence na data.
- [ ] "Barrado na secretária" pede nome e horário do decisor, que aparecem na ligação e na tarefa.
- [ ] "Sem interesse" leva para Lead não qualificado com o motivo "Sem interesse declarado".
- [ ] "Interessado, sem data" leva para Oportunidade e cria o follow-up para marcar o diagnóstico.
- [ ] "Diagnóstico agendado" pede data e hora, leva para Diagnóstico agendado, cria o compromisso na agenda e a tarefa
      de briefing na véspera.
- [ ] "Número errado" marca o telefone do contato como inválido (selo nos contatos do negócio).
- [ ] O selo da última ligação aparece no card do funil; o histórico de ligações aparece no negócio.
- [ ] Cada tarefa criada gera notificação no sino (e push, em produção).
- [ ] Em Config. do funil, mudar o destino ou a tarefa de um resultado vale para a próxima ligação.

### Motivos e origens (Seções 3.3 e 3.4)
- [ ] As listas de motivos e origens são as do PE-PA-002.
- [ ] Mover para Projeto não vendido com "Outro" exige comentário.
- [ ] "Pediu para não ser contatado" marca "Não contatar" no contato.

### Remarcação e valor por serviço (Seção 3.4)
- [ ] Na agenda, "Remarcar" uma Apresentação de proposta: a original fica riscada como Remarcada e nasce outra na nova
      data; o painel conta 1 proposta remarcada.
- [ ] No negócio, informar valor em dois serviços: o valor do negócio vira a soma.

### Tarefas e Início (Seções 4 e 6)
- [ ] O Início mostra Atrasadas, Hoje, Próximos 7 dias e Sem prazo; concluir, registrar ligação e abrir o negócio
      funcionam em um toque.
- [ ] Um assessor cria uma tarefa pessoal; não consegue atribuí-la a outra pessoa nem editar tarefa do sistema.
- [ ] No dia útil seguinte, às 7h30, aparecem as tarefas da cadência dos cards em E-mail (D0, D3, D7…).
- [ ] Um card em E-mail há 21 dias sem contato efetivo vai sozinho para a Reciclagem, com retorno em 90 dias.

### Indicadores (Seção 7)
- [ ] O painel comercial mostra coldcall, ticket por solução, pipeline ponderado, % no SLA, destinos de saída e
      motivos por fase.
- [ ] A visão por membro (desempenho e motivos por membro) só aparece para o diretor.
- [ ] Transferir a carteira de um assessor não muda os contratos que ele fechou no período.

## Depois do roteiro

- [ ] Rodar `supabase/dados/remover_dados_ficticios.sql`.
- [ ] Rodar `supabase/migrations/20261012130100_motivos_e_origens_v2_apagar_antigos.sql` no SQL Editor (apaga as
      origens e os motivos antigos, hoje inativos).
- [ ] Registrar aqui a data da validação e liberar a Fase 1.
