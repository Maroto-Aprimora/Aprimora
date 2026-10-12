# Planejamento Estratégico — Portal Aprimora Comercial

> **PE-PA-002.** Versão em Markdown do PDF `Planejamento-Estrategico-Comercial-v2.pdf` (mesma pasta). As figuras do
> PDF (arquitetura e roadmap) foram transcritas em texto. As decisões tomadas depois do documento estão na seção
> "Decisões registradas" no fim.

Oct 9, 2026 · @Fabricio

## 1. Visão e objetivos

O Portal Aprimora deixa de ser um portal de toda a EJ e passa a ser **o sistema de trabalho exclusivo da Diretoria Comercial**, construído em volta do CRM (funil de vendas). As demais diretorias são deletadas. O que já está em produção (funil, empresas, negócio, agenda, tarefas, metas, push) é a base, não é refeito.

**Problema.** O time tem 7 pessoas (1 diretor e 6 assessores) com 10 a 15 h semanais cada. Boa parte desse tempo vai para tarefas de baixo valor: preencher cards, anotar ligações, montar e-mails, lembrar follow-ups e montar a R.I. Ao mesmo tempo, o maior gargalo do Comercial é a **falta de leads**.

**Objetivos da v2:**

1. **Devolver horas ao time.** Os agentes fazem o trabalho operacional (enriquecimento, anotação de ligação, e-mails, agenda) e o membro só confirma.
2. **Padronizar o processo.** Resultado de ligação, cadência e motivos de perda passam a ser campos fechados, não texto livre.
3. **Facilitar a gestão.** O diretor responde as perguntas da semana em segundos e prepara a R.I com um clique.
4. **Gerar informação nova.** Transcrição e avaliação das coldcalls, desempenho individual, análise semanal do ICP e motivos de perda.
5. **Funcionar no bolso.** Site e PWA, com cada membro vendo suas próprias tarefas e notificações.

**Princípio de desenho:** o agente prepara, o humano decide. Nada sai para o lead sem aprovação de um membro, e o preço final é sempre do diretor comercial.

## 2. Escopo

A v2 cobre o ciclo comercial inteiro, da entrada do lead até a passagem do projeto vendido para a Diretoria de Projetos.

| Dentro da v2 | Fora da v2 (decidido) |
| --- | --- |
| Funil, empresas, negócio e anexos (já existem) | Telas de Projetos, Marketing e Presidência |
| Processo padronizado: resultado de ligação, cadência, motivos de perda | Extração de leads no LinkedIn |
| Página inicial com as tarefas e lembretes de cada membro, com push | WhatsApp (continua pessoal, fora do sistema) |
| 12 agentes e automações (Seção 5) | Aviso automático ao Financeiro |
| Desempenho individual (membro vê o seu; diretor vê todos) | CSAT e pós-venda (são da Presidência) |
| Diagnóstico e precificação digitais | Meta de volume de leads (definir depois) |
| Relatório da R.I e análise semanal do ICP | Importação do Pipefy antes do fim (fica para a última fase) |
| Dossiê de passagem para Projetos |  |

Permanecem como estão, sem evolução: Membros, Pontuação, Auditoria e o Painel geral.

## 3. Processo comercial padronizado

Três listas fechadas viram campos obrigatórios no banco. Sem elas não há indicador de coldcall, motivo de perda nem agente confiável. As listas ficam editáveis em Configurações do funil, como já acontece com origens e motivos.

### 3.1 Resultado de ligação

Toda ligação gera um registro com data, duração, resultado e próximo passo. O Agente de ligação sugere o resultado a partir da transcrição e o membro confirma.

| Resultado | O que acontece com o card | Tarefa criada para o responsável |
| --- | --- | --- |
| Não atendeu | Fica na fase; conta como tentativa | Próximo toque da cadência |
| Caixa postal | Fica na fase; conta como tentativa | Próximo toque da cadência |
| Barrado na secretária | Fica na fase; registra nome e melhor horário do decisor | Ligar no horário indicado |
| Decisor indisponível, retornar | Fica na fase com data de retorno | Ligar na data combinada |
| Pediu e-mail | Fica na fase | Aprovar e-mail com material (gerado pelo Redator) |
| Sem interesse | Vai para Lead não qualificado, motivo “Sem interesse declarado” | — |
| Interessado, sem data | Vai para Oportunidade (SLA de 15 dias já existe) | Follow-up para marcar diagnóstico |
| Diagnóstico agendado | Vai para Diagnóstico agendado | Compromisso na agenda + briefing |
| Número errado | Fica na fase; marca o telefone como inválido | Corrigir telefone (Enriquecedor tenta antes) |

