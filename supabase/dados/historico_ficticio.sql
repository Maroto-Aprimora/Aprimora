-- HISTÓRICO FICTÍCIO para os indicadores fazerem sentido nos testes (Fase 3).
-- Reconstrói o caminho de cada negócio fictício pelo funil, com datas entre a criação e a entrada na fase atual.
-- Sai junto com os negócios em remover_dados_ficticios.sql (o histórico apaga em cascata).
begin;

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

commit;
