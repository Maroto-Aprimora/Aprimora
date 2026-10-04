// Conteúdo do Documento de Escopo do Portal Aprimora.
// Este arquivo só descreve O QUE o documento diz, em blocos neutros.
// A formatação fica em render-docx.js (Word) e render-pdf.js (PDF).
// Sintaxe inline: **negrito** e `código`.

const VERSAO = "1.0";
const DATA = "04/10/2026";

const corpo = [];
const add = (...xs) => xs.forEach((x) => (Array.isArray(x) ? corpo.push(...x) : corpo.push(x)));

const H1 = (text) => ({ t: "h1", text });
const H2 = (text) => ({ t: "h2", text });
const H3 = (text) => ({ t: "h3", text });
const P = (text) => ({ t: "p", text });
const bullets = (items) => ({ t: "ul", items });
const numbered = (items) => ({ t: "ol", items });
const table = (headers, rows, widths, opts = {}) => ({ t: "table", headers, rows, widths, opts });
const callout = (title, lines, kind = "info") => ({ t: "callout", title, lines: [].concat(lines), kind });
const figure = (file, w, h, caption) => ({ t: "figure", file, w, h, caption });

// ---------- Controle do documento ----------
add(H1("Controle do documento"));
add(P("Este documento é **vivo**. Toda mudança de escopo aprovada deve gerar uma nova versão, registrada na tabela abaixo. A fonte oficial fica no repositório do projeto, na pasta `docs/escopo`, junto com o script que gera este arquivo."));
add(table(["Versão", "Data", "Autor", "Descrição"], [
  ["0.1", "04/10/2026", "Diretoria Comercial", "Levantamento: leitura do protótipo Portal Comercial, perguntas e respostas da diretoria, análise do Pipefy e da Carta de Serviços."],
  ["1.0", "04/10/2026", "Diretoria Comercial", "Primeira versão completa do escopo para validação com os demais diretores."],
], [900, 1300, 2000, 5400]));
add(H3("Como ler este documento"));
add(bullets([
  "**Seções 1 a 4**: o porquê do projeto, os objetivos e o que está dentro e fora do escopo. São a leitura mínima para qualquer membro.",
  "**Seções 5 a 10**: como o portal funciona (perfis, funil, módulos, indicadores, automações e IA). É a referência para quem usa e para quem desenvolve.",
  "**Seções 11 a 13**: arquitetura técnica, requisitos não funcionais e identidade visual. É a referência para quem desenvolve.",
  "**Seções 14 a 17**: plano de entregas, riscos, governança e decisões em aberto. É a referência para a diretoria.",
  "**Anexos**: catálogo de serviços, campos do funil, diagnóstico do protótipo e glossário.",
]));
add(callout("Convenções usadas", [
  "**RF-XX**: requisito funcional (o que o sistema faz). **RNF-XX**: requisito não funcional (como o sistema deve se comportar).",
  "**Prioridade (MoSCoW)**: **M** = obrigatório (Must), **S** = importante (Should), **C** = desejável (Could), **W** = não será feito agora (Won't).",
  "Os termos técnicos são explicados no Glossário (Anexo D).",
]));

// ---------- 1. Introdução ----------
add(H1("1. Introdução"));
add(H2("1.1 Sobre a Aprimora"));
add(P("A **Aprimora** é a Empresa Júnior de Engenharia de Produção da UTFPR, campus Londrina, e é referência na região. Seu propósito é ajudar pequenas e médias empresas a se tornarem a sua **melhor versão** com assessorias nas áreas de **negócios, produção e qualidade**, entregando soluções personalizadas que façam sentido para cada cliente."));
add(P("A empresa tem mais de 30 membros em cinco diretorias: **Comercial**, **Projetos**, **Presidência** (nome usado para a diretoria Jurídico-Financeira), **Recursos Humanos** e **Marketing**. A Diretoria Comercial tem hoje 7 pessoas."));
add(H2("1.2 O que é o Portal Aprimora"));
add(P("O Portal Aprimora é um aplicativo web instalável (PWA) que **centraliza o trabalho da Diretoria Comercial** em um só lugar: leads, funil de vendas, visitas, diagnósticos, agenda, tarefas, metas e indicadores. Ele também automatiza o que hoje é manual: preenchimento de metas, follow-ups por e-mail, lembretes, alertas e relatórios."));
add(P("O portal nasce comercial e foi desenhado para **crescer e virar o aplicativo oficial de toda a empresa júnior**, recebendo depois os módulos das outras diretorias."));
add(H2("1.3 Por que este documento existe"));
add(P("Empresas juniores têm **alta rotatividade**: todo mês entram ou saem de 1 a 2 pessoas, e o Diretor Comercial muda uma vez por ano. Por isso este documento tem dois objetivos:"));
add(numbered([
  "**Alinhar a diretoria atual** sobre o que será construído, em que ordem e com quais critérios de sucesso.",
  "**Preservar o raciocínio** por trás de cada decisão, para que as próximas gerações entendam por que o sistema é como é e consigam mantê-lo e evoluí-lo. O código será **patrimônio da Aprimora**.",
]));

// ---------- 2. Contexto ----------
add(H1("2. Contexto e problema"));
add(H2("2.1 Como o trabalho comercial é feito hoje"));
add(table(["Ferramenta", "Uso atual", "Limitação"], [
  ["Pipefy", "Funil comercial completo, remodelado recentemente, com 18 fases, formulários e algumas automações de SLA. Também faz a passagem do projeto vendido para Projetos e Presidência.", "Indicadores de funil fracos, dados isolados de metas e agenda, automação de e-mail limitada e custo de crescimento."],
  ["Portal Comercial (protótipo)", "Protótipo feito no Lovable com painel, funil simplificado, visitas, metas, tarefas e agenda.", "Funil diferente do Pipefy, metas preenchidas à mão, falhas de segurança e dependência do Lovable (veja o Anexo C)."],
  ["Planilhas e e-mail manual", "Controle paralelo de metas, envios e follow-ups.", "Retrabalho, dados desatualizados e nenhum histórico confiável."],
], [1800, 3900, 3900]));
add(H2("2.2 Dores principais"));
add(bullets([
  "**Preenchimento manual de metas**: o diretor precisa consolidar os números à mão. Este é o maior gargalo atual.",
  "**Falta de indicadores recorrentes do funil**: não há acompanhamento confiável de taxa de conversão, ticket médio, ciclo de venda, tempo por fase e motivos de perda.",
  "**Informação espalhada** entre Pipefy, protótipo, planilhas e caixas de e-mail individuais.",
  "**Follow-up dependente de memória**: os e-mails de acompanhamento são enviados à mão e acabam esquecidos.",
  "**Pouca visibilidade para o diretor** sobre o andamento de cada assessor e de cada lead.",
  "**Perda de conhecimento** a cada troca de membros: dúvidas frequentes, objeções e boas respostas não ficam registradas.",
]));
add(H2("2.3 Oportunidade"));
add(P("Com o protótipo e o Pipefy recém-remodelado, a Aprimora já tem o processo comercial bem definido. Falta uma **plataforma própria** que siga esse processo, gere os indicadores sozinha e automatize as tarefas repetitivas. Ela deve ser construída com custo inicial zero, para demonstrar valor aos demais diretores antes de qualquer investimento."));

// ---------- 3. Objetivos ----------
add(H1("3. Objetivos e critérios de sucesso"));
add(H2("3.1 Objetivo geral"));
add(P("Entregar um **portal comercial próprio, seguro e automatizado** que substitua o Pipefy e as planilhas da Diretoria Comercial, gere indicadores e metas sem preenchimento manual e sirva de base para o futuro aplicativo de toda a empresa júnior."));
add(H2("3.2 Objetivos específicos"));
add(numbered([
  "Representar no portal **o funil comercial atual do Pipefy**, com histórico completo de movimentações e SLA por fase.",
  "**Calcular metas e indicadores automaticamente** a partir dos dados do funil, das atividades e dos e-mails.",
  "**Automatizar a cadência de e-mails**: o 1º envio só sai com aprovação, e depois o portal monitora a caixa e envia os follow-ups sozinho.",
  "Enviar **lembretes, alertas de SLA e resumo semanal** sem intervenção humana.",
  "Controlar o **acesso por convite**, com perfis de Diretor, Assessor e Trainee e regras por diretoria.",
  "Oferecer **assistência por IA** baseada na base de conhecimento da Aprimora.",
  "Funcionar como **PWA** instalável no celular, com notificações.",
  "Manter **custo zero** na fase de piloto.",
]));
add(H2("3.3 Critérios de sucesso do piloto"));
add(P("Ao fim do piloto (veja a Seção 14), a diretoria avaliará o projeto com estes indicadores:"));
add(table(["Critério", "Meta proposta", "Como medir"], [
  ["Adoção", "7 de 7 membros do Comercial usando o portal toda semana", "Acessos e registros por usuário (log de atividade)"],
  ["Cobertura do funil", "100% dos negócios ativos no portal, nenhum mais no Pipefy", "Contagem de negócios ativos"],
  ["Metas automáticas", "0 metas preenchidas à mão, exceto as definidas como qualitativas", "Tipo de cálculo de cada meta"],
  ["Follow-up", "100% dos leads em cadência com follow-up no prazo", "Envios atrasados ÷ envios previstos"],
  ["Tempo do diretor", "Redução perceptível do tempo gasto consolidando números (meta: menos de 30 min por semana)", "Autoavaliação do Diretor Comercial"],
  ["Custo", "R$ 0 por mês no piloto", "Faturas dos serviços"],
  ["Satisfação", "Nota média de 8 ou mais na pesquisa com os usuários", "Formulário ao fim do piloto"],
], [1800, 4200, 3600]));

