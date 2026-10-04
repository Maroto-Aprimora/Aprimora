-- Configuração inicial do funil comercial (espelha o pipe do Pipefy remodelado em 2026),
-- catálogo de serviços (Carta de Serviços), cadastros de apoio e metas de 2026.
-- Tudo aqui pode ser alterado depois pelo Diretor Comercial em Configurações.

insert into public.funis (diretoria, chave, nome) values ('comercial', 'comercial', 'Funil Comercial');

with f as (select id from public.funis where diretoria = 'comercial' and chave = 'comercial')
insert into public.fases (funil_id, chave, nome, ordem, macroetapa, tipo, probabilidade, distribui_responsavel, exige_motivo, descricao)
select f.id, v.chave, v.nome, v.ordem, v.macro::public.macroetapa, v.tipo::public.tipo_fase, v.prob, v.distrib, v.motivo::public.tipo_motivo, v.descr
from f, (values
  ('entrada',         'Entrada de leads',          1, 'prospeccao',   'aberta', 0,    false, null, 'Leads novos ou importados. Vão automaticamente para Enriquecimento.'),
  ('enriquecimento',  'Enriquecimento',            2, 'prospeccao',   'aberta', 0,    false, null, 'Completar dados do decisor e dos contatos.'),
  ('coleta',          'Coleta de dados concluída', 3, 'prospeccao',   'aberta', 0,    false, null, 'Dados validados, pronto para a abordagem.'),
  ('email',           'E-mail',                    4, 'cadencia',     'aberta', 0,    true,  null, 'Primeiro contato e follow-ups. Responsável distribuído por rodízio.'),
  ('coldcall_1',      'Coldcall (semana 1)',       5, 'cadencia',     'aberta', 0,    false, null, 'Primeira rodada de ligações.'),
  ('coldcall_2',      'Coldcall (semana 2)',       6, 'cadencia',     'aberta', 0,    false, null, 'Segunda rodada de ligações.'),
  ('retornar',        'Retornar futuro',           7, 'cadencia',     'aberta', 0,    false, null, 'O lead pediu contato em outro momento.'),
  ('oportunidade',    'Oportunidade',              8, 'oportunidade', 'aberta', 0.10, false, null, 'Lead com interesse. Agendar o diagnóstico em até 15 dias.'),
  ('diagnostico',     'Diagnóstico agendado',      9, 'venda',        'aberta', 0.25, false, null, 'Reunião de diagnóstico para entender as dores.'),
  ('escopo',          'Elaboração de escopo',     10, 'venda',        'aberta', 0.50, false, null, 'Construção do escopo e do valor.'),
  ('proposta',        'Apresentação de proposta', 11, 'venda',        'aberta', 0.70, false, null, 'Proposta apresentada; negociação.'),
  ('ganho',           'Projetos Aprimora',        12, 'ganho',        'ganho',  1,    false, null, 'Projeto vendido. Segue para Projetos e Presidência.'),
  ('reciclagem',      'Reciclagem',               13, 'pausa',        'pausa',  0,    false, null, 'Lead esfriou. Volta ao funil na data de retorno.'),
  ('nao_vendido',     'Projeto não vendido',      14, 'perda',        'perda',  0,    false, 'perda', 'Proposta não convertida. Motivo obrigatório.'),
  ('nao_qualificado', 'Lead não qualificado',     15, 'perda',        'perda',  0,    false, 'desqualificacao', 'Fora do perfil. Motivo obrigatório.')
) as v(chave, nome, ordem, macro, tipo, prob, distrib, motivo, descr);

-- Automações herdadas do Pipefy
update public.fases set auto_mover_para = (select id from public.fases where chave = 'enriquecimento')
  where chave = 'entrada';
update public.fases set sla_dias = 15, acao_sla = 'mover', fase_destino_sla = (select id from public.fases where chave = 'email')
  where chave = 'oportunidade';
update public.fases set fase_destino_sla = (select id from public.fases where chave = 'enriquecimento')
  where chave = 'reciclagem';