### 3.2 Cadência padrão

Mantém o ritmo atual de **uma ligação por semana, por duas semanas**. A padronização define o dia e o canal de cada toque e intercala e-mails curtos, como é prática no mercado B2B: o e-mail aquece a ligação e a ligação dá contexto ao e-mail. A contagem pausa quando o lead responde.

| Dia | Fase no funil | Toque | Quem faz |
| --- | --- | --- | --- |
| D0 | E-mail | E-mail 1: apresentação personalizada | Redator prepara, membro aprova |
| D3 | E-mail | E-mail 2: follow-up curto, com um caso ou dado do segmento | Redator prepara, membro aprova |
| D7 | Coldcall (semana 1) | Ligação 1 | Membro liga; Agente de ligação anota |
| D8 | Coldcall (semana 1) | E-mail 3: “tentei falar com você”, só se não houve contato | Redator prepara, membro aprova |
| D14 | Coldcall (semana 2) | Ligação 2 | Membro liga; Agente de ligação anota |
| D15 | Coldcall (semana 2) | E-mail 4: encerramento cordial, deixando a porta aberta | Redator prepara, membro aprova |
| D21 | Reciclagem | Sem resposta: vai para Reciclagem com retorno em 90 dias | Automático (SLA) |

Os dias, os modelos e o prazo de retorno ficam configuráveis. Os modelos atuais de e-mail e o roteiro de coldcall ainda precisam ser enviados para virar a base do Redator.

### 3.3 Motivos de perda e desqualificação

O banco já exige motivo nas fases de perda. A v2 substitui a lista atual por estas duas e torna o comentário obrigatório quando o motivo for “Outro”.

| Projeto não vendido (perda) | Lead não qualificado (desqualificação) |
| --- | --- |
| Preço acima do orçamento | Sem interesse declarado |
| Momento inadequado, adiou | Fora do perfil (porte ou segmento) |
| Sem orçamento | Empresa fechada ou inativa |
| Não percebeu valor | Contato inválido, sem alternativa |
| Escolheu outra consultoria | Pediu para não ser contatado (marca “não contatar”) |
| Parou de responder | Atendido recentemente pela Aprimora |
| Resolveu internamente | Outro (comentário obrigatório) |
| Outro (comentário obrigatório) |  |

### 3.4 Outros ajustes de processo

- **Proposta remarcada:** novo status `remarcada` na atividade, com a data nova. Isso alimenta o indicador de propostas remarcadas.
- **Valor por serviço:** cada serviço vendido no negócio recebe um valor próprio, para calcular o ticket médio por solução.
- **Remetente único:** os e-mails saem da conta pessoal do diretor na fase de testes e depois da conta comercial@ (Google Workspace).
- **Origens do lead:** a lista passa a ser Extração (Google), Apollo, Indicação, Evento, Instagram, LinkedIn (página, orgânico), Site, Tráfego pago, Pós-venda, Revenda e Manual.

## 4. Mapa de atividades e níveis de automação

Das 34 atividades mapeadas, só quatro continuam humanas: ligar, combinar a data do diagnóstico, conduzir o diagnóstico e decidir o preço. As demais passam a ser feitas ou preparadas pelo sistema.

**Níveis:** N0 humano · N1 assistido (a IA sugere, o membro faz) · N2 agente com aprovação (o agente faz, o membro aprova com um clique) · N3 autônomo (o agente faz e registra). **Todo lembrete vira tarefa na página inicial do responsável e notificação push.**