// ---------- 4. Escopo ----------
add(H1("4. Escopo"));
add(H2("4.1 Dentro do escopo (MVP Comercial)"));
add(bullets([
  "Autenticação por convite, perfis (Diretor, Assessor, Trainee), diretorias e gestão de membros.",
  "Cadastro de **empresas, contatos e leads**, com origem do lead e detecção de duplicidade.",
  "**Funil comercial** em kanban com as fases do Pipefy, campos por fase, SLA, histórico e saídas (ganho, reciclagem, não vendido, não qualificado).",
  "**Atividades**: visitas, diagnósticos, reuniões, ligações e e-mails, com confirmação de visita pelo assessor.",
  "**Agenda** da equipe e **tarefas** individuais ou compartilhadas.",
  "**Metas trimestrais** calculadas automaticamente e **painéis de indicadores** pessoais e da diretoria.",
  "**Notificações** no app, por push (PWA) e por e-mail.",
  "**Automações via N8N**: cadência de e-mail, monitoramento da caixa, follow-ups, lembretes, alertas de SLA, resumo semanal e passagem do ganho para Projetos e Presidência.",
  "**Extração e importação de leads** em massa (CSV e fluxos N8N), com enriquecimento.",
  "**Assistente de IA**: sugestão de respostas, classificação de e-mails, resumo de diagnósticos e consulta à base de conhecimento.",
  "Migração das metas atuais e dos cards ativos do Pipefy.",
  "Documentação técnica e de uso no repositório.",
]));
add(H2("4.2 Fora do escopo neste momento"));
add(table(["Item", "Motivo", "Quando reavaliar"], [
  ["Módulos de Projetos, Presidência, RH e Marketing", "Prioridade é terminar o Comercial", "Após o piloto (Fase 8)"],
  ["Ocupação da equipe", "Ainda não há definição de como medir", "Quando a métrica for definida"],
  ["Integração com WhatsApp", "Não desejada pela diretoria", "Não previsto"],
  ["Publicação na Play Store e App Store", "O PWA atende sem custo", "Se houver demanda e orçamento"],
  ["Funcionamento sem internet", "Não é necessário", "Não previsto"],
  ["Deploy automático em produção", "A publicação na Vercel e no domínio será feita manualmente pela diretoria", "Após a validação"],
  ["NPS de clientes", "É coletado pela Presidência após o projeto", "No módulo da Presidência"],
], [3000, 3800, 2800]));
add(H2("4.3 Visão de longo prazo"));
add(P("O portal será a **plataforma única da Aprimora**. A arquitetura já prevê o conceito de **diretoria** em todas as tabelas e permissões. Assim, os módulos futuros entram sem reescrever a base:"));
add(bullets([
  "**Projetos**: recebe os projetos vendidos com escopo, gerente, assessores, fases e oportunidades de melhoria.",
  "**Presidência**: contratos, cobranças, parcelas, fluxo de caixa e NPS.",
  "**RH**: processo seletivo, avaliações, desenvolvimento dos membros e entrada e saída de pessoas.",
  "**Marketing**: calendário editorial e captação de leads integrada ao funil.",
]));

// ---------- 5. Perfis ----------
add(H1("5. Perfis de acesso e permissões"));
add(H2("5.1 Estrutura organizacional"));
add(P("A Aprimora tem uma **estrutura horizontal na diretoria**: os 5 diretores têm o mesmo poder de decisão. O cargo de Presidente é o nome dado ao diretor Jurídico-Financeiro e não tem privilégios extras no sistema. Abaixo dos diretores estão os assessores e, por fim, os trainees. Pós-juniores e conselheiros não terão acesso."));
add(table(["Cargo", "Quantidade", "Descrição no sistema"], [
  ["Diretor", "5 (um por diretoria)", "Administra a própria diretoria: membros, metas, configurações e todos os registros. Vê as outras diretorias, mas não altera nada nelas."],
  ["Assessor", "Variável", "Executa o trabalho da diretoria: gerencia os próprios leads, negócios, atividades e tarefas."],
  ["Trainee", "Variável", "Em formação. Mesmo acesso de leitura do assessor, com permissões de escrita restritas (proposta na Seção 5.3)."],
], [1500, 1700, 6400]));
add(H2("5.2 Regras gerais de acesso"));
add(numbered([
  "**Não existe cadastro aberto.** Só entra quem for convidado por e-mail pelo diretor da própria diretoria.",
  "**Todo diretor vê todas as diretorias**, mas **só altera a sua**.",
  "O perfil e a diretoria de cada pessoa são definidos **apenas pelo diretor**, nunca pelo próprio usuário. Isso corrige a falha crítica do protótipo descrita no Anexo C.",
  "As regras são aplicadas **no banco de dados** (Row Level Security), e não só na tela. Mesmo quem acessar a API diretamente não passa por cima delas.",
  "Toda ação sensível (mudança de perfil, exclusão, transferência de carteira) fica registrada em **log de auditoria**.",
]));
add(H2("5.3 Matriz de permissões (Diretoria Comercial)"));
add(P("Legenda: **T** = total (criar, ler, editar, excluir), **E** = criar e editar os próprios ou aqueles em que participa, **L** = só leitura, **—** = sem acesso."));
add(table(["Recurso", "Diretor Comercial", "Diretor de outra área", "Assessor", "Trainee"], [
  ["Membros da diretoria", "T", "L", "L (nome e cargo)", "L (nome e cargo)"],
  ["Empresas e contatos", "T", "L", "E (vê todos, para evitar contato duplicado)", "E"],
  ["Negócios (funil)", "T", "L", "E nos seus; L nos da equipe", "E nos seus; L nos da equipe"],
  ["Mover fase, marcar ganho ou perda", "T", "—", "E nos seus", "E nos seus, exceto ganho (proposta)"],
  ["Visitas e atividades", "T", "L", "E nas suas e nas que participa", "E nas suas e nas que participa"],
  ["Agenda", "T", "L", "E nos seus eventos; L na equipe", "E nos seus eventos; L na equipe"],
  ["Tarefas", "T", "L", "E nas atribuídas a ele", "E nas atribuídas a ele"],
  ["Metas", "T", "L", "L", "L"],
  ["Indicadores", "Todos", "Todos (leitura)", "Pessoais + agregados da equipe", "Pessoais + agregados da equipe"],
  ["Aprovar e-mail inicial", "T", "—", "Conforme configuração (Seção 17)", "—"],
  ["Configurações (fases, SLA, modelos, serviços)", "T", "—", "—", "—"],
  ["Base de conhecimento da IA", "T", "L", "L + sugerir conteúdo", "L"],
], [2500, 1500, 1500, 2100, 2000], { boldFirst: true, size: 16 }));
add(callout("Por que o assessor vê todas as empresas?", "Com 7 pessoas prospectando, o maior risco é duas pessoas contatarem a mesma empresa. O protótipo já tinha uma busca de \"empresa já visitada\" com esse objetivo. Por isso, os dados cadastrais e o histórico de contatos ficam visíveis para toda a diretoria. A edição continua restrita ao responsável."));
add(H2("5.4 Ciclo de vida dos membros"));
add(table(["Evento", "Como funciona no portal"], [
  ["Entrada", "O diretor informa nome, e-mail, cargo e diretoria. O portal envia um convite com link de acesso válido por 7 dias. No primeiro acesso a pessoa define a senha."],
  ["Mudança de cargo", "Trainee para assessor, ou assessor para diretor na troca anual: só o diretor da diretoria altera, e a mudança fica registrada na auditoria."],
  ["Saída", "O diretor desativa o membro, que perde o acesso na hora. O histórico é preservado (nada é apagado), e os registros continuam associados ao nome da pessoa."],
  ["Transferência de carteira", "Na saída, ou a qualquer momento, o diretor transfere em lote os negócios, tarefas e eventos futuros de um membro para outro."],
  ["Troca anual de diretor", "O diretor que sai promove o sucessor antes de se rebaixar ou desativar. O sistema nunca deixa uma diretoria sem diretor ativo."],
], [2200, 7400], { boldFirst: true }));

