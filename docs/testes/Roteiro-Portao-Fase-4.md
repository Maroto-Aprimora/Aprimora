# Roteiro de teste — portão da Fase 4 (Da oportunidade à venda)

Portão do PE-PA-002: **um negócio real vai do diagnóstico ao dossiê dentro do portal.**

Testes automáticos de banco em `supabase/testes/fase4_diagnostico_proposta.sql` (mapa de maturidade, A9, preço mínimo
e máximo, preço final só do diretor virando o valor do negócio, passagem para Projetos).

## Preparação (uma vez)

1. **Config. do funil → Diagnóstico**: conferir as 10 áreas e as 50 perguntas iniciais com o formulário impresso que a
   Aprimora já usa; ajustar textos, desativar ou incluir perguntas. A nota 4 deve ser sempre "estruturado".
2. **Config. do funil → Precificação**: conferir com a planilha atual o valor da hora de consultor e de gerente, as
   margens, o imposto e os fatores (cliente recorrente, prazo, concorrência, entregas fora do padrão, complexidade,
   porte, capacidade). A primeira opção de cada fator é a padrão.
3. **Config. do funil → Agentes**: "Assistente de proposta" e "Passagem para Projetos" ligados. O fluxo 12 (A9) já está
   publicado no n8n.

## Diagnóstico (no celular)

- [ ] No negócio, a faixa "1. Diagnóstico · 2. Precificação · 3. Proposta · 4. Dossiê" aparece abaixo dos indicadores.
- [ ] **Começar diagnóstico**: as áreas abrem uma por vez; notas 1–4 em botões grandes; "Comentário" abre o campo.
- [ ] O "Salvo" aparece sozinho; fechar e abrir de novo mantém as respostas.
- [ ] O mapa de maturidade muda a cada nota (vermelho, laranja, azul, verde).
- [ ] **Concluir** pede confirmação se faltam perguntas; depois mostra "Assistente escrevendo".

## A9 · Proposta

- [ ] Em 1 a 2 minutos chega o aviso "Rascunho de proposta pronto" e a página Proposta mostra resumo, até 3 serviços
      sugeridos com o motivo, escopo e texto da proposta, sem preço e sem markdown.
- [ ] **Marcar nas dores identificadas** marca os serviços no negócio.
- [ ] Editar, **Marcar como revisada**: aparece "Revisada por … em …". Reabrir e concluir o diagnóstico de novo não
      apaga o texto revisado.

## Precificação

- [ ] Fatores, horas e custos mudam o mínimo e o máximo na hora; **Salvar** grava os mesmos valores (a conta oficial é do banco).
- [ ] "Projetos parecidos" mostra ganhos com alguma dor em comum.
- [ ] Assessor não vê o campo de preço final; o diretor registra e o valor do negócio muda; fora da faixa aparece o aviso.

## Passagem para Projetos (A10)

- [ ] Mover o negócio para **Projetos Aprimora**: o diretor de Projetos (ou, sem ele, o diretor comercial) recebe a
      tarefa "Receber projeto · …" de prioridade alta para o próximo dia útil; o responsável recebe o aviso com o link do dossiê.
- [ ] **Dossiê → Salvar em PDF**: o PDF sai sem o menu, com empresa, contatos, dores, mapa de maturidade, proposta,
      precificação, reuniões, ligações, anexos e o caminho no funil.

## Depois do roteiro

- [ ] Registrar aqui a data da validação e liberar a Fase 5.