| # | Etapa | Atividade | Hoje | Nível | Agente ou automação |
| --- | --- | --- | --- | --- | --- |
| P1 | Prospecção | Extrair leads em massa (Google, Apollo) | Manual | N2 (diretor aprova o lote) | Prospector |
| P2 | Prospecção | Checar duplicidade | Automático | N3 | Já existe |
| P3 | Prospecção | Distribuir o lead (rodízio) | Automático | N3 | Já existe |
| P4 | Prospecção | Preencher CNPJ, endereço, segmento e telefone | Manual, maior dor do time | N3 | Enriquecedor |
| P5 | Prospecção | Achar o decisor e os e-mails | Manual | N2 | Enriquecedor |
| P6 | Prospecção | Levantar possíveis dores | Opcional | N1 | Enriquecedor |
| P7 | Prospecção | Medir aderência ao ICP | Não existe | N3 | Analista de ICP |
| P8 | Prospecção | Cadastrar lead de evento ou indicação | Manual | N1 (cadastro rápido no celular) | Enriquecedor |
| C1 | Cadência | Personalizar e-mail | Manual | N2 (membro aprova) | Redator |
| C2 | Cadência | Enviar e-mails e follow-ups | Manual, conta do diretor | N2 (membro aprova) | Redator |
| C3 | Cadência | Ler e classificar respostas | Manual | N2 | Monitor de respostas |
| C4 | Cadência | Decidir quem ligar hoje | Manual | N3 | Organizador do dia |
| C5 | Cadência | Fazer a ligação | Humano | N0 | — |
| C6 | Cadência | Anotar data, resposta e dores | Manual | N3 | Agente de ligação |
| C7 | Cadência | Registrar o resultado e mover o card | Sem padrão | N2 (membro confirma) | Agente de ligação |
| C8 | Cadência | Avaliar a ligação | Diretor, só no início | N3 (aba Desempenho individual) | Avaliador de ligações |
| C9 | Cadência | Retornar futuro e Reciclagem | SLA automático | N3 + tarefa de retorno | Já existe |
| O1 | Oportunidade | Combinar a data do diagnóstico | Humano | N0 | — |
| O2 | Oportunidade | Lançar o diagnóstico na agenda | Manual | N3 | Agendador |
| O3 | Oportunidade | Escolher os 2 acompanhantes | Manual | N1 (sugere por agenda livre) | Agendador |
| O4 | Oportunidade | Confirmar com o lead na véspera | Indefinido | N2 | Agendador |
| O5 | Oportunidade | Briefing pré-diagnóstico | Não existe | N3 | Agendador |
| O6 | Diagnóstico | Aplicar o checklist | Papel | N0, em formulário digital | — |
| O7 | Diagnóstico | Resumir o diagnóstico no card | Indefinido | N3 | Assistente de proposta |
| E1 | Proposta | Elaborar o escopo com Projetos | Humano | N1 (rascunho) | Assistente de proposta |
| E2 | Proposta | Precificar | Planilha | N1 (pré-preenche); decisão N0 do diretor | Precificação digital |
| E3 | Proposta | Montar o documento da proposta | Indefinido | N2 | Assistente de proposta |
| E4 | Proposta | Registrar apresentação e remarcação | Não registrada | N3 | Regra no banco |
| E5 | Proposta | Follow-up pós-proposta | Indefinido | N2 + tarefa | Redator |
| E6 | Proposta | Registrar motivo de perda | Não registrado | N0 obrigatório + N1 sugestão | Regra no banco |
| G1 | Pós-ganho | Dossiê de passagem para Projetos | Não existe | N3 | Passagem |
| M1 | Gestão | Relatório da R.I | Diretor monta toda semana | N3, **sob demanda (botão do diretor)** | Analista gerencial |
| M2 | Gestão | Desempenho e plano de melhoria por membro | Informal | N3 painel; N2 plano | Analista gerencial |
| M3 | Gestão | Análise do ICP | Não existe | N3, **toda sexta de manhã** | Analista de ICP |

## 5. Agentes de IA

São 12 agentes. **Os três prioritários são o Enriquecedor, o Agente de ligação (com o Avaliador) e o Analista gerencial.** Três deles (A7, A10 e A12) são só regras no banco ou no n8n e não gastam IA, e outros três usam IA só no texto final, o que preserva a cota gratuita do Gemini para o que precisa de linguagem.