// ---------- 6. Processo comercial ----------
add(H1("6. Processo comercial (funil)"));
add(P("O funil do portal **reproduz o pipe do Pipefy recém-remodelado**, que é o processo oficial da Diretoria Comercial. As fases ficam agrupadas em **macroetapas** para facilitar a leitura dos indicadores."));
add(figure("funil.png", 3200, 1014, "Figura 1: Funil comercial da Aprimora (fases do Pipefy agrupadas em macroetapas)"));
add(H2("6.1 Fases, objetivos e campos"));
add(table(["Macroetapa", "Fase", "Objetivo", "Campos e automações herdados do Pipefy"], [
  ["Prospecção", "Formulário inicial", "Cadastrar o lead", "Nome da empresa, telefone, e-mails principal, secundário e terciário, segmento, decisor, rede social e outros (15 campos, veja o Anexo B)"],
  ["Prospecção", "Entrada de leads", "Receber leads, inclusive importados", "Automação: card movido para cá vai para Enriquecimento"],
  ["Prospecção", "Enriquecimento", "Completar dados do decisor e contatos", "SLA atingido gera alerta (atrasado)"],
  ["Prospecção", "Coleta de dados", "Validar os dados antes da abordagem", "—"],
  ["Cadência", "E-mail", "Primeiro contato e follow-ups", "Automação: distribuir responsável. Campos: etapa de e-mail, data do 1º envio, follow-ups 1, 2 e 3"],
  ["Cadência", "Coldcall (semana 1)", "Ligações de prospecção", "—"],
  ["Cadência", "Coldcall (semana 2)", "Segunda rodada de ligações", "—"],
  ["Cadência", "Retornar futuro", "Lead pediu contato depois", "Retornar em (data), retorna para qual decisor"],
  ["Oportunidade", "Oportunidade", "Lead demonstrou interesse; agendar diagnóstico", "SLA, qual a oportunidade. Regra: mais de 14 dias sem agendar volta para a cadência"],
  ["Venda consultiva", "Diagnóstico", "Entender as dores do cliente", "Data marcada, dores coletadas na ligação, decisor contatado"],
  ["Venda consultiva", "Elaboração de escopo", "Construir escopo e valor", "Data limite, arquivo do escopo, responsáveis pela elaboração"],
  ["Venda consultiva", "Apresentação de proposta", "Apresentar e negociar", "Data da apresentação, quem apresentou, decisores presentes"],
  ["Saída: ganho", "Projetos Aprimora", "Projeto vendido; passagem para outras áreas", "Proposta, declaração de escopo, projeto, fases, gerente, assessores do projeto, oportunidades de melhoria"],
  ["Saída: pausa", "Reciclagem", "Lead esfriou; voltar a contatar depois", "SLA de reciclagem, etiqueta"],
  ["Saída: perda", "Projeto não vendido", "Registrar a perda", "Motivo de não ter vendido (obrigatório)"],
  ["Saída: perda", "Lead não qualificado", "Fora do perfil de cliente ideal (ICP)", "Motivo (proposta: lista padronizada)"],
], [1500, 1900, 2500, 3700], { size: 16 }));
add(H2("6.2 Regras de negócio do funil"));
add(numbered([
  "**Toda movimentação gera histórico**: fase de origem, fase de destino, quem moveu, quando e o motivo, se houver. Sem histórico não é possível calcular conversão nem tempo por fase.",
  "**Cada fase tem um SLA configurável** em dias. Ao estourar, o portal executa a ação da fase: alerta, mover para Reciclagem ou voltar para Enriquecimento ou cadência, como no Pipefy.",
  "**Os campos obrigatórios por fase** precisam estar preenchidos para o card avançar. Por exemplo: não se entra em Diagnóstico sem data marcada.",
  "**Toda saída de perda exige motivo**, escolhido em uma lista padronizada com opção de comentário. Isso alimenta o indicador de motivos de perda.",
  "**Reciclagem tem data de retorno**. Quando a data chega, o card volta para Entrada de leads ou Cadência e o responsável é notificado.",
  "**Cada negócio tem um responsável principal** e pode ter participantes. A distribuição automática na fase E-mail segue uma regra configurável (rodízio entre assessores ativos ou menor carteira).",
  "**Valor e escopo são únicos por negócio**. O negócio registra um ou mais serviços da carta como referência, mas o valor é livre (não existe tabela de preços).",
  "**Detecção de duplicidade**: ao cadastrar, o portal procura empresas pelo CNPJ, domínio do e-mail, telefone e nome parecido, e avisa antes de criar outra.",
]));
add(H2("6.3 Passagem do ganho para outras diretorias"));
add(P("Quando um negócio entra em **Projetos Aprimora**, o portal dispara de forma automática:"));
add(numbered([
  "Criação de um **registro de projeto** (diretoria de Projetos) com cliente, escopo, valor, responsáveis comerciais e arquivos da proposta.",
  "Criação de um **registro financeiro** (Presidência) com valor, condições de pagamento e contato do cliente, para seguir com contrato e cobrança.",
  "**Notificação e e-mail** aos diretores de Projetos e Presidência com o resumo do negócio.",
  "Atualização das **metas e indicadores** do Comercial (receita fechada e propostas convertidas).",
]));
add(callout("Enquanto os módulos de Projetos e Presidência não existem", "Os registros de projeto e financeiro serão criados em tabelas simples (\"caixa de entrada\" de cada diretoria) com uma tela de leitura. A informação passa a viver no portal desde o primeiro dia, e os módulos completos poderão ser construídos depois sem migração."));

// ---------- 7. Módulos ----------
add(H1("7. Módulos e requisitos funcionais"));
add(P("Cada módulo lista seus requisitos com identificador, prioridade (MoSCoW) e a fase do plano de entregas (Seção 14) em que será construído."));
const mod = (titulo, desc, reqs) => {
  add(H2(titulo));
  add(P(desc));
  add(table(["ID", "Requisito", "Prior.", "Fase"], reqs, [800, 7000, 800, 800], { boldFirst: true, size: 16 }));
};
mod("7.1 Acesso e gestão de membros", "Login, convites, perfis e diretorias.", [
  ["RF-01", "Login com e-mail e senha, recuperação de senha e sessão persistente no PWA.", "M", "0"],
  ["RF-02", "Convite por e-mail feito pelo diretor (nome, e-mail, cargo, diretoria), com link de uso único.", "M", "0"],
  ["RF-03", "Cadastro público desativado. Perfil e diretoria nunca vêm do navegador do usuário.", "M", "0"],
  ["RF-04", "Tela de membros: listar, editar cargo, desativar e reativar.", "M", "0"],
  ["RF-05", "Transferência de carteira em lote (negócios, tarefas, eventos futuros).", "M", "2"],
  ["RF-06", "Perfil do usuário: foto, telefone e preferências de notificação.", "S", "2"],
  ["RF-07", "Log de auditoria das ações sensíveis, consultável pelo diretor.", "S", "2"],
  ["RF-08", "Login com conta Google do Workspace @aprimoraej.com.", "C", "5"],
]);
mod("7.2 Empresas, contatos e leads", "Base única de empresas e pessoas, compartilhada pela diretoria.", [
  ["RF-10", "Cadastro de empresa: razão social, nome fantasia, CNPJ, segmento, porte, cidade, site e redes sociais.", "M", "1"],
  ["RF-11", "Cadastro de contatos da empresa: nome, cargo, decisor (sim ou não), e-mails, telefone, LinkedIn.", "M", "1"],
  ["RF-12", "Origem do lead: indicação, Instagram, eventos, prospecção ativa, site ou extração em massa, com detalhe livre.", "M", "1"],
  ["RF-13", "Detecção de duplicidade por CNPJ, domínio, telefone e nome parecido.", "M", "1"],
  ["RF-14", "Página da empresa com linha do tempo de negócios, atividades, e-mails e arquivos.", "M", "1"],
  ["RF-15", "Busca global (\"essa empresa já foi contatada? por quem? quando?\").", "M", "1"],
  ["RF-16", "Importação de leads por CSV com mapeamento de colunas e relatório de duplicados.", "M", "1"],
  ["RF-17", "Lista de bloqueio (opt-out e LGPD): contatos que não podem receber e-mails.", "M", "5"],
]);
mod("7.3 Funil (negócios)", "Kanban com as fases do Pipefy, campos por fase, SLA e histórico.", [
  ["RF-20", "Kanban por fase com arrastar e soltar; cards mostram empresa, responsável, valor, dias na fase e SLA.", "M", "1"],
  ["RF-21", "Fases, ordem, macroetapa, SLA e campos obrigatórios configuráveis pelo diretor.", "M", "1"],
  ["RF-22", "Histórico de movimentação gravado automaticamente pelo banco.", "M", "1"],
  ["RF-23", "Campos específicos por fase (datas, responsáveis, arquivos, textos) conforme o Anexo B.", "M", "1"],
  ["RF-24", "Saídas com motivo obrigatório (perda, não qualificado) e data de retorno (reciclagem).", "M", "1"],
  ["RF-25", "Ações automáticas por SLA (alerta, mover de fase), como no Pipefy.", "M", "4"],
  ["RF-26", "Filtros por responsável, origem, segmento, serviço e período; visão em lista com exportação para CSV.", "S", "1"],
  ["RF-27", "Anexos no negócio (escopo, proposta, declaração de escopo) no Storage.", "M", "1"],
  ["RF-28", "Distribuição automática de responsável na fase E-mail (rodízio ou menor carteira).", "S", "4"],
  ["RF-29", "Migração dos cards ativos do Pipefy via exportação em CSV.", "M", "1"],
]);
mod("7.4 Atividades: visitas, diagnósticos, reuniões e ligações", "Tudo o que é feito com o lead vira uma atividade ligada à empresa e ao negócio.", [
  ["RF-30", "Registro de atividade: tipo (visita presencial, online, diagnóstico, ligação, reunião, evento), data, participantes, resumo, próximos passos e stakeholder.", "M", "2"],
  ["RF-31", "Confirmação de visita pelo assessor (pendente, confirmada, realizada, cancelada).", "M", "2"],
  ["RF-32", "Todos os participantes veem e editam a atividade (corrige o protótipo).", "M", "2"],
  ["RF-33", "Registro rápido de ligação de coldcall com resultado (atendeu, não atendeu, retornar, sem interesse).", "S", "2"],
  ["RF-34", "Atividades com data futura aparecem na agenda automaticamente.", "M", "2"],
]);
mod("7.5 Agenda", "Calendário da equipe com visitas, diagnósticos, apresentações, reuniões internas e eventos.", [
  ["RF-40", "Visões de mês, semana e lista, com filtro por pessoa e tipo.", "M", "2"],
  ["RF-41", "Eventos internos (reunião de equipe) com convidados.", "M", "2"],
  ["RF-42", "Lembretes automáticos: reunião do time para todos; reunião com lead para os responsáveis do evento.", "M", "4"],
  ["RF-43", "Sincronização com o Google Agenda dos membros.", "C", "6"],
]);
mod("7.6 Tarefas", "Checklist individual ou compartilhado.", [
  ["RF-50", "Tarefa com título, descrição, prazo, prioridade, status e vários responsáveis.", "M", "2"],
  ["RF-51", "Tarefa opcionalmente ligada a um negócio ou empresa.", "S", "2"],
  ["RF-52", "Tarefas geradas por automação (exemplo: \"ligar para o lead X\" ao entrar em Coldcall).", "S", "4"],
  ["RF-53", "Aviso de tarefas vencendo e vencidas.", "M", "4"],
]);
mod("7.7 Metas e indicadores", "Metas trimestrais calculadas sozinhas e painéis de KPIs (detalhes na Seção 8).", [
  ["RF-60", "Cadastro de meta: trimestre, tipo, escopo (equipe ou membro), valor-alvo, peso e método de cálculo.", "M", "3"],
  ["RF-61", "Progresso calculado automaticamente a partir dos dados; cálculo manual só para metas qualitativas.", "M", "3"],
  ["RF-62", "Progresso ponderado geral da equipe e projeção de fim de trimestre.", "S", "3"],
  ["RF-63", "Painel pessoal (assessor) e painel da diretoria (diretor) com os KPIs da Seção 8.", "M", "3"],
  ["RF-64", "Filtros por período, membro, origem e segmento; comparação com o período anterior.", "S", "3"],
  ["RF-65", "Importação das metas atuais.", "M", "3"],
]);
mod("7.8 Notificações", "Central única de avisos.", [
  ["RF-70", "Central de notificações no app (sino) com lidas e não lidas.", "M", "2"],
  ["RF-71", "Notificações push no celular e no computador (Web Push do PWA).", "M", "2"],
  ["RF-72", "E-mail para eventos importantes (convite, lembrete, resumo semanal).", "M", "4"],
  ["RF-73", "Preferências por tipo de notificação e canal.", "S", "4"],
]);
mod("7.9 Cadência de e-mail", "Primeiro envio com aprovação, monitoramento da caixa e follow-ups automáticos (detalhes na Seção 9.3).", [
  ["RF-80", "Modelos de e-mail com variáveis (empresa, contato, segmento, serviço) e versões para testes A/B.", "M", "5"],
  ["RF-81", "Rascunho do 1º e-mail gerado pelo modelo e personalizado por IA.", "S", "5"],
  ["RF-82", "Fila de aprovação: o aprovador revisa, edita, aprova ou rejeita.", "M", "5"],
  ["RF-83", "Envio pelo Gmail do Workspace e registro da data do 1º envio.", "M", "5"],
  ["RF-84", "Monitoramento das respostas e classificação automática (positiva, neutra, negativa, ausência, devolvido, descadastro).", "M", "5"],
  ["RF-85", "Follow-ups 1, 2 e 3 automáticos em intervalos configuráveis enquanto não houver resposta.", "M", "5"],
  ["RF-86", "Resposta recebida pausa a cadência e notifica o responsável.", "M", "5"],
  ["RF-87", "Painel de cadência: enviados, respondidos, taxa de resposta por modelo, segmento e ICP.", "S", "5"],
  ["RF-88", "Link ou instrução de descadastro em todo e-mail e respeito à lista de bloqueio.", "M", "5"],
]);
mod("7.10 Extração de leads e assistente de IA", "Fluxos N8N de captação e assistência inteligente (detalhes nas Seções 9 e 10).", [
  ["RF-90", "Fluxo de extração em massa por segmento e cidade, com fontes legítimas, entrando em Entrada de leads.", "S", "6"],
  ["RF-91", "Enriquecimento automático (site, CNPJ, decisor provável) com marcação do que veio da IA.", "S", "6"],
  ["RF-92", "Assistente que sugere respostas a leads usando a base de conhecimento.", "S", "6"],
  ["RF-93", "Resumo automático das anotações de diagnóstico em \"dores\" e \"serviços sugeridos\".", "C", "6"],
  ["RF-94", "Perguntas em linguagem natural sobre a base (\"quantos diagnósticos fizemos no setor alimentício?\").", "C", "6"],
  ["RF-95", "Base de conhecimento editável: perguntas frequentes, objeções, cases e carta de serviços.", "S", "6"],
]);
mod("7.11 Relatórios e configurações", "Resumo semanal e parâmetros do sistema.", [
  ["RF-100", "Resumo semanal por e-mail para cada diretoria (o que entrou, avançou, ganhou e perdeu; metas; atrasos).", "M", "4"],
  ["RF-101", "Resumo pessoal semanal para cada assessor (sua carteira, tarefas e SLA).", "S", "4"],
  ["RF-102", "Configurações da diretoria: fases, SLA, motivos de perda, serviços, tipos de atividade, modelos e regras de distribuição.", "M", "1"],
  ["RF-103", "Exportação de dados (CSV) para análises externas.", "S", "3"],
]);

