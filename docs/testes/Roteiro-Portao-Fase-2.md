# Roteiro de teste — portão da Fase 2 (Agentes prioritários)

Portão do PE-PA-002: **card enriquecido sem digitação, ligação anotada sozinha e R.I gerada com um clique.**

Este roteiro cresce a cada entrega da Fase 2. Hoje cobre o **A1 Enriquecedor** e o **A4 Analista gerencial**; o
Agente de ligação (A2), o Avaliador (A3) e a tela de Desempenho individual entram depois dos testes da API4COM.

Os testes automáticos de banco estão em `supabase/testes/fase2_enriquecedor_analista.sql` (fila ao entrar em
Enriquecimento, só campos vazios preenchidos, aprovação do decisor, tarefa "Completar dados", relatório só pelo
diretor, erro na 3ª falha).

## Preparação (uma vez)

1. Fluxos 06 e 07 criados e publicados no n8n pelo conector do n8n em 13/10/2026 (ids `X4QxQK0Xaa0l153J` e
   `VN5goyMMvOWnYY5z`). Teste real em 13/10: o Analista gerencial escreveu a análise do relatório da semana.
2. Pendente: publicar "APRIMORA | Sistema | Tratamento de erros" (e o Monitor da fila) e escolhê-lo em
   **Settings → Error workflow** dos fluxos 06 e 07.
3. Confira que a VPS tem `GEMINI_API_KEY` no ambiente do n8n (feito em 13/10/2026). Os fluxos 06 e 07 usam o modelo
   `gemini-3.8-flash` fixo no nó do Gemini (o `gemini-2.5-flash` não aceita mais contas novas).
4. No portal, **Config. do funil → Agentes e fila**: ligar **Enriquecedor** e **Analista gerencial**.

## A1 · Enriquecedor

Use uma empresa **real** da região (o agente pesquisa na internet; empresa fictícia não tem o que achar). Cadastre só
com o nome e a cidade.

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

## Depois do roteiro

- [ ] Excluir o lead real de teste, se não for prospectá-lo.
- [ ] Registrar aqui a data da validação (a aprovação do portão espera também A2, A3 e o Desempenho individual).