| # | Agente | Prioridade | Tipo | Gatilho | O que entrega | Quem aprova |
| --- | --- | --- | --- | --- | --- | --- |
| A1 | Enriquecedor | 1 | IA + APIs públicas | Card entra em Enriquecimento | CNPJ, razão social, endereço, segmento e telefone (dados públicos de CNPJ e site do lead); decisor e e-mails sugeridos; hipóteses de dor; tarefa “completar dados” com o que faltar | Dados públicos: ninguém. Decisor e e-mail: o responsável |
| A2 | Agente de ligação | 1 | IA (áudio) | Fim de uma ligação na API4COM | Transcrição, resumo, resultado sugerido (lista 3.1), dores marcadas, próximo passo e data; gravação no Drive | O responsável confirma resultado e fase |
| A3 | Avaliador de ligações | 1 | IA | Depois do A2 | Nota por critério da rubrica (abaixo) e comentários, na aba Desempenho individual | Ninguém (só leitura) |
| A4 | Analista gerencial | 1 | Regra + IA | **Botão do diretor** | Relatório da R.I: indicadores gerais e individuais, travados por SLA, destaques e pontos de atenção; rascunho de plano de melhoria por membro | Diretor revisa o plano antes de compartilhar |
| A5 | Redator de cadência | 2 | IA | Cada toque de e-mail da cadência (3.2) e follow-up pós-proposta | E-mail personalizado a partir do modelo e dos dados do lead, numa tarefa “aprovar e-mail” | Qualquer membro aprova os e-mails dos seus leads; o diretor aprova qualquer um |
| A6 | Monitor de respostas | 2 | IA | Resposta chega na caixa de e-mail | Classificação (interessado, retornar depois, recusa, ausência, outro), resumo e fase sugerida; pausa a cadência | O responsável confirma |
| A7 | Organizador do dia | 2 | Regra | Todo dia às 07h30 | Fila de ligações e tarefas do dia na página inicial + push | — |
| A8 | Agendador | 3 | Regra + IA | Resultado “Diagnóstico agendado” ou e-mail com data | Compromisso na agenda e no Google Calendar, sugestão de acompanhantes, e-mail de confirmação na véspera, briefing de 1 página | O responsável aprova a confirmação |
| A9 | Assistente de proposta | 3 | IA | Checklist de diagnóstico salvo | Resumo do diagnóstico, mapa de maturidade por área, serviços sugeridos, rascunho de escopo e proposta | O responsável e Projetos |
| A10 | Passagem para Projetos | 3 | Regra | Card entra em Projetos Aprimora | Dossiê em PDF com tudo do card (dados, contatos, ligações, diagnóstico, proposta, anexos) e tarefa para a Diretoria de Projetos | — |
| A11 | Analista de ICP | 4 | Regra + IA | **Toda sexta às 08h** | Conversão por segmento, porte, cidade e origem; recomendação de foco da semana; score de aderência de cada lead | Diretor lê |
| A12 | Prospector | 4 | APIs + regra | Sob demanda, com filtros (segmento, cidade, porte) | Lote de leads do Google Maps ou Apollo, já sem duplicados | Diretor aprova o lote |

### 5.1 Rubrica do Avaliador de ligações

Cada critério recebe nota de 1 a 4, a mesma escala do checklist de diagnóstico. A rubrica fica configurável pelo diretor.

1. **Abertura:** apresentação clara da Aprimora e do motivo da ligação nos primeiros 40 segundos.
2. **Decisor:** chegou ou tentou chegar a quem decide.
3. **Descoberta:** perguntas sobre a operação e as dores do lead.
4. **Proposta de valor:** ligou a dor do lead a um serviço da Aprimora.
5. **Objeções:** respondeu sem encerrar a conversa.
6. **Próximo passo:** saiu com uma data, um e-mail ou um retorno combinado.
7. **Escuta:** proporção de fala entre membro e lead.

### 5.2 Diagnóstico e precificação digitais