// ---------- 8. KPIs ----------
add(H1("8. Indicadores (KPIs) e metas automáticas"));
add(P("Os indicadores são a principal falha do processo atual. Todos os KPIs abaixo são **calculados pelo banco de dados** a partir do histórico do funil e das atividades. Ninguém digita números."));
add(H2("8.1 Indicadores do funil"));
add(table(["Indicador", "Definição e fórmula", "Visão"], [
  ["Leads novos", "Quantidade de negócios criados no período, por origem e segmento.", "Diretor e assessor"],
  ["Taxa de conversão por etapa", "Negócios que avançaram da etapa A para a B ÷ negócios que entraram em A no período.", "Diretor e assessor"],
  ["Conversão geral", "Ganhos ÷ leads que entraram no período (por coorte de entrada).", "Diretor"],
  ["Taxa de ganho (win rate)", "Ganhos ÷ (ganhos + não vendidos) entre as propostas apresentadas.", "Diretor e assessor"],
  ["Receita fechada", "Soma do valor dos negócios ganhos no período.", "Diretor e assessor"],
  ["Ticket médio", "Receita fechada ÷ número de ganhos.", "Diretor"],
  ["Pipeline aberto", "Soma do valor dos negócios ativos a partir de Oportunidade.", "Diretor e assessor"],
  ["Pipeline ponderado", "Σ valor × probabilidade da macroetapa. Probabilidade configurável; padrão sugerido: Oportunidade 10%, Diagnóstico 25%, Escopo 50%, Proposta 70%.", "Diretor"],
  ["Ciclo de venda", "Média ou mediana de dias entre a entrada em Oportunidade e o ganho.", "Diretor"],
  ["Tempo médio por fase", "Média de dias em cada fase, calculada pelo histórico.", "Diretor"],
  ["Negócios com SLA estourado", "Quantidade e lista de negócios acima do SLA da fase.", "Diretor e assessor"],
  ["Motivos de perda", "Distribuição dos motivos de não vendido e não qualificado.", "Diretor"],
  ["Reativação da reciclagem", "Negócios que saíram da Reciclagem e chegaram a Oportunidade ÷ total reciclado.", "Diretor"],
], [2300, 5500, 1800], { boldFirst: true, size: 16 }));
add(H2("8.2 Indicadores de atividade e cadência"));
add(table(["Indicador", "Definição e fórmula", "Visão"], [
  ["Atividades por assessor", "Quantidade de visitas, diagnósticos, ligações e reuniões por pessoa e período.", "Diretor e assessor"],
  ["Diagnósticos marcados", "Negócios que entraram em Diagnóstico no período.", "Diretor e assessor"],
  ["Diagnósticos realizados", "Atividades do tipo diagnóstico com status realizada.", "Diretor e assessor"],
  ["Taxa de resposta de e-mail", "Leads que responderam ÷ leads com 1º envio no período, por modelo, segmento e ICP.", "Diretor"],
  ["Taxa de resposta positiva", "Respostas classificadas como positivas ÷ leads com 1º envio.", "Diretor"],
  ["Follow-ups no prazo", "Follow-ups enviados na data prevista ÷ follow-ups previstos.", "Diretor"],
  ["Conversão da coldcall", "Ligações que geraram Oportunidade ÷ ligações realizadas.", "Diretor e assessor"],
], [2300, 5500, 1800], { boldFirst: true, size: 16 }));
add(H2("8.3 Metas trimestrais automáticas"));
add(P("As quatro metas que já existem no protótipo passam a ter cálculo automático. Novas metas podem usar qualquer indicador das Seções 8.1 e 8.2."));
add(table(["Meta", "Cálculo automático", "Fonte"], [
  ["Receita (R$)", "Soma do valor dos negócios que entraram em Projetos Aprimora no trimestre.", "Histórico do funil"],
  ["Diagnósticos marcados", "Negócios que entraram em Diagnóstico no trimestre, ou atividades de diagnóstico realizadas (definir).", "Histórico do funil e atividades"],
  ["Propostas convertidas", "Negócios ganhos no trimestre que passaram por Apresentação de proposta.", "Histórico do funil"],
  ["Desenvolvimento dos membros", "Hoje é qualitativa. Proposta: manter manual até o módulo de RH existir, ou medir por capacitações concluídas.", "Manual (exceção)"],
], [2300, 5300, 2000], { boldFirst: true, size: 16 }));
add(callout("Decisão de projeto: dados derivados, nunca digitados", "O progresso de uma meta não é uma coluna que alguém atualiza. É uma consulta (view) sobre os dados reais. Assim os números nunca ficam desatualizados nem divergem entre telas, e qualquer membro futuro consegue auditar como cada número foi obtido."));

