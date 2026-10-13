# Roteiro de teste — portão da Fase 2 (Agentes prioritários)

Portão do PE-PA-002: **card enriquecido sem digitação, ligação anotada sozinha e R.I gerada com um clique.**

Este roteiro cresce a cada entrega da Fase 2. Hoje cobre o **A1 Enriquecedor**, o **A4 Analista gerencial**, o **A2 Agente
de ligação**, o **A3 Avaliador** e a tela de **Desempenho individual**.

Os testes automáticos de banco estão em `supabase/testes/fase2_enriquecedor_analista.sql` (fila ao entrar em
Enriquecimento, só campos vazios preenchidos, aprovação do decisor, tarefa "Completar dados", relatório só pelo
diretor, erro na 3ª falha).

## Preparação (uma vez)

1. Fluxos 06 e 07 criados e publicados no n8n pelo conector do n8n em 13/10/2026 (ids `nWA8nWwKhuzuV8ev` e
   `VN5goyMMvOWnYY5z`), com "Tratamento de erros" como Error workflow. Testes reais em 13/10: o Analista gerencial
   escreveu a análise do relatório da semana; o Enriquecedor devolveu segmento, dores e resumo de um lead fictício.
2. Para o Apollo: `APOLLO_API_KEY` no ambiente da VPS e a linha `- APOLLO_API_KEY=${APOLLO_API_KEY:-}` no
   `docker-compose.yml` (já está no repositório). Sem ela, o Enriquecedor segue sem o Apollo.
3. Confira que a VPS tem `GEMINI_API_KEY` no ambiente do n8n (feito em 13/10/2026). Os fluxos 06 e 07 usam o modelo
   `gemini-3.8-flash` fixo no nó do Gemini (o `gemini-2.5-flash` não aceita mais contas novas).
4. No portal, **Config. do funil → Agentes e fila**: ligar **Enriquecedor** e **Analista gerencial**.

## A1 · Enriquecedor

Use uma empresa **real** da região, com o **site** preenchido (o agente lê o site, o Apollo busca pelo domínio e a
BrasilAPI usa o CNPJ do rodapé). Sem site, sobram só o CNPJ (se informado) e o nome.

- [ ] **Novo lead** com nome e cidade: o card cai em Enriquecimento e, em até 2 minutos, em Agentes e fila aparece
      um trabalho do Enriquecedor como **Concluído**.
- [ ] Na empresa, CNPJ, razão social, endereço, telefone e segmento aparecem **sem digitação** (o que já estava
      preenchido não muda). No negócio, o cartão **Enriquecimento** mostra situação, porte, CNAE, resumo e fontes.
- [ ] Na **Caixa de aprovação** do responsável chega "Confirmar decisor e e-mails", com decisor, e-mails e hipóteses
      de dor editáveis.
- [ ] Aprovar: o decisor vira contato (selo Decisor) e contato do negócio; os e-mails entram na empresa; as
      hipóteses aparecem em "Dores identificadas".
- [ ] Se algo faltou (CNPJ, telefone, e-mail ou decisor), nasce a tarefa **Completar dados do lead** para o dia útil
      seguinte, dizendo o que faltou.
- [ ] No negócio, **Enriquecer agora** coloca o card de novo na fila; enquanto está na fila o botão fica
      "Enriquecendo…". Com o agente desligado, o botão some.

## A4 · Analista gerencial

- [ ] **Painel comercial → Relatórios da R.I** (só o diretor vê o botão): **Gerar relatório da R.I** com o período
      padrão (últimos 7 dias).
- [ ] A página do relatório mostra os números na hora (semana × trimestre, por membro, SLA estourado) e "Gerando
      análise…"; em até 1–2 minutos, sem recarregar, aparece a análise (resumo, destaques, pontos de atenção e um
      plano por membro).
- [ ] Os números citados na análise batem com a tabela e com o Painel comercial do mesmo período.
- [ ] Editar o **Texto revisado**, **Marcar como revisado** e **Copiar**: a lista mostra o selo "Revisado".
- [ ] Com o Analista desligado, o relatório sai na hora só com os números e o aviso.
- [ ] Um assessor não acessa `/comercial/relatorios` (volta para o Painel comercial).

## A2 · Agente de ligação e A3 · Avaliador

Testes de banco em `supabase/testes/fase2_agente_ligacao.sql`. Use um lead com o **telefone do contato** (ou da empresa)
igual ao número que você vai discar, e ligue pela API4COM com o seu ramal (o e-mail do ramal é o do portal).

- [ ] Ligação com conversa (15 s ou mais): em até ~7 minutos aparece no negócio, em **Ligações**, como "Aguardando
      confirmação", com resumo, transcrição e link da gravação.
- [ ] Na **Caixa de aprovação** de quem ligou chega "Confirmar resultado da ligação", com o resultado sugerido numa
      lista, datas, próximo passo e dores. Confirmar aplica o resultado como no registro manual (fase, tarefa, agenda) e
      as dores entram no negócio.
- [ ] Ligação sem conversa (não atendeu): chega direto como "Não atendeu", sem gastar IA.
- [ ] Resultado que exige data (ex.: "Decisor indisponível, retornar") sem a data: a confirmação é recusada.
- [ ] A ligação mostra a nota da rubrica (média de 1 a 4); o membro vê só as suas avaliações, o diretor vê todas.

## Desempenho individual e telas novas

- [ ] **Comercial → Desempenho individual**: o membro vê só o seu; o diretor escolhe o membro. Aparecem ligações,
      nota da rubrica, diagnósticos e contratos do período, a nota por critério, a evolução semanal e as ligações com
      resumo, avaliação e transcrição.
- [ ] O plano de melhoria aparece para o membro só depois que o diretor revisa o relatório da R.I.
- [ ] **Config. do funil → Rubrica**: mudar a descrição de um critério vale para as próximas ligações.
- [ ] **Tarefas**: a coluna "Para aprovar" traz os itens dos agentes; clicar abre o card para editar e aprovar.
      Colunas recolhem e ficam recolhidas ao voltar; clicar numa tarefa abre todas as informações e as ações.
- [ ] **Funil**: Kanban e Lista à esquerda; "Procurar cards" e o ícone de filtro à direita. O card abre e fecha
      mostrando responsável, cidade, valor, dias na fase, segmento, serviços, contato, telefone, site e última ligação.

## Depois do roteiro

- [ ] Excluir o lead real de teste, se não for prospectá-lo.
- [ ] Registrar aqui a data da validação e liberar a Fase 3.
