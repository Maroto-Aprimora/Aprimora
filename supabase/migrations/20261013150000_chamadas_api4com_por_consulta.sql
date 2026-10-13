-- =====================================================================
-- v2 · Fase 2 (2.3) — Chamadas da API4COM também por consulta
-- O webhook da API4COM não dispara para ligações feitas pelo aplicativo/webphone (sem metadados do discador).
-- O n8n passa a consultar GET /api/v1/calls a cada 5 minutos e entrega as chamadas novas ao portal.
-- Cada chamada entra uma vez só (id da chamada na API4COM), venha pelo webhook ou pela consulta.
-- =====================================================================

alter table public.eventos_integracoes add column externo_id text;
create unique index eventos_integracoes_externo_idx on public.eventos_integracoes (origem, externo_id) where externo_id is not null;

-- Webhook: grava o id da chamada e ignora repetição
create or replace function public.registrar_evento_integracao(_origem text, _token text, _payload jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_id bigint;
  v_externo text := nullif(coalesce(_payload ->> 'id', _payload ->> 'call_id', _payload -> 'call' ->> 'id'), '');
begin
  if _origem is distinct from 'api4com' or coalesce(_token, '') = '' or not exists (
    select 1 from privado.config c
    where c.chave = 'api4com_token_hash' and c.valor = encode(extensions.digest(_token, 'sha256'), 'hex')) then
    raise exception 'não autorizado';
  end if;
  insert into public.eventos_integracoes (origem, payload, externo_id) values (_origem, coalesce(_payload, '{}'), v_externo)
  on conflict (origem, externo_id) where externo_id is not null do nothing
  returning id into v_id;
  return jsonb_build_object('ok', true, 'id', v_id, 'repetido', v_id is null);
end;
$$;

-- Consulta do n8n: recebe uma lista de chamadas (formato de GET /api/v1/calls) e grava as novas
create or replace function public.n8n_registrar_chamadas(_segredo text, _chamadas jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_novas int;
begin
  if not privado.n8n_autorizado(_segredo) then raise exception 'não autorizado'; end if;
  if jsonb_typeof(_chamadas) is distinct from 'array' then raise exception 'chamadas deve ser uma lista'; end if;
  with ins as (
    insert into public.eventos_integracoes (origem, payload, externo_id)
    select 'api4com', jsonb_set(c, '{_fonte}', '"consulta"'), c ->> 'id'
    from jsonb_array_elements(_chamadas) c
    where nullif(c ->> 'id', '') is not null
    on conflict (origem, externo_id) where externo_id is not null do nothing
    returning 1)
  select count(*) into v_novas from ins;
  return jsonb_build_object('ok', true, 'recebidas', jsonb_array_length(_chamadas), 'novas', v_novas);
end;
$$;
revoke all on function public.n8n_registrar_chamadas(text, jsonb) from public;
grant execute on function public.n8n_registrar_chamadas(text, jsonb) to anon, authenticated;