// ---------- 9. Automações ----------
add(H1("9. Automações e integrações (N8N)"));
add(H2("9.1 Princípios"));
add(numbered([
  "**O Supabase é a fonte da verdade.** O N8N lê e escreve no banco pela API, mas nenhum dado de negócio vive só no N8N.",
  "**O N8N é o orquestrador** de tudo que envolve tempo (agendamentos), serviços externos (Gmail, IA, fontes de leads) ou fluxos longos.",
  "**Eventos disparam fluxos**: mudanças no banco (exemplo: negócio entrou em E-mail) chamam webhooks do N8N. O N8N devolve o resultado por rotas protegidas do portal.",
  "**Toda execução deixa rastro** em uma tabela de log de automações, visível no portal, para diagnosticar falhas sem abrir o N8N.",
  "**Os fluxos são versionados**: o JSON de cada fluxo fica salvo no repositório (`automacoes/n8n`).",
]));
add(H2("9.2 Catálogo de fluxos"));
add(table(["#", "Fluxo", "Gatilho", "O que faz", "Fase"], [
  ["F1", "Lembretes de agenda", "Agendado (a cada 15 min)", "Lembra reuniões de equipe (todos) e reuniões com lead (responsáveis) em D-1 e H-1.", "4"],
  ["F2", "Alertas de SLA", "Agendado (diário)", "Encontra negócios com SLA estourado, notifica e executa a ação da fase (mover ou alertar).", "4"],
  ["F3", "Retorno da reciclagem", "Agendado (diário)", "Devolve ao funil os negócios cuja data de retorno chegou.", "4"],
  ["F4", "Resumo semanal", "Agendado (segunda, 8h)", "Gera e envia o resumo por diretoria e o resumo pessoal.", "4"],
  ["F5", "Passagem do ganho", "Evento: negócio ganho", "Cria registros de Projetos e Presidência e notifica os diretores.", "4"],
  ["F6", "Distribuição de responsável", "Evento: entrou em E-mail", "Atribui um assessor pela regra configurada.", "4"],
  ["F7", "Envio aprovado", "Evento: e-mail aprovado", "Envia pelo Gmail, guarda o ID da conversa e agenda os follow-ups.", "5"],
  ["F8", "Monitoramento da caixa", "Agendado (a cada 10 min)", "Lê respostas das conversas monitoradas, classifica com IA e atualiza o negócio.", "5"],
  ["F9", "Follow-ups", "Agendado (de hora em hora)", "Envia o follow-up devido quando não houve resposta; após o 3º, move para Coldcall.", "5"],
  ["F10", "Extração de leads", "Manual ou agendado", "Busca empresas por segmento e cidade, remove duplicados e cria leads em Entrada de leads.", "6"],
  ["F11", "Enriquecimento", "Evento: entrou em Enriquecimento", "Completa dados públicos (site, CNPJ, redes) e sugere o decisor.", "6"],
], [500, 1900, 1900, 4500, 700], { size: 16 }));
add(H2("9.3 Cadência de e-mail em detalhe"));
add(figure("cadencia.png", 3200, 622, "Figura 2: Ciclo da cadência de e-mail"));
add(bullets([
  "**Conta de envio**: o e-mail sai pela conta Google Workspace do responsável ou por uma conta comercial (comercial@aprimoraej.com). A decisão está na Seção 17.",
  "**Rastreio**: cada envio grava o ID da mensagem e da conversa do Gmail. O monitoramento só olha as conversas da cadência e não lê o resto da caixa.",
  "**Limites**: o Workspace permite cerca de 2.000 envios por dia por usuário. Os envios serão espaçados (exemplo: no máximo 50 por hora) para proteger a reputação do domínio.",
  "**Entregabilidade**: verificar SPF, DKIM e DMARC do domínio aprimoraej.com antes da Fase 5.",
  "**Testes A/B**: cada modelo tem versões. O painel compara a taxa de resposta por versão, assunto e ICP, a exemplo do CRM de coldmail do Portal Valkz.",
]));
add(H2("9.4 Extração de leads e LGPD"));
add(P("A extração em massa deve usar **fontes legítimas** e respeitar a LGPD. A prospecção B2B se apoia na base legal de **legítimo interesse**, desde que o contato seja profissional, haja transparência e o titular possa pedir para sair a qualquer momento."));
add(table(["Fonte", "Uso", "Observação"], [
  ["Formulário do site e Instagram", "Leads de entrada", "Webhook ou cadastro manual"],
  ["Eventos e indicações", "Importação por CSV ou cadastro manual", "Registrar a origem"],
  ["Dados abertos de CNPJ (Receita Federal)", "Empresas por CNAE, porte e cidade", "Gratuito; dados cadastrais públicos"],
  ["Google Maps (Places API)", "Empresas locais por segmento", "Cota gratuita mensal, cobrado acima dela; respeitar os termos de uso"],
  ["Site da própria empresa", "E-mail e telefone comerciais públicos", "Enriquecimento via N8N"],
  ["LinkedIn", "Somente consulta manual", "Raspagem automática viola os termos de uso: fora do escopo"],
], [3000, 3300, 3300], { boldFirst: true, size: 16 }));
add(H2("9.5 Hospedagem do N8N com custo zero"));
add(table(["Opção", "Prós", "Contras"], [
  ["N8N Community self-hosted em VM gratuita (ex.: Oracle Cloud Always Free)", "Gratuito, sem limite de execuções, controle total", "Exige configurar Docker, domínio e backup (documentado no repositório)"],
  ["Computador de um membro durante o piloto", "Zero configuração de nuvem", "Fica fora do ar quando o computador desliga; não serve para produção"],
  ["N8N Cloud (período de teste)", "Pronto para usar", "Pago após o teste"],
  ["VPS paga (ex.: Hostinger)", "Estável e simples", "Custo mensal; opção para depois da aprovação do investimento"],
], [3300, 3100, 3200], { boldFirst: true, size: 16 }));
add(P("**Recomendação:** N8N Community em VM gratuita para o piloto, com o arquivo `docker-compose` e o passo a passo no repositório, migrando para uma VPS paga se o projeto for aprovado."));

// ---------- 10. IA ----------
add(H1("10. Inteligência artificial"));
add(H2("10.1 Casos de uso"));
add(table(["Caso de uso", "Como funciona", "Quem usa", "Prior."], [
  ["Classificar respostas de e-mail", "A IA lê a resposta e classifica (positiva, neutra, negativa, ausência, descadastro) para a automação decidir o próximo passo.", "Automação (F8)", "M"],
  ["Sugerir resposta ao lead", "Com base na conversa, na empresa e na base de conhecimento, a IA propõe um texto que a pessoa edita e aprova.", "Assessor", "S"],
  ["Personalizar o 1º e-mail", "Ajusta o modelo ao segmento e ao contexto do lead.", "Assessor e aprovador", "S"],
  ["Resumir diagnósticos", "Transforma anotações da reunião em dores, oportunidades e serviços sugeridos da carta.", "Assessor", "C"],
  ["Tirar dúvidas internas", "Responde perguntas como \"como respondemos à objeção de preço?\" ou \"qual case de PCP usar?\" consultando a base.", "Todos", "S"],
  ["Enriquecer leads", "Extrai do site público informações como segmento, porte e possível decisor.", "Automação (F11)", "S"],
], [2200, 4600, 1800, 1000], { boldFirst: true, size: 16 }));
add(H2("10.2 Base de conhecimento"));
add(P("A IA responde com base em conteúdo da própria Aprimora, guardado no Supabase com busca semântica (pgvector). Essa técnica se chama RAG: antes de responder, o sistema busca os trechos mais relevantes da base e os entrega à IA como contexto."));
add(bullets([
  "Carta de Serviços (já disponível) e descrição detalhada de cada serviço.",
  "Perguntas frequentes de leads e respostas aprovadas.",
  "Objeções comuns e como contorná-las.",
  "Cases de projetos anteriores (sem dados sensíveis de clientes).",
  "Modelos de e-mail e scripts de coldcall.",
]));
add(H2("10.3 Provedor e custo"));
add(P("O portal terá uma **camada própria de IA** (um único módulo no código), o que permite trocar de provedor sem mexer no resto do sistema. No piloto será usado um provedor com **plano gratuito** (exemplo: Google Gemini API). Com orçamento aprovado, a diretoria pode migrar para um provedor pago com melhor qualidade e garantias contratuais de privacidade."));
add(callout("Atenção: privacidade nos planos gratuitos", [
  "Alguns planos gratuitos de IA podem usar os dados enviados para melhorar os próprios produtos. No piloto, a IA receberá **apenas o mínimo necessário** (sem CPF, dados financeiros ou informações sensíveis de clientes), e os termos do provedor escolhido serão revisados antes do uso.",
], "warn"));
add(H2("10.4 Regras de uso da IA"));
add(numbered([
  "**Nenhum texto gerado por IA é enviado a um lead sem aprovação humana.**",
  "Todo conteúdo sugerido pela IA é marcado como tal no portal.",
  "As classificações automáticas podem ser corrigidas pelo responsável, e as correções servem para melhorar os prompts.",
  "Prompts e modelos usados ficam versionados no repositório.",
]));

