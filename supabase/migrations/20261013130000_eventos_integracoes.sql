-- =====================================================================
-- v2 · Fase 2 (preparação da 2.3) — Recebimento dos eventos da API4COM
-- Guarda cada aviso "após desligamento da chamada" exatamente como chega, para depois virar ligação
-- e trabalho do Agente de ligação. O endereço é /api/integracoes/api4com?token=…; o token é conferido
-- pelo hash em privado.config 'api4com_token_hash' (o valor fica só no painel da API4COM).
-- =====================================================================

create table public.eventos_integracoes (
  id bigint generated always as identity primary key,
  origem text not null,                 -- 'api4com'
  recebido_em timestamptz not null default now(),
  payload jsonb not null,
  processado_em timestamptz,
  ligacao_id uuid references public.ligacoes (id) on delete set null,
  erro text
);
create index eventos_integracoes_pendentes_idx on public.eventos_integracoes (origem, recebido_em) where processado_em is null;
alter table public.eventos_integracoes enable row level security;
-- Só o diretor comercial lê (contém números de telefone); ninguém escreve pela API
create policy eventos_integracoes_ler on public.eventos_integracoes for select to authenticated
  using (privado.eh_diretor_de('comercial'));
revoke all on public.eventos_integracoes from anon;
revoke insert, update, delete on public.eventos_integracoes from authenticated;

create or replace function public.registrar_evento_integracao(_origem text, _token text, _payload jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_id bigint;
begin
  if _origem is distinct from 'api4com' or coalesce(_token, '') = '' or not exists (
    select 1 from privado.config c
    where c.chave = 'api4com_token_hash' and c.valor = encode(extensions.digest(_token, 'sha256'), 'hex')) then
    raise exception 'não autorizado';
  end if;
  insert into public.eventos_integracoes (origem, payload) values (_origem, coalesce(_payload, '{}')) returning id into v_id;
  return jsonb_build_object('ok', true, 'id', v_id);
end;
$$;
revoke all on function public.registrar_evento_integracao(text, text, jsonb) from public;
grant execute on function public.registrar_evento_integracao(text, text, jsonb) to anon, authenticated;
