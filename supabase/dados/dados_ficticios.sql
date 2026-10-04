-- DADOS FICTÍCIOS PARA TESTES — todos marcados com ficticio = true.
-- Remova antes do uso real com supabase/dados/remover_dados_ficticios.sql
-- Gera 50 empresas (com decisor) e 50 negócios espalhados pelas fases do funil,
-- em proporção parecida com a do Pipefy em outubro de 2026.
begin;
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
  (select o.id from public.origens o where o.ordem = 1 + (em.pos::int % 7)),
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
    when 'nao_vendido' then (select m.id from public.motivos m where m.tipo = 'perda' order by m.ordem limit 1 offset (em.pos::int % 3))
    when 'nao_qualificado' then (select m.id from public.motivos m where m.tipo = 'desqualificacao' order by m.ordem limit 1 offset (em.pos::int % 3))
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

commit;