// ---------- 11. Arquitetura ----------
add(H1("11. Arquitetura técnica"));
add(figure("arquitetura.png", 3200, 1280, "Figura 3: Visão geral da arquitetura"));
add(H2("11.1 Tecnologias escolhidas"));
add(table(["Camada", "Tecnologia", "Por que"], [
  ["Linguagem", "TypeScript", "Tipagem evita erros e serve de documentação; a mesma linguagem no front e no back."],
  ["Framework web", "Next.js (App Router) + React", "Framework React mais usado e mais documentado, nativo na Vercel. Facilita que futuros membros encontrem tutoriais e ajuda."],
  ["Interface", "Tailwind CSS + shadcn/ui", "Componentes acessíveis e reaproveitáveis do protótipo; identidade visual por tokens."],
  ["Banco, autenticação e arquivos", "Supabase (Postgres, Auth, RLS, Storage, pg_cron, pgvector)", "Plano gratuito generoso, segurança no banco, SQL padrão e migrações versionadas. Já usado no protótipo."],
  ["Automação", "N8N", "Fluxos visuais que pessoas sem formação em programação conseguem manter. Integra Gmail e IA."],
  ["PWA", "Manifesto + service worker (Serwist) + Web Push", "App instalável com notificações, sem lojas."],
  ["Gráficos", "Recharts", "Já usado no protótipo; simples."],
  ["Validação", "Zod + React Hook Form", "Formulários com validação no cliente e no servidor."],
  ["Testes", "Vitest + Playwright", "Testes de regras de negócio e fluxos principais."],
  ["Hospedagem", "Vercel (piloto) e domínio próprio depois", "Deploy manual pela diretoria; nenhum deploy automático neste projeto."],
], [2100, 3000, 4500], { boldFirst: true, size: 16 }));
add(callout("Por que não continuar com o código do protótipo?", [
  "O protótipo usa TanStack Start acoplado ao Lovable, que não será mais usado, e tem falhas estruturais (Anexo C). Vamos **reaproveitar o aprendizado, a identidade visual, os componentes de interface e o padrão de segurança no banco**, mas começar um repositório limpo, com arquitetura pensada para várias diretorias.",
]));
add(H2("11.2 Modelo de dados (principais entidades)"));
add(table(["Entidade", "Descrição", "Campos principais"], [
  ["diretorias", "As 5 diretorias", "nome, slug, ativa"],
  ["membros (profiles)", "Pessoas com acesso", "nome, e-mail, diretoria, cargo (diretor, assessor, trainee), ativo, foto"],
  ["convites", "Convites pendentes", "e-mail, diretoria, cargo, token, expira_em, convidado_por"],
  ["empresas", "Clientes e prospects", "razão social, nome fantasia, CNPJ, segmento, porte, cidade, site, redes"],
  ["contatos", "Pessoas das empresas", "empresa, nome, cargo, decisor, e-mails, telefone, opt-out"],
  ["funis e fases", "Configuração do funil", "diretoria, nome, ordem, macroetapa, SLA, ação de SLA, probabilidade, campos obrigatórios"],
  ["negocios", "Cards do funil", "empresa, contato principal, responsável, fase, valor, origem, entrou_na_fase_em, status"],
  ["negocio_historico", "Movimentações", "negócio, fase de origem, fase de destino, autor, data, motivo"],
  ["negocio_campos", "Valores dos campos por fase", "negócio, campo, valor (JSON tipado)"],
  ["negocio_participantes", "Pessoas no negócio", "negócio, membro, papel"],
  ["servicos e negocio_servicos", "Catálogo da carta", "área (negócios, produção, qualidade), nome, descrição"],
  ["atividades", "Visitas, ligações, reuniões", "tipo, data, status, empresa, negócio, resumo, próximos passos"],
  ["atividade_participantes", "Quem participou", "atividade, membro"],
  ["eventos (agenda)", "Compromissos", "título, início, fim, tipo, local, convidados, atividade vinculada"],
  ["tarefas e tarefa_responsaveis", "Checklist", "título, descrição, prazo, prioridade, status, negócio"],
  ["metas", "Metas trimestrais", "trimestre, diretoria, membro (opcional), indicador, alvo, peso, método"],
  ["email_modelos, email_cadencias, email_mensagens", "Cadência de e-mail", "modelo e versão, negócio, etapa, IDs do Gmail, status, classificação, datas"],
  ["notificacoes e push_assinaturas", "Avisos", "membro, tipo, mensagem, link, lida; endpoint do push"],
  ["conhecimento e conhecimento_trechos", "Base da IA", "título, categoria, conteúdo, vetor (pgvector)"],
  ["automacao_logs", "Rastro do N8N", "fluxo, entidade, status, mensagem, data"],
  ["auditoria", "Ações sensíveis", "autor, ação, entidade, antes, depois, data"],
  ["projetos_entrada, financeiro_entrada", "Caixas de entrada pós-venda", "negócio, valor, escopo, status"],
], [2600, 2300, 4700], { boldFirst: true, size: 15 }));
add(H2("11.3 Segurança"));
add(bullets([
  "**RLS em todas as tabelas**, com funções auxiliares como `eh_diretor_de(diretoria)`, `mesma_diretoria()` e `participa_do_negocio()`.",
  "**Papéis definidos só por diretores**, por convite. Gatilhos impedem que alguém altere o próprio cargo ou diretoria.",
  "**Chaves secretas nunca no navegador**: a `service_role` do Supabase e as credenciais do N8N, Gmail e IA ficam apenas em variáveis de ambiente do servidor.",
  "**O arquivo `.env` nunca vai para o repositório**. Haverá um `.env.example` documentado.",
  "**Webhooks protegidos** por segredo compartilhado (assinatura HMAC) entre o portal e o N8N.",
  "**Auditoria** de ações sensíveis e **backups** (exportação semanal do banco no plano gratuito).",
  "**LGPD**: mínimo de dados pessoais, finalidade clara, lista de bloqueio, exclusão sob pedido e acesso restrito por perfil.",
]));
add(H2("11.4 Ambientes e limites do plano gratuito"));
add(table(["Serviço", "Plano", "Limites relevantes (verificar os valores atuais)", "Mitigação"], [
  ["Supabase", "Free", "500 MB de banco, 1 GB de arquivos; projeto pausa após 7 dias sem uso", "O uso diário evita a pausa; arquivos grandes ficam em link externo (Google Drive)"],
  ["Vercel", "Hobby", "Termos de uso restringem o plano gratuito a uso pessoal e não comercial", "Avaliar com a diretoria; alternativas: Vercel Pro, Netlify, Cloudflare Pages ou servidor próprio"],
  ["N8N", "Community (self-hosted)", "Depende da máquina", "VM gratuita + backup dos fluxos no Git"],
  ["Gmail Workspace", "Já contratado", "Cerca de 2.000 envios por dia por usuário", "Espaçar envios; monitorar devoluções"],
  ["IA", "Plano gratuito", "Limite de requisições por minuto e por dia; termos de uso de dados", "Fila de processamento; dados mínimos"],
], [1500, 1500, 3500, 3100], { boldFirst: true, size: 16 }));
add(H2("11.5 Organização do repositório"));
add(table(["Pasta", "Conteúdo"], [
  ["`app/`", "Páginas e rotas do Next.js, organizadas por módulo (comercial, configuracoes, auth)"],
  ["`components/`", "Componentes de interface reutilizáveis (inclui shadcn/ui)"],
  ["`lib/`", "Regras de negócio, cliente Supabase, camada de IA, utilitários"],
  ["`supabase/migrations/`", "Todas as mudanças de banco em SQL versionado"],
  ["`supabase/seed.sql`", "Dados iniciais: diretorias, fases do funil, serviços da carta"],
  ["`automacoes/n8n/`", "JSON dos fluxos do N8N e guia de instalação"],
  ["`docs/`", "Este escopo, decisões de arquitetura (ADRs), guia de contribuição e manual do usuário"],
  ["`tests/`", "Testes automatizados"],
], [2600, 7000]));
add(H2("11.6 Padrões de desenvolvimento"));
add(bullets([
  "Branch `main` protegida; cada mudança em uma branch própria com Pull Request revisado.",
  "Mensagens de commit no padrão **Conventional Commits** (`feat:`, `fix:`, `docs:`).",
  "**CI no GitHub Actions**: lint, checagem de tipos e testes em todo Pull Request.",
  "Toda mudança de banco é uma migração; ninguém altera o banco de produção à mão.",
  "Decisões importantes registradas como **ADR** (Architecture Decision Record) em `docs/adr`.",
  "Código e comentários em português nos nomes de domínio (negócio, fase, meta), para facilitar a leitura de futuros membros.",
]));

// ---------- 12. RNF ----------
add(H1("12. Requisitos não funcionais"));
add(table(["ID", "Requisito", "Critério de aceite"], [
  ["RNF-01", "Responsividade e PWA", "Funciona bem em celulares a partir de 360 px de largura; instalável no Android, iOS e desktop; ícone e tela de abertura com a marca."],
  ["RNF-02", "Desempenho", "Telas principais carregam em menos de 2 s numa conexão 4G; kanban com 300 cards sem travar."],
  ["RNF-03", "Segurança", "RLS em 100% das tabelas; nenhum segredo no front-end; análise de segurança (advisors do Supabase) sem alertas críticos."],
  ["RNF-04", "Disponibilidade", "Compatível com o plano gratuito; falhas de automação registradas e notificadas ao diretor."],
  ["RNF-05", "Idioma e fuso", "Interface 100% em pt-BR; datas no fuso America/Sao_Paulo; moeda em R$."],
  ["RNF-06", "Acessibilidade", "Contraste mínimo WCAG AA, navegação por teclado e rótulos em todos os campos."],
  ["RNF-07", "Manutenibilidade", "README de instalação em até 15 min, ADRs, cobertura de testes nas regras de cálculo de KPIs."],
  ["RNF-08", "Backup e recuperação", "Exportação semanal do banco e dos fluxos do N8N, com restauração testada uma vez por semestre."],
  ["RNF-09", "Privacidade (LGPD)", "Lista de bloqueio respeitada em 100% dos envios; exclusão de contato sob pedido em até 15 dias."],
  ["RNF-10", "Custo", "R$ 0 por mês no piloto."],
], [1000, 2300, 6300], { boldFirst: true, size: 16 }));

// ---------- 13. Identidade visual ----------
add(H1("13. Identidade visual do portal"));
add(P("A identidade segue a **logo oficial** (fundo azul com quadrados brancos e laranja) e a Carta de Serviços. Como não há manual de marca, este documento define os tokens abaixo como referência até que um manual seja criado pelo Marketing."));
add(table(["Token", "Cor", "Uso"], [
  ["Azul Aprimora", "#24476F", "Cor principal: menu lateral, cabeçalhos, botões principais, fundo da logo"],
  ["Azul profundo", "#1A3554", "Títulos e texto de destaque sobre fundo claro"],
  ["Laranja Aprimora", "#E8833A", "Destaques, alertas de SLA, chamadas para ação, gráficos"],
  ["Azul claro", "#97B9C6", "Elementos secundários e formas decorativas (como na Carta)"],
  ["Fundo suave", "#F2F5F9", "Fundos de cartões e tabelas"],
  ["Branco", "#FFFFFF", "Fundo principal no tema claro; logo sobre fundo azul"],
], [2200, 1600, 5800], { boldFirst: true }));
add(bullets([
  "**Tipografia**: Montserrat para títulos (como na Carta de Serviços) e Open Sans para textos. Ambas são gratuitas (Google Fonts).",
  "**Temas**: claro como padrão, alinhado à Carta, e escuro opcional em azul profundo, aproveitando o visual do protótipo.",
  "**Logo**: versão branca sobre azul no menu e na tela de login; versão quadrada oficial como ícone do PWA.",
  "**Elementos gráficos**: linhas diagonais e triângulos, como na Carta, usados com moderação em telas vazias e no login.",
]));