- **Checklist de diagnóstico:** o formulário impresso vira tela no PWA, para usar no celular dentro da fábrica. São 10 áreas (Mapeamento de processos, Pesquisa de mercado, Gestão de custos, Planejamento estratégico, Cronoanálise, Gestão de estoque, Layout, PCP, Desperdício e 5S), com cerca de 5 perguntas cada, nota de 1 a 4 e comentário. Fotos e áudio são opcionais. A média por área gera o mapa de maturidade que o A9 usa para sugerir serviços.
- **Precificação:** a planilha vira uma tela ligada ao negócio, com as mesmas fórmulas: fatores multiplicativos (cliente recorrente, prazo, concorrência, entregas fora do padrão, complexidade, porte, capacidade operacional), horas de consultores e gerentes, custos do projeto, margem mínima e imposto. A tela calcula o preço mínimo e o máximo e mostra o preço de projetos parecidos já vendidos. **O diretor comercial registra o preço final**, que vira o `valor` do negócio.

## 6. Módulos e telas

O menu passa a ter o Comercial como centro. São quatro telas novas e cinco ajustes em telas que já existem.

| Tela | Situação | Quem vê | O que muda |
| --- | --- | --- | --- |
| **Início (Minhas tarefas)** | Ajuste em `/painel` | Cada membro, só o seu | Fila do dia (ligações, follow-ups, e-mails para aprovar, compromissos, retornos), com ações em um toque. Tarefas criadas pelo sistema e pelos agentes, além das do diretor. Cada uma vira push |
| Funil | Ajuste em `/funil` | Todos | Selo de resultado da última ligação, etapa da cadência e score de ICP no card |
| Negócio | Ajuste em `/negocios/[id]` | Todos | Linha do tempo única: ligações (áudio, transcrição, resumo), e-mails, respostas, diagnóstico, precificação, proposta. Botão do dossiê |
| **Caixa de aprovação** | Nova | Cada membro; diretor vê todas | E-mails e sugestões de agentes esperando aprovação, com editar, aprovar ou descartar |
| **Desempenho individual** | Nova | Membro vê o seu; diretor vê todos | Indicadores do membro, notas da rubrica ao longo do tempo, transcrições e avaliações das ligações, plano de melhoria (depois que o diretor libera) |
| **Diagnóstico** | Nova | Todos (edita quem participa) | Checklist digital, mapa de maturidade, fotos e áudio |
| **Precificação** | Nova | Membros; preço final só o diretor | Calculadora ligada ao negócio |
| Painel comercial | Ajuste em `/comercial` | Todos; visão por membro só o diretor | Novos indicadores (Seção 7), botão “Gerar relatório da R.I” (diretor) e aba ICP com a análise de sexta |
| Configurações do funil | Ajuste em `/funil/configuracoes` | Diretor | Listas da Seção 3, cadência, modelos de e-mail, rubrica e liga/desliga de cada agente |

**Mudança de permissão necessária:** hoje só o diretor cria tarefas. A v2 precisa que o sistema e os agentes criem tarefas para qualquer responsável, com uma coluna `origem` (manual, sistema ou agente) e um vínculo com o negócio.

## 7. Indicadores

Sete dos 16 indicadores pedidos já são calculados. Os outros dependem das listas da Seção 3 ou de pequenas mudanças no banco. Todos aparecem no geral e por membro.

| Indicador | Definição | Situação |
| --- | --- | --- |
| Leads novos | Negócios criados no período | Já existe |
| Diagnósticos marcados | Entradas em Diagnóstico agendado | Já existe |
| Propostas apresentadas | Entradas em Apresentação de proposta | Já existe |
| Propostas remarcadas | Atividades de proposta com status `remarcada` | Novo (status `remarcada`) |
| Contratos | Entradas em Projetos Aprimora | Já existe |
| Ticket médio | Faturamento ÷ contratos | Já existe |
| Ticket por solução | Soma do valor de cada serviço ÷ contratos com esse serviço | Novo (valor por serviço) |
| Ciclo de venda | Média de dias entre a criação do card e a entrada em **Projetos Aprimora** | Já existe (confirmado) |
| Conversão por fase | % que chega à fase seguinte | Já existe |
| Pipeline ponderado | Soma de valor × probabilidade da fase atual, nos negócios abertos | Novo (a probabilidade já existe nas fases) |
| Tempo por fase, SLA e saídas | Tempo médio, % dentro do SLA e para onde os negócios saíram | Parcial (falta % no SLA e destinos) |
| Desempenho por membro | Todos os indicadores pelo responsável **da época** da movimentação | Corrigir: hoje usa o responsável atual |
| Origem dos leads | Leads, conversão e faturamento por origem | Existe; falta a lista nova de origens |
| Motivos de perda | Distribuição por motivo, por fase de saída e por membro | Novo (lista 3.3) |
| Coldcall | Ligações feitas, % por resultado, % que vira diagnóstico, nota média da rubrica | Novo (lista 3.1 e A3) |
| Cadência de e-mail | Enviados, taxa de resposta, respostas por classificação | Novo (A5 e A6) |

