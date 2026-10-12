-- =====================================================================
-- v2 · Fase 0 · PR 3 (parte 1) — Motivos de perda/desqualificação e origens (PE-PA-002, Seções 3.3 e 3.4)
-- Cria as listas novas e as regras. As antigas ficam inativas e são apagadas na parte 2
-- (decisão do Diretor Comercial em 12/10/2026: substituir as listas).
-- =====================================================================

-- Chave estável para as regras do banco encontrarem um item mesmo se o nome for editado
alter table public.motivos
  add column chave text,
  add column exige_comentario boolean not null default false,   -- "Outro": comentário obrigatório
  add column marca_nao_contatar boolean not null default false; -- "Pediu para não ser contatado"
create unique index motivos_chave_idx on public.motivos (diretoria, tipo, chave) where chave is not null;

alter table public.origens add column chave text;
create unique index origens_chave_idx on public.origens (diretoria, chave) where chave is not null;

-- Libera os nomes (há unicidade por nome) e desativa os itens antigos
update public.motivos set nome = nome || ' (antigo)', ativo = false where chave is null;
update public.origens set nome = nome || ' (antigo)', ativo = false where chave is null;

insert into public.motivos (diretoria, tipo, chave, nome, ordem, exige_comentario, marca_nao_contatar) values
  ('comercial', 'perda', 'preco_acima',          'Preço acima do orçamento', 1, false, false),
  ('comercial', 'perda', 'momento_inadequado',   'Momento inadequado, adiou', 2, false, false),
  ('comercial', 'perda', 'sem_orcamento',        'Sem orçamento', 3, false, false),
  ('comercial', 'perda', 'nao_percebeu_valor',   'Não percebeu valor', 4, false, false),
  ('comercial', 'perda', 'outra_consultoria',    'Escolheu outra consultoria', 5, false, false),
  ('comercial', 'perda', 'parou_de_responder',   'Parou de responder', 6, false, false),
  ('comercial', 'perda', 'resolveu_internamente','Resolveu internamente', 7, false, false),
  ('comercial', 'perda', 'outro',                'Outro', 99, true, false),
  ('comercial', 'desqualificacao', 'sem_interesse',        'Sem interesse declarado', 1, false, false),
  ('comercial', 'desqualificacao', 'fora_do_perfil',       'Fora do perfil (porte ou segmento)', 2, false, false),
  ('comercial', 'desqualificacao', 'empresa_inativa',      'Empresa fechada ou inativa', 3, false, false),
  ('comercial', 'desqualificacao', 'contato_invalido',     'Contato inválido, sem alternativa', 4, false, false),
  ('comercial', 'desqualificacao', 'nao_contatar',         'Pediu para não ser contatado', 5, false, true),
  ('comercial', 'desqualificacao', 'atendido_recentemente','Atendido recentemente pela Aprimora', 6, false, false),
  ('comercial', 'desqualificacao', 'outro',                'Outro', 99, true, false);

insert into public.origens (diretoria, chave, nome, ordem) values
  ('comercial', 'extracao_google', 'Extração (Google)', 1),
  ('comercial', 'apollo',          'Apollo', 2),
  ('comercial', 'indicacao',       'Indicação', 3),
  ('comercial', 'evento',          'Evento', 4),
  ('comercial', 'instagram',       'Instagram', 5),
  ('comercial', 'linkedin',        'LinkedIn (página, orgânico)', 6),
  ('comercial', 'site',            'Site', 7),
  ('comercial', 'trafego_pago',    'Tráfego pago', 8),
  ('comercial', 'pos_venda',       'Pós-venda', 9),
  ('comercial', 'revenda',         'Revenda', 10),
  ('comercial', 'manual',          'Manual', 11);

-- Resultado "Sem interesse" leva o motivo "Sem interesse declarado"
update public.resultados_ligacao set motivo_id = (select id from public.motivos where chave = 'sem_interesse' and tipo = 'desqualificacao')
 where chave = 'sem_interesse';

-- ---------------------------------------------------------------------
-- Regras dos motivos ao salvar o negócio
-- ---------------------------------------------------------------------
-- "Outro" exige comentário (motivo_detalhe); antes do gatilho principal, que valida a fase
create or replace function public.validar_motivo_negocio()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  m public.motivos%rowtype;
begin
  if new.motivo_id is not null and (tg_op = 'INSERT' or new.motivo_id is distinct from old.motivo_id
                                    or new.motivo_detalhe is distinct from old.motivo_detalhe) then
    select * into m from public.motivos where id = new.motivo_id;
    if m.exige_comentario and nullif(trim(coalesce(new.motivo_detalhe, '')), '') is null then
      raise exception 'Escreva um comentário para o motivo "%"', m.nome;
    end if;
  end if;
  return new;
end;
$$;
create trigger a_validar_motivo_negocio before insert or update of motivo_id, motivo_detalhe on public.negocios
  for each row execute function public.validar_motivo_negocio();

-- "Pediu para não ser contatado" marca "não contatar" no contato do negócio (sem contato: em todos da empresa)
create or replace function public.aplicar_motivo_negocio()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.motivo_id is not null and (tg_op = 'INSERT' or new.motivo_id is distinct from old.motivo_id)
     and exists (select 1 from public.motivos m where m.id = new.motivo_id and m.marca_nao_contatar) then
    if new.contato_id is not null then
      update public.contatos set nao_contatar = true where id = new.contato_id;
    else
      update public.contatos set nao_contatar = true where empresa_id = new.empresa_id;
    end if;
  end if;
  return null;
end;
$$;
create trigger aplicar_motivo_negocio after insert or update of motivo_id on public.negocios
  for each row execute function public.aplicar_motivo_negocio();

revoke all on function public.validar_motivo_negocio() from public, anon, authenticated;
revoke all on function public.aplicar_motivo_negocio() from public, anon, authenticated;