// ---------- 14. Roadmap ----------
add(H1("14. Plano de entregas"));
add(P("Não há prazo fixo, mas há **prioridade**: o Comercial termina primeiro. As fases são incrementais. Cada uma entrega algo utilizável e é validada pelo Diretor Comercial antes da próxima. Tamanho estimado: **P** (pequeno), **M** (médio), **G** (grande)."));
add(table(["Fase", "Nome", "Entregas", "Critério de aceite", "Tam."], [
  ["0", "Fundação", "Repositório, stack, design system, autenticação por convite, diretorias e cargos, RLS base, CI, documentação inicial.", "Diretor convida um assessor, que acessa e só vê o que deve; CI verde.", "M"],
  ["1", "CRM e funil", "Empresas, contatos, importação CSV, funil com fases do Pipefy, campos por fase, histórico, saídas, anexos, configurações, migração do Pipefy.", "Todos os cards ativos do Pipefy estão no portal e a equipe opera o funil só por ele.", "G"],
  ["2", "Atividades e rotina", "Visitas e atividades, agenda, tarefas, notificações no app e push, transferência de carteira, auditoria.", "Uma semana de trabalho registrada inteiramente no portal.", "M"],
  ["3", "Indicadores e metas", "Views de KPIs, painéis pessoal e da diretoria, metas automáticas, importação das metas atuais, exportação.", "Metas do trimestre calculadas sem digitação e conferidas pelo diretor.", "M"],
  ["4", "Automações básicas", "N8N no ar; lembretes, SLA, reciclagem, resumo semanal, passagem do ganho, distribuição de responsável.", "Resumo semanal chega por 2 semanas seguidas; ganho gera registros em Projetos e Presidência.", "M"],
  ["5", "Cadência de e-mail", "Modelos, fila de aprovação, envio via Gmail, monitoramento, classificação por IA, follow-ups, painel de cadência, lista de bloqueio.", "Ciclo completo testado com leads reais, sem envio fora da regra.", "G"],
  ["6", "Extração e IA", "Fluxos de extração e enriquecimento, base de conhecimento, assistente de respostas, resumo de diagnóstico.", "Lote de leads extraído sem duplicados; respostas sugeridas avaliadas como úteis pela equipe.", "G"],
  ["7", "Piloto e avaliação", "Uso real por todo o Comercial, coleta dos critérios da Seção 3.3 e apresentação aos diretores.", "Relatório de avaliação e decisão sobre investimento.", "P"],
  ["8+", "Expansão", "Módulos de Projetos, Presidência, RH e Marketing, cada um com escopo próprio.", "Escopo específico aprovado por cada diretoria.", "—"],
], [600, 1500, 3700, 3100, 700], { size: 16 }));
add(callout("Marco intermediário sugerido", "Ao fim da Fase 3, o portal já resolve o maior gargalo (metas automáticas e indicadores do funil). É um bom momento para uma primeira demonstração aos outros diretores, mesmo antes das automações de e-mail."));

// ---------- 15. Riscos ----------
add(H1("15. Riscos e mitigação"));
add(table(["Risco", "Prob.", "Impacto", "Mitigação"], [
  ["Rotatividade: quem desenvolve sai da EJ", "Alta", "Alto", "Documentação no repositório, ADRs, código simples e em português, passagem de bastão formal (Seção 16)."],
  ["Baixa adesão da equipe (dados incompletos)", "Média", "Alto", "Campos obrigatórios só onde necessário, registro rápido pelo celular, metas e KPIs dependem do uso, treinamento."],
  ["Limites e regras dos planos gratuitos (pausa do Supabase, termos da Vercel Hobby)", "Média", "Médio", "Monitorar o uso, alternativas mapeadas na Seção 11.4, decisão de investimento após o piloto."],
  ["Reputação do domínio por envio em massa", "Média", "Alto", "Aprovação humana, limites por hora, SPF, DKIM e DMARC, lista de bloqueio, monitorar devoluções."],
  ["Questões de LGPD na extração de leads", "Média", "Alto", "Fontes legítimas, base legal documentada, descadastro em todos os e-mails, sem raspar redes sociais."],
  ["IA gera conteúdo inadequado", "Média", "Médio", "Nada é enviado sem aprovação; base de conhecimento curada; prompts versionados."],
  ["Escopo crescer antes de terminar o Comercial", "Alta", "Médio", "Este documento define o que fica fora; mudanças passam por nova versão aprovada."],
  ["Transição do Pipefy gerar dados em dois lugares", "Média", "Médio", "Data de corte definida; migração dos cards ativos; Pipefy só para consulta após o corte."],
], [3000, 900, 1000, 4700], { boldFirst: true, size: 16 }));

// ---------- 16. Governança ----------
add(H1("16. Governança e manutenção"));
add(H2("16.1 Papéis"));
add(table(["Papel", "Quem", "Responsabilidades"], [
  ["Dono do produto", "Diretor Comercial (ou o diretor dono de cada módulo, no futuro)", "Prioriza demandas, aprova versões do escopo e valida entregas."],
  ["Mantenedor técnico", "Membro(s) designado(s) pela diretoria", "Desenvolve, revisa Pull Requests, cuida do deploy manual, dos backups e do N8N."],
  ["Usuários-chave", "1 assessor por diretoria", "Testam novidades, coletam feedback e ajudam a treinar novos membros."],
  ["Comitê de diretores", "Os 5 diretores", "Decide investimentos e a expansão para novas diretorias."],
], [2000, 3200, 4400], { boldFirst: true }));
add(H2("16.2 Como pedir mudanças"));
add(numbered([
  "Abrir uma **issue** no GitHub com o modelo de pedido (problema, quem é afetado, sugestão).",
  "O dono do produto prioriza (MoSCoW) e associa a uma fase ou versão.",
  "Mudanças de escopo relevantes geram nova versão deste documento.",
]));
add(H2("16.3 Passagem de bastão"));
add(P("Na troca de diretoria ou de mantenedor, faça uma **reunião de transição** usando este checklist:"));
add(bullets([
  "Transferir a propriedade e o acesso de administrador do repositório, do Supabase, da Vercel, do N8N e do Google Cloud para contas da Aprimora (nunca contas pessoais).",
  "Revisar este documento e as ADRs com quem chega.",
  "Rodar o projeto localmente seguindo o README.",
  "Testar a restauração de backup.",
  "Atualizar a lista de diretores e mantenedores no `README`.",
]));
add(callout("Recomendação importante", "Todas as contas de serviço (GitHub, Supabase, Vercel, N8N, Google Cloud) devem pertencer a um e-mail institucional da Aprimora, como ti@aprimoraej.com ou o e-mail da diretoria, e não ao e-mail pessoal de um membro. Isso garante que o patrimônio continue com a empresa júnior quando as pessoas saírem.", "warn"));

// ---------- 17. Decisões em aberto ----------
add(H1("17. Decisões em aberto"));
add(P("Os pontos abaixo precisam de definição da diretoria. Cada um traz uma **proposta padrão**, que será adotada se não houver decisão contrária até a fase indicada."));
add(table(["#", "Decisão", "Proposta padrão", "Até a fase"], [
  ["D1", "Quem aprova o 1º e-mail da cadência?", "O responsável aprova os próprios; o diretor pode exigir sua aprovação por configuração.", "5"],
  ["D2", "Conta de envio dos e-mails", "Conta Workspace de cada assessor (mais pessoal e melhor entregabilidade), com comercial@ em cópia oculta.", "5"],
  ["D3", "Assessor vê os negócios da equipe?", "Sim, em leitura (Seção 5.3).", "1"],
  ["D4", "Permissões do trainee", "Igual ao assessor, sem marcar ganho e sem excluir registros.", "0"],
  ["D5", "Data de corte do Pipefy", "Ao fim da Fase 1, com migração dos cards ativos.", "1"],
  ["D6", "Os 7 campos restantes do Formulário inicial e os campos de Enriquecimento e Coleta de dados", "Levantar no Pipefy e completar o Anexo B.", "1"],
  ["D7", "Valores de SLA por fase e lista de motivos de perda", "Usar os valores atuais do Pipefy; lista inicial de motivos no Anexo B.", "1"],
  ["D8", "Cálculo de \"Diagnósticos marcados\"", "Entrada na fase Diagnóstico.", "3"],
  ["D9", "Como medir \"Desenvolvimento dos membros\"", "Manual até existir o módulo de RH.", "3"],
  ["D10", "Hospedagem do N8N", "N8N Community em VM gratuita.", "4"],
  ["D11", "Provedor de IA do piloto", "Provedor com plano gratuito, enviando dados mínimos.", "5"],
  ["D12", "Plano da Vercel e domínio definitivo", "Piloto na Vercel; domínio portal.aprimoraej.com após aprovação.", "7"],
  ["D13", "Conta institucional para os serviços", "Criar um e-mail institucional dono de todas as contas.", "0"],
  ["D14", "Intervalos dos follow-ups", "D+3, D+7 e D+14 após o 1º envio.", "5"],
], [600, 3300, 4600, 1100], { size: 16 }));