Para não ficar lento com o crescimento, os indicadores passam a ser calculados no banco, em vez de na memória da Vercel a cada acesso.

## 8. Arquitetura, integrações e custos

A arquitetura já desenhada no repositório é mantida: o portal guarda o trabalho numa fila e o n8n, numa VPS da Hostinger, busca cada item, chama a IA e os serviços externos e devolve o resultado. Se o n8n cair, nada se perde e o portal continua funcionando.

```
Membros (site e PWA) ◀──HTTPS──▶ Portal (Vercel: telas, /api/n8n/*, /api/push) ◀── pede e devolve trabalho ── n8n (VPS Hostinger)
                                          │                                                                   │
                                          ▼                                                                   ▼
                     Supabase (banco, regras e fila, pg_cron, arquivos, login)        Gemini · Google Workspace · API4COM · Dados públicos
```

O único ponto que guarda dados é o Supabase. A gravação da API4COM chega por webhook ao portal, entra na fila e só então vai para o n8n. As rotas `/api/n8n/*` previstas no `n8n/README.md` são o primeiro código a escrever.

| Item | Uso | Situação |
| --- | --- | --- |
| Vercel | Portal (site e PWA) | Já em uso |
| Supabase | Banco, regras, fila, arquivos, login | Plano gratuito; pago só se faltar espaço |
| VPS Hostinger | n8n (gratuito, auto-hospedado) | A contratar |
| API do Gemini | Transcrição, resumos, classificação, textos | Plano gratuito (ver risco na Seção 10) |
| Google Workspace | Envio de e-mails, agenda, gravações no Drive | Conta pessoal do diretor nos testes, depois comercial@ |
| API4COM | Ligações e gravações | Já contratada |
| Plano Claude (R$ 110/mês) | Desenvolvimento do portal | Para construir, não para rodar os agentes |
| Dados públicos de CNPJ, Google Maps, Apollo | Enriquecimento e prospecção | Gratuitos dentro dos limites de cada um |

## 9. Roadmap por fases

O portal evolui em sete fases, uma por vez. Cada fase termina utilizável, e a seguinte só começa quando o portão da anterior é cumprido. Não há datas fixas, porque o ritmo depende do tempo de desenvolvimento disponível.

| Fase | Entregas | Portão |
| --- | --- | --- |
| 0 · Fundação do processo | Listas padronizadas (Seção 3), status remarcada, valor por serviço, tarefas automáticas com push; indicadores no banco e pelo responsável da época | Resultado de ligação e motivo de perda registrados em todos os casos por 2 semanas |
| 1 · Infraestrutura dos agentes | VPS Hostinger com n8n, rotas `/api/n8n/*`, fila, chave do Gemini e Caixa de aprovação; saúde da fila e liga/desliga de cada agente nas configurações | Um fluxo de teste vai e volta pela fila sem erro |
| 2 · Agentes prioritários | A1 Enriquecedor, A2 Agente de ligação, A3 Avaliador e A4 Analista gerencial (relatório da R.I); tela de Desempenho individual | Card enriquecido sem digitação, ligação anotada sozinha e R.I gerada com um clique |
| 3 · Cadência de e-mail | A5 Redator, A6 Monitor de respostas e A7 Organizador do dia; envio pela conta pessoal nos testes, depois pela comercial@ | Cadência completa rodando com aprovação dos membros |
| 4 · Da oportunidade à venda | A8 Agendador, diagnóstico e precificação digitais, A9 Assistente de proposta; A10 Passagem para Projetos com dossiê em PDF | Um negócio real vai do diagnóstico ao dossiê dentro do portal |
| 5 · Inteligência | A11 Analista de ICP (toda sexta) e planos de melhoria por membro; A12 Prospector (Google Maps e Apollo) | Um mês de dados nas listas novas |
| 6 · Migração do Pipefy | Limpeza e importação dos 805 cards; desligamento do Pipefy | — |

