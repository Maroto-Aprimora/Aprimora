-- Carga dos dados fictícios para o roteiro do portão da Fase 0 (uma transação).
-- Os gatilhos de aviso ficam desligados só durante a carga, para não gerar tarefas e notificações
-- de movimentos "passados" do histórico fictício.
begin;
alter table public.negocios disable trigger notificar_responsavel_negocio;
alter table public.negocio_historico disable trigger tarefas_ao_mudar_fase;
-- DADOS FICTÍCIOS PARA TESTES — todos marcados com ficticio = true.
-- Remova antes do uso real com supabase/dados/remover_dados_ficticios.sql
-- Gera 50 empresas (com decisor) e 50 negócios espalhados pelas fases do funil,
-- em proporção parecida com a do Pipefy em outubro de 2026.
select setseed(0.42);

with base as (
  select g as i,
    (array['Metalúrgica','Indústria','Confecções','Alimentos','Móveis','Plásticos','Transportes','Laticínios','Usinagem','Embalagens',
           'Panificadora','Cerâmica','Agro','Química','Distribuidora','Gráfica','Têxtil','Autopeças','Frigorífico','Vidraçaria'])[1 + (g % 20)] as tipo,
    (array['Horizonte','Paraná Norte','Ipiranga','Três Marcos','Bela Vista','Cafezal','Tibagi','Pioneira','Aurora','Rio Branco',
           'Esperança','Gralha Azul','Jardim','Ouro Verde','Cambé','Primavera','Itaipu','Araucária','Boa Safra','Vale Verde',
           'Santa Clara','Monte Alegre','Sol Nascente','Pé Vermelho','Norte Novo'])[1 + ((g * 7) % 25)] as sobrenome,
    (array['Londrina','Londrina','Londrina','Cambé','Ibiporã','Arapongas','Rolândia','Apucarana','Maringá'])[1 + (g % 9)] as cidade
  from generate_series(1, 50) g
)
insert into public.empresas (nome, razao_social, cnpj, segmento_id, telefone, email_principal, site, cidade, uf, ficticio)
select b.tipo || ' ' || b.sobrenome,
       b.tipo || ' ' || b.sobrenome || ' LTDA',
       case when random() < 0.7 then lpad((10 + b.i)::text, 2, '0') || '.' || (100 + b.i * 13 % 900) || '.' || (200 + b.i * 7 % 800) || '/0001-' || (10 + b.i % 90) end,
       (select s.id from public.segmentos s where s.nome = case b.tipo
          when 'Metalúrgica' then 'Metalmecânico' when 'Usinagem' then 'Metalmecânico' when 'Autopeças' then 'Automotivo'
          when 'Confecções' then 'Têxtil e confecção' when 'Têxtil' then 'Têxtil e confecção' when 'Móveis' then 'Moveleiro'
          when 'Plásticos' then 'Químico e plástico' when 'Química' then 'Químico e plástico' when 'Transportes' then 'Logística e transporte'
          when 'Distribuidora' then 'Logística e transporte' when 'Embalagens' then 'Embalagens' when 'Cerâmica' then 'Construção civil'
          when 'Vidraçaria' then 'Construção civil' when 'Agro' then 'Agronegócio' when 'Gráfica' then 'Indústria (outros)'
          else 'Alimentos e bebidas' end),
       '(43) 3' || (300 + b.i) || '-' || (1000 + b.i * 37 % 9000),
       'contato@' || lower(public.normalizar(replace(b.tipo || b.sobrenome, ' ', ''))) || '.com.br',
       'www.' || lower(public.normalizar(replace(b.tipo || b.sobrenome, ' ', ''))) || '.com.br',
       b.cidade, 'PR', true
from base b
on conflict do nothing;

insert into public.contatos (empresa_id, nome, cargo, decisor, email, telefone)
select e.id,
  (array['Carlos Souza','Mariana Lima','João Pereira','Ana Ribeiro','Paulo Martins','Fernanda Alves','Rafael Gomes','Juliana Costa',
         'Ricardo Nunes','Patrícia Rocha','Marcelo Dias','Camila Freitas','Bruno Teixeira','Larissa Melo','Gustavo Barros'])[1 + (row_number() over (order by e.nome))::int % 15],
  (array['Sócio-proprietário','Diretor','Gerente de produção','Gerente administrativo','Supervisor de qualidade'])[1 + (row_number() over (order by e.nome))::int % 5],
  true,
  'decisor@' || split_part(e.email_principal, '@', 2),
  '(43) 99' || (100 + (row_number() over (order by e.nome))::int) || '-' || (2000 + (row_number() over (order by e.nome))::int * 31 % 7000)