// ---------- Anexos ----------
add(H1("Anexo A: Catálogo de serviços"));
add(P("Extraído da Carta de Serviços. No portal, estes serviços são cadastrados como referência para os negócios. Cada projeto tem escopo e valor únicos."));
add(table(["Área", "Serviço", "Descrição resumida"], [
  ["Negócios", "Pesquisa de Mercado", "Obtenção e análise de dados sobre clientes, fornecedores e concorrentes para o planejamento estratégico."],
  ["Negócios", "Gestão de Custos", "Relação entre lucratividade e gastos; formação de mark-up; análise custo-volume-lucro."],
  ["Negócios", "Planejamento Estratégico", "Definição de metas, planos de ação, posicionamento e cultura organizacional."],
  ["Negócios", "Gestão de Indicadores", "Definição, estruturação e acompanhamento de métricas com painéis visuais."],
  ["Produção", "Cronoanálise", "Análise e padronização dos tempos de execução dos processos."],
  ["Produção", "Mapeamento de Processos", "Estruturação do fluxo de processos e esquematização dos procedimentos."],
  ["Produção", "Otimização de Processos", "Identificação e eliminação de falhas e padronização de rotinas."],
  ["Produção", "Análise de Layout e Arranjo Físico", "Melhor aproveitamento do espaço por reposicionamento de máquinas, equipamentos e pessoas."],
  ["Produção", "Planejamento e Controle da Produção (PCP)", "Sincronização de fornecimento, produção e demanda."],
  ["Qualidade", "Gestão de Estoque", "Controle do fluxo e armazenamento de materiais; inventário."],
  ["Qualidade", "Gestão de Desperdício", "Redução de tudo que consome recursos sem agregar valor."],
  ["Qualidade", "Aplicação do 5S", "Cultura de organização, limpeza, padronização e autodisciplina."],
], [1500, 3000, 5100], { boldFirst: true, size: 16 }));

add(H1("Anexo B: Campos do funil (levantamento do Pipefy)"));
add(P("Levantamento feito a partir das capturas de tela do Pipefy. Os itens marcados como **a completar** dependem da decisão D6."));
add(table(["Fase", "Campos", "Tipo"], [
  ["Formulário inicial", "Nome da empresa; número de telefone; e-mail principal; e-mail secundário; e-mail terciário; segmento; decisor; rede social; + 7 campos (a completar)", "Texto, telefone, e-mail"],
  ["Entrada de leads", "Sem campos próprios (automação para Enriquecimento)", "—"],
  ["Enriquecimento", "Sem campos próprios no Pipefy (a completar: decisor, cargo, LinkedIn, site)", "—"],
  ["Coleta de dados", "Sem campos próprios no Pipefy (a completar)", "—"],
  ["E-mail", "Etapa de e-mail; data do 1º envio; data do follow-up 1; data do follow-up 2; data do follow-up 3", "Seleção, datas (preenchidas automaticamente pelo portal)"],
  ["Coldcall semanas 1 e 2", "Sem campos próprios (proposta: registro de ligações como atividade)", "—"],
  ["Retornar futuro", "Retornar (data); retorna para qual decisor", "Data, texto"],
  ["Oportunidade", "SLA; qual a oportunidade", "Data, texto longo"],
  ["Diagnóstico", "Data marcada; dores coletadas na ligação; decisor contatado", "Data, texto longo, texto"],
  ["Elaboração de escopo", "Data limite para elaboração; arquivo do escopo; responsáveis pela elaboração", "Data, anexo, membros"],
  ["Apresentação de proposta", "Data da apresentação; quem apresentou a proposta; decisores presentes", "Data, membros, texto"],
  ["Projetos Aprimora", "Apresentação da proposta; declaração de escopo; projeto; fases do projeto; gerente do projeto; assessores do projeto; oportunidades de melhoria", "Anexos, textos, membros"],
  ["Reciclagem", "SLA de reciclagem; etiqueta", "Data, etiqueta"],
  ["Projeto não vendido", "Motivo de não ter vendido", "Lista + texto"],
  ["Lead não qualificado", "Sem campos (proposta: motivo da desqualificação)", "Lista + texto"],
], [2200, 5300, 2100], { boldFirst: true, size: 16 }));
add(H3("Lista inicial sugerida de motivos de perda"));
add(bullets([
  "Preço ou orçamento insuficiente",
  "Sem prioridade no momento (timing)",
  "Escolheu concorrente ou consultoria sênior",
  "Decisor não engajado",
  "Escopo fora da atuação da Aprimora",
  "Sem retorno após a proposta",
  "Outro (descrever)",
]));

add(H1("Anexo C: Diagnóstico do protótipo atual"));
add(P("Análise do repositório `Maroto-Aprimora/Portal-Comercial` (setembro de 2026), feito no Lovable com TanStack Start, React 19, Tailwind e Supabase."));
add(H2("C.1 O que aproveitar"));
add(bullets([
  "Conceito dos módulos (painel, funil, visitas, metas, checklist, agenda) e a validação de uso pela equipe.",
  "Padrão de segurança no banco com `has_role()` e funções `SECURITY DEFINER`.",
  "Gatilho que atualiza a data de entrada na fase (`stage_entered_at`).",
  "Componentes shadcn/ui e o alerta de negócios parados no sino.",
  "Visitas com vários membros e stakeholder; tarefas com vários responsáveis.",
]));
add(H2("C.2 Problemas encontrados"));
add(table(["Gravidade", "Problema", "Como o novo portal resolve"], [
  ["Crítica", "Qualquer pessoa pode se cadastrar como Diretor: o cadastro é aberto e a função `handle_new_user` aceita o perfil enviado pelo próprio navegador (`perfil: \"diretor\"`).", "Sem cadastro aberto; perfil definido só por convite de diretor; gatilhos bloqueiam a autoalteração."],
  ["Alta", "Arquivo `.env` versionado em repositório público.", "`.env` no `.gitignore` e `.env.example`; revisar e trocar as chaves do projeto antigo se necessário."],
  ["Alta", "Metas com progresso digitado à mão.", "Metas derivadas dos dados (Seção 8)."],
  ["Alta", "Sem histórico de fases: impossível medir conversão e tempo por fase.", "Tabela `negocio_historico` alimentada por gatilho."],
  ["Média", "Funil simplificado (5 fases), diferente do Pipefy; sem etapas de perda e reciclagem nem motivo.", "Funil configurável com as fases do Pipefy e saídas com motivo."],
  ["Média", "Membros 2 a 4 de uma visita não enxergam a visita (RLS só pelo membro principal); colunas fixas `membro_2_id`…`membro_4_id`.", "Tabela de participantes e RLS por participação."],
  ["Média", "E-mails de todos os usuários visíveis para todos; agenda sem restrição.", "Visibilidade por diretoria e cargo."],
  ["Baixa", "Empresa digitada como texto livre no negócio e na visita, sem vínculo com o cadastro.", "Chave estrangeira obrigatória para empresa, com detecção de duplicidade."],
  ["Baixa", "Prazo de alerta fixo no código (7 dias).", "SLA configurável por fase."],
  ["Baixa", "Acoplamento ao Lovable (plugins e configuração).", "Stack independente e documentada."],
], [1200, 4400, 4000], { size: 16 }));

add(H1("Anexo D: Glossário"));
add(table(["Termo", "Significado"], [
  ["ADR", "Architecture Decision Record: documento curto que registra uma decisão técnica e o porquê."],
  ["API", "Interface que permite que sistemas conversem entre si (por exemplo, o N8N falar com o portal)."],
  ["Cadência", "Sequência planejada de contatos com o lead (e-mails e ligações) em intervalos definidos."],
  ["Coldcall / Coldmail", "Ligação ou e-mail para um lead que ainda não conhece a Aprimora."],
  ["EJ", "Empresa Júnior."],
  ["Follow-up", "Contato de acompanhamento após uma mensagem sem resposta."],
  ["Funil (pipeline)", "Sequência de fases pelas quais um lead passa até virar cliente."],
  ["ICP", "Ideal Customer Profile: perfil de cliente ideal."],
  ["KPI", "Key Performance Indicator: indicador-chave de desempenho."],
  ["Lead", "Empresa ou pessoa com potencial de virar cliente."],
  ["LGPD", "Lei Geral de Proteção de Dados (Lei 13.709/2018)."],
  ["Migração", "Arquivo SQL versionado que altera a estrutura do banco de forma controlada."],
  ["MoSCoW", "Método de priorização: Must, Should, Could, Won't."],
  ["MVP", "Minimum Viable Product: primeira versão com o essencial para gerar valor."],
  ["N8N", "Ferramenta de automação de fluxos com interface visual."],
  ["Pipeline ponderado", "Valor dos negócios abertos multiplicado pela probabilidade de fechamento de cada etapa."],
  ["PWA", "Progressive Web App: site que se instala como aplicativo no celular."],
  ["RAG", "Técnica em que a IA consulta uma base de conhecimento antes de responder."],
  ["RLS", "Row Level Security: regras no banco que definem quem vê e altera cada linha."],
  ["SLA", "Prazo máximo que um card pode ficar em uma fase."],
  ["Supabase", "Plataforma que oferece banco Postgres, autenticação, arquivos e funções."],
  ["Ticket médio", "Valor médio dos projetos vendidos."],
  ["Vercel", "Serviço de hospedagem de aplicações web."],
  ["Webhook", "Endereço que um sistema chama para avisar outro sobre um evento."],
  ["Win rate", "Taxa de ganho entre as propostas apresentadas."],
], [2200, 7400], { boldFirst: true, size: 17 }));

add({ t: "closing" });

module.exports = { VERSAO, DATA, blocos: corpo };