-- Campos por fase (levantados do Pipefy; ver docs/escopo, Anexo B)
insert into public.fase_campos (fase_id, chave, rotulo, tipo, opcoes, obrigatorio, ordem)
select fa.id, v.chave, v.rotulo, v.tipo::public.tipo_campo, v.opcoes::jsonb, v.obrig, v.ordem
from (values
  ('email', 'etapa_email', 'Etapa de e-mail', 'selecao', '["1º envio","Follow-up 1","Follow-up 2","Follow-up 3","Respondeu"]', false, 1),
  ('email', 'data_1_envio', 'Data do 1º envio', 'data', null, false, 2),
  ('email', 'data_follow_up_1', 'Data do follow-up 1', 'data', null, false, 3),
  ('email', 'data_follow_up_2', 'Data do follow-up 2', 'data', null, false, 4),
  ('email', 'data_follow_up_3', 'Data do follow-up 3', 'data', null, false, 5),
  ('retornar', 'retornar_em', 'Retornar em', 'data', null, true, 1),
  ('retornar', 'retorna_para_decisor', 'Retorna para qual decisor', 'texto', null, false, 2),
  ('oportunidade', 'qual_oportunidade', 'Qual a oportunidade?', 'texto_longo', null, true, 1),
  ('diagnostico', 'data_marcada', 'Data marcada', 'data', null, true, 1),
  ('diagnostico', 'dores_coletadas', 'Dores coletadas na ligação', 'texto_longo', null, false, 2),
  ('diagnostico', 'decisor_contatado', 'Decisor contatado', 'texto', null, false, 3),
  ('escopo', 'data_limite', 'Data limite para elaboração', 'data', null, false, 1),
  ('escopo', 'arquivo_escopo', 'Arquivo do escopo (link)', 'link', null, false, 2),
  ('escopo', 'responsaveis_elaboracao', 'Responsáveis pela elaboração', 'membros', null, false, 3),
  ('proposta', 'data_apresentacao', 'Data da apresentação', 'data', null, true, 1),
  ('proposta', 'quem_apresentou', 'Quem apresentou a proposta', 'membros', null, false, 2),
  ('proposta', 'decisores_presentes', 'Decisores que estavam presentes', 'texto', null, false, 3),
  ('ganho', 'apresentacao_proposta', 'Apresentação da proposta (link)', 'link', null, false, 1),
  ('ganho', 'declaracao_escopo', 'Declaração de escopo (link)', 'link', null, false, 2),
  ('ganho', 'projeto', 'Projeto', 'texto', null, false, 3),
  ('ganho', 'fases_projeto', 'Fases do projeto', 'texto_longo', null, false, 4),
  ('ganho', 'gerente_projeto', 'Gerente do projeto', 'membros', null, false, 5),
  ('ganho', 'assessores_projeto', 'Assessores do projeto', 'membros', null, false, 6),
  ('ganho', 'oportunidades_melhoria', 'Oportunidades de melhoria', 'texto_longo', null, false, 7),
  ('reciclagem', 'etiqueta', 'Etiqueta', 'texto', null, false, 1)
) as v(fase, chave, rotulo, tipo, opcoes, obrig, ordem)
join public.fases fa on fa.chave = v.fase;

insert into public.segmentos (nome) values
  ('Agronegócio'), ('Alimentos e bebidas'), ('Automotivo'), ('Comércio e varejo'), ('Construção civil'),
  ('Educação'), ('Embalagens'), ('Indústria (outros)'), ('Logística e transporte'), ('Metalmecânico'),
  ('Moveleiro'), ('Químico e plástico'), ('Saúde'), ('Serviços'), ('Tecnologia'), ('Têxtil e confecção'), ('Outro');

insert into public.origens (nome, ordem) values
  ('Indicação', 1), ('Instagram', 2), ('Eventos', 3), ('Prospecção ativa', 4), ('Site', 5),
  ('Extração em massa', 6), ('Pós-vendas', 7), ('LinkedIn', 8), ('Outro', 9);

insert into public.servicos (area, nome, descricao, ordem) values
  ('negocios', 'Pesquisa de Mercado', 'Obtenção e análise de dados sobre clientes, fornecedores e concorrentes para o planejamento estratégico.', 1),
  ('negocios', 'Gestão de Custos', 'Relação entre lucratividade e gastos; formação de mark-up; análise custo-volume-lucro.', 2),
  ('negocios', 'Planejamento Estratégico', 'Definição de metas, planos de ação, posicionamento e cultura organizacional.', 3),
  ('negocios', 'Gestão de Indicadores', 'Definição, estruturação e acompanhamento de métricas com painéis visuais.', 4),
  ('producao', 'Cronoanálise', 'Análise e padronização dos tempos de execução dos processos.', 5),
  ('producao', 'Mapeamento de Processos', 'Estruturação do fluxo de processos e esquematização dos procedimentos.', 6),
  ('producao', 'Otimização de Processos', 'Identificação e eliminação de falhas e padronização de rotinas.', 7),
  ('producao', 'Análise de Layout e Arranjo Físico', 'Melhor aproveitamento do espaço por reposicionamento de máquinas, equipamentos e pessoas.', 8),
  ('producao', 'Planejamento e Controle da Produção (PCP)', 'Sincronização de fornecimento, produção e demanda.', 9),
  ('qualidade', 'Gestão de Estoque', 'Controle do fluxo e armazenamento de materiais; inventário.', 10),
  ('qualidade', 'Gestão de Desperdício', 'Redução de tudo que consome recursos sem agregar valor.', 11),
  ('qualidade', 'Aplicação do 5S', 'Cultura de organização, limpeza, padronização e autodisciplina.', 12);

insert into public.motivos (tipo, nome, ordem) values
  ('perda', 'Preço ou orçamento insuficiente', 1),
  ('perda', 'Sem prioridade no momento (timing)', 2),
  ('perda', 'Escolheu concorrente ou consultoria sênior', 3),
  ('perda', 'Decisor não engajado', 4),
  ('perda', 'Escopo fora da atuação da Aprimora', 5),
  ('perda', 'Sem retorno após a proposta', 6),
  ('perda', 'Outro', 99),
  ('desqualificacao', 'Fora do perfil de cliente', 1),
  ('desqualificacao', 'Sem contato válido', 2),
  ('desqualificacao', 'Empresa encerrada', 3),
  ('desqualificacao', 'Lead duplicado', 4),
  ('desqualificacao', 'Sem interesse declarado', 5),
  ('desqualificacao', 'Outro', 99);