from public.empresas e where e.ficticio;

with distribuicao as (
  select fase, row_number() over () as pos from unnest(array[
    'enriquecimento','enriquecimento','enriquecimento','enriquecimento',
    'coleta','coleta','coleta','coleta','coleta','coleta',
    'email','email','email','email','email','email','email','email','email','email','email','email','email','email',
    'coldcall_1','coldcall_1','coldcall_1','coldcall_1','coldcall_2','coldcall_2','retornar','retornar',
    'oportunidade','oportunidade','oportunidade','diagnostico','diagnostico','escopo','escopo','proposta','proposta',
    'ganho','ganho','ganho','reciclagem','reciclagem','nao_vendido','nao_vendido','nao_qualificado','nao_qualificado']) as fase
), empresas as (
  select e.id, e.nome, row_number() over (order by e.nome) as pos from public.empresas e where e.ficticio
)
insert into public.negocios (funil_id, empresa_id, contato_id, titulo, fase_id, valor, origem_id, campos, motivo_id, retorno_em, ficticio)
select fa.funil_id, em.id, (select c.id from public.contatos c where c.empresa_id = em.id limit 1), em.nome, fa.id,
  case when fa.chave in ('oportunidade','diagnostico','escopo','proposta','ganho','nao_vendido')
       then (array[4500, 6800, 8000, 9500, 12000, 15000, 18000])[1 + (em.pos::int % 7)] end,
  (select o.id from public.origens o where o.ativo and o.ordem = 1 + (em.pos::int % 7)),
  case
    when fa.chave = 'oportunidade' then '{"qual_oportunidade":"Pediu proposta de mapeamento de processos"}'::jsonb
    when fa.chave = 'retornar' then jsonb_build_object('retornar_em', (current_date + 20)::text, 'retorna_para_decisor', 'Sócio-proprietário')
    when fa.chave in ('diagnostico','escopo','proposta','ganho','nao_vendido') then jsonb_build_object(
      'qual_oportunidade', 'Organizar a produção e reduzir desperdícios',
      'data_marcada', (current_date - (em.pos::int % 20))::text,
      'dores_coletadas', 'Atrasos na entrega, falta de padronização e estoque desorganizado',
      'data_apresentacao', (current_date - (em.pos::int % 10))::text)
    else '{}'::jsonb end,
  case fa.chave
    when 'nao_vendido' then (select m.id from public.motivos m where m.ativo and m.tipo = 'perda' order by m.ordem limit 1 offset (em.pos::int % 3))
    when 'nao_qualificado' then (select m.id from public.motivos m where m.ativo and m.tipo = 'desqualificacao' order by m.ordem limit 1 offset (em.pos::int % 3))
  end,
  case when fa.chave = 'reciclagem' then current_date + 30 end,
  true
from distribuicao d
join empresas em on em.pos = d.pos
join public.fases fa on fa.chave = d.fase;

-- Datas variadas para o SLA e os indicadores fazerem sentido
update public.negocios n set
  entrou_na_fase_em = now() - make_interval(days => case when f.chave = 'oportunidade' then 2 + (abs(hashtext(n.titulo)) % 11)
                                                        else 1 + (abs(hashtext(n.titulo)) % 40) end),
  created_at = now() - make_interval(days => 45 + (abs(hashtext(n.titulo)) % 120))
from public.fases f
where f.id = n.fase_id and n.ficticio;


-- Responsáveis: distribui entre os membros ativos do Comercial (diretores incluídos, para aparecer no Início deles)
update public.negocios n set responsavel_id = m.id
from (select md.membro_id as id, row_number() over (order by mb.nome) - 1 as k, count(*) over () as total
      from public.membro_diretorias md join public.membros mb on mb.id = md.membro_id
      where md.diretoria = 'comercial' and mb.ativo) m