A Fase 0 vem antes dos agentes porque eles dependem das listas padronizadas para registrar e medir o trabalho. O Pipefy fica por último, como decidido, e continua ativo até a importação.

## 10. Riscos, premissas e decisões pendentes

| Risco | Impacto | Como tratar |
| --- | --- | --- |
| No plano gratuito, o Google pode usar os dados enviados ao Gemini para melhorar seus produtos | Transcrições com dados de leads saem do controle da Aprimora | Conferir os termos atuais da API antes da Fase 2; se confirmado, avaliar o plano pago só para áudio ou anonimizar nomes e telefones |
| Limites de uso do Gemini gratuito | Agentes param no meio do dia | Fila no portal com novas tentativas; regras sem IA onde der (Seção 5) |
| VPS única para o n8n | Se cair, os agentes param | O portal funciona sem o n8n; a fila guarda o trabalho até a volta |
| Limite de envio do Gmail e reputação do domínio | E-mails vão para spam | Volume baixo por dia, aquecimento da conta comercial@, SPF/DKIM configurados |
| Time aprova sem ler | E-mail ruim chega ao lead | Aprovação mostra o texto inteiro; diretor audita uma amostra semanal |
| Gravação de ligações | Exigência de aviso ao lead | Decidido: sem preocupação específica no momento; manter a opção de aviso no roteiro |
| Equipe de desenvolvimento pequena | Fases atrasam | Uma fase por vez, cada uma utilizável ao terminar |

**Premissas:** orçamento limitado a VPS Hostinger, plano Claude para desenvolvimento e Supabase gratuito (ou pago, se necessário); API do Gemini; API4COM já contratada; Pipefy desligado só depois da importação.

**Decisões pendentes:**

- [ ] Meta de volume de leads novos por semana
- [ ] Enviar os modelos de e-mail e o roteiro de coldcall atuais
- [ ] Validar a rubrica de avaliação de ligações (5.1)
- [ ] Ligar as 10 áreas do checklist aos serviços da Carta de Serviços
- [ ] Confirmar a fórmula do “multiplicativo ambiente” da planilha de precificação
- [ ] Confirmar se a Apollo será usada no plano gratuito
- [ ] Definir quem da Diretoria de Projetos recebe o dossiê de passagem

## Decisões registradas (12/10/2026)

Tomadas com o Diretor Comercial no início da Fase 0. Prevalecem sobre o texto acima quando houver conflito.

- **Diretorias:** nada é apagado do banco. Presidência, Vice-Presidência, Projetos e Marketing continuam cadastradas,
  mas não recebem telas nem regras novas. O Painel geral atual vai para a seção Vice-Presidência, para comparação.
- **Retornar futuro:** só quando o decisor pede retorno em outro momento. Sem contato efetivo (não atendeu, decisor
  indisponível), o card fica na fase em que está, com data de retorno.
- **Cadência:** o card só muda de fase sozinho quando o n8n confirma uma resposta real de e-mail (Fase 3). Sem
  resposta, o único movimento automático é o do D21 para a Reciclagem. Os toques que caem em fim de semana ou feriado
  vão para o próximo dia útil.
- **Origens e motivos:** as listas antigas são substituídas (apagadas) pelas da Seção 3.
- **Tarefas:** além do diretor, o assessor pode criar tarefas para si mesmo.
- **Uso:** o portal só é liberado ao time ao fim das fases. Cada portão do roadmap vira um **roteiro de teste com dados
  fictícios**, validado pelo diretor. A importação do Pipefy é feita junto com o diretor, com análise prévia dos dados.
- **Fluxo:** os commits vão direto para a `main`.