-- Metas do Comercial em 2026 (planilha "Planejamento Estratégico Aprimora", abas de 2026).
-- Valores realizados registrados manualmente; o cálculo automático entra na Fase 3.
insert into public.metas (diretoria, trimestre, objetivo, codigo, titulo, alvo, unidade, realizado_manual, ordem) values
  ('comercial', '1T2026', 'Faturamento / Mercado / Pós-Vendas', '4.1.1', 'Faturamento da meta', 40000, 'R$', 0, 1),
  ('comercial', '1T2026', 'Faturamento / Mercado / Pós-Vendas', '4.1.2', 'Diagnósticos marcados', 7, 'un', 6, 2),
  ('comercial', '1T2026', 'Faturamento / Mercado / Pós-Vendas', '4.1.3', 'Diagnósticos marcados fora de Londrina', 2, 'un', 1, 3),
  ('comercial', '1T2026', 'Faturamento / Mercado / Pós-Vendas', '4.1.4', 'Diagnósticos oriundos de pós-vendas', 2, 'un', 1, 4),
  ('comercial', '1T2026', 'Faturamento / Mercado / Pós-Vendas', '4.1.5', 'Contratos fechados', 2, 'un', 0, 5),
  ('comercial', '1T2026', 'Faturamento / Mercado / Pós-Vendas', '4.1.6', 'Propostas', 4, 'un', 3, 6),
  ('comercial', '1T2026', 'Membros e Time', '4.2.1', 'Benchs', 1, 'un', 1, 7),
  ('comercial', '1T2026', 'Membros e Time', '4.2.2', 'Treinamento de Projetos', 1, 'un', 1, 8),
  ('comercial', '1T2026', 'Membros e Time', '4.2.3', 'Roleplay', 1, 'un', 0, 9),
  ('comercial', '2T2026', 'Faturamento / Mercado / Pós-Vendas', '4.1.1', 'Faturamento da meta', 100000, 'R$', 0, 1),
  ('comercial', '2T2026', 'Faturamento / Mercado / Pós-Vendas', '4.1.2', 'Diagnósticos marcados', 16, 'un', 15, 2),
  ('comercial', '2T2026', 'Faturamento / Mercado / Pós-Vendas', '4.1.3', 'Diagnósticos marcados fora de Londrina', 2, 'un', 1, 3),
  ('comercial', '2T2026', 'Faturamento / Mercado / Pós-Vendas', '4.1.4', 'Diagnósticos oriundos de pós-vendas', 1, 'un', 1, 4),
  ('comercial', '2T2026', 'Faturamento / Mercado / Pós-Vendas', '4.1.5', 'Contratos fechados', 3, 'un', 0, 5),
  ('comercial', '2T2026', 'Faturamento / Mercado / Pós-Vendas', '4.1.6', 'Propostas', 10, 'un', 14, 6),
  ('comercial', '2T2026', 'Membros e Time', '4.2.1', 'Benchs', 1, 'un', 1, 7),
  ('comercial', '2T2026', 'Membros e Time', '4.2.2', 'Treinamento de Projetos', 3, 'un', 2, 8),
  ('comercial', '2T2026', 'Membros e Time', '4.2.3', 'Roleplay', 3, 'un', 0, 9),
  ('comercial', '3T2026', 'Faturamento / Mercado / Pós-Vendas', '4.1.1', 'Faturamento da meta', 100000, 'R$', 5540, 1),
  ('comercial', '3T2026', 'Faturamento / Mercado / Pós-Vendas', '4.1.2', 'Diagnósticos marcados', 16, 'un', 1, 2),
  ('comercial', '3T2026', 'Faturamento / Mercado / Pós-Vendas', '4.1.3', 'ProspectDay', 2, 'un', 2, 3),
  ('comercial', '3T2026', 'Faturamento / Mercado / Pós-Vendas', '4.1.4', 'Diagnósticos marcados por membros novos', 4, 'un', 0, 4),
  ('comercial', '3T2026', 'Faturamento / Mercado / Pós-Vendas', '4.1.5', 'Contratos fechados', 3, 'un', 2, 5),
  ('comercial', '3T2026', 'Faturamento / Mercado / Pós-Vendas', '4.1.6', 'Propostas', 10, 'un', 6, 6),
  ('comercial', '3T2026', 'Membros e Time', '4.2.1', 'Benchs', 1, 'un', 1, 7),
  ('comercial', '3T2026', 'Membros e Time', '4.2.2', 'Treinamento de Projetos', 3, 'un', 0, 8),
  ('comercial', '3T2026', 'Membros e Time', '4.2.3', 'Roleplay de ligação durante as férias', 1, 'un', 3, 9),
  ('comercial', '3T2026', 'Membros e Time', '4.2.4', 'Roleplay', 3, 'un', 0, 10);