where n.ficticio and m.k = abs(hashtext(n.id::text)) % m.total;
-- HISTÓRICO FICTÍCIO para os indicadores fazerem sentido nos testes (Fase 3).
-- Reconstrói o caminho de cada negócio fictício pelo funil, com datas entre a criação e a entrada na fase atual.
-- Sai junto com os negócios em remover_dados_ficticios.sql (o histórico apaga em cascata).

with caminhos(chave_atual, passos) as (values
  ('entrada',         array['entrada']),
  ('enriquecimento',  array['entrada','enriquecimento']),
  ('coleta',          array['entrada','enriquecimento','coleta']),
  ('email',           array['entrada','enriquecimento','coleta','email']),
  ('coldcall_1',      array['entrada','enriquecimento','coleta','email','coldcall_1']),
  ('coldcall_2',      array['entrada','enriquecimento','coleta','email','coldcall_1','coldcall_2']),
  ('retornar',        array['entrada','enriquecimento','coleta','email','coldcall_1','retornar']),
  ('oportunidade',    array['entrada','enriquecimento','coleta','email','coldcall_1','oportunidade']),
  ('diagnostico',     array['entrada','enriquecimento','coleta','email','coldcall_1','oportunidade','diagnostico']),
  ('escopo',          array['entrada','enriquecimento','coleta','email','coldcall_1','oportunidade','diagnostico','escopo']),
  ('proposta',        array['entrada','enriquecimento','coleta','email','coldcall_1','oportunidade','diagnostico','escopo','proposta']),
  ('ganho',           array['entrada','enriquecimento','coleta','email','coldcall_1','oportunidade','diagnostico','escopo','proposta','ganho']),
  ('nao_vendido',     array['entrada','enriquecimento','coleta','email','coldcall_1','oportunidade','diagnostico','escopo','proposta','nao_vendido']),
  ('reciclagem',      array['entrada','enriquecimento','coleta','email','coldcall_1','coldcall_2','reciclagem']),
  ('nao_qualificado', array['entrada','enriquecimento','nao_qualificado'])
),
alvo as (
  select n.id, n.created_at, n.entrou_na_fase_em, n.responsavel_id, n.motivo_id, c.passos
  from public.negocios n
  join public.fases f on f.id = n.fase_id
  join caminhos c on c.chave_atual = f.chave
  where n.ficticio
    and not exists (select 1 from public.negocio_historico h where h.negocio_id = n.id and h.fase_origem_id is not null)
),
passos as (
  select a.id, a.responsavel_id, a.motivo_id, p.chave, p.i, array_length(a.passos, 1) as total,
         lag(p.chave) over (partition by a.id order by p.i) as anterior,
         a.created_at + (a.entrou_na_fase_em - a.created_at) * ((p.i - 1)::numeric / greatest(array_length(a.passos, 1) - 1, 1)) as quando
  from alvo a, unnest(a.passos) with ordinality as p(chave, i)
)
insert into public.negocio_historico (negocio_id, fase_origem_id, fase_destino_id, autor_id, automatico, motivo_id, created_at)
select p.id, fo.id, fd.id, case when p.i > 3 then p.responsavel_id end, p.i <= 2,
       case when p.i = p.total then p.motivo_id end, p.quando
from passos p
join public.fases fd on fd.chave = p.chave
left join public.fases fo on fo.chave = p.anterior
where p.i > 1;

-- O registro de criação passa a ser a entrada no funil, na data de criação do negócio
update public.negocio_historico h set
  fase_destino_id = (select id from public.fases where chave = 'entrada'),
  created_at = n.created_at
from public.negocios n
where n.id = h.negocio_id and n.ficticio and h.fase_origem_id is null;

-- Ganhos e perdas com data coerente com o histórico (espalhados pelos trimestres)
update public.negocios n set
  ganho_em = case when f.tipo = 'ganho' then n.entrou_na_fase_em end,
  encerrado_em = case when f.tipo in ('ganho', 'perda') then n.entrou_na_fase_em end
from public.fases f
where f.id = n.fase_id and n.ficticio and f.tipo in ('ganho', 'perda');


-- Responsável da época no histórico fictício = responsável atual
update public.negocio_historico h set responsavel_id = n.responsavel_id from public.negocios n where n.id = h.negocio_id and n.ficticio;
alter table public.negocios enable trigger notificar_responsavel_negocio;
alter table public.negocio_historico enable trigger tarefas_ao_mudar_fase;
commit;
