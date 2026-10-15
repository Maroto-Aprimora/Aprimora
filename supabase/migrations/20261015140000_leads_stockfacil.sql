-- =====================================================================
-- Temporário · Leads StockFacil (pedido do Diretor Comercial, 15/10/2026)
-- Prospecção separada do funil da Aprimora: comércios de pequeno e médio porte de Londrina com muitos itens em estoque
-- (lojas de variedades, utilidades, materiais, autopeças…) para o SaaS StockFacil. O n8n roda o google-maps-scraper
-- (gosom) na VPS e devolve os leads; a página "Leads StockFacil" lista, filtra e exporta em Excel.
-- Nada aqui entra no funil, nos indicadores ou nos agentes da Aprimora.
-- =====================================================================

insert into public.agentes (chave, codigo, nome, descricao, tipo, prioridade, fase_roadmap, quem_aprova, ativo, ordem)
select 'stockfacil', 'T1', 'Leads StockFacil (temporário)',
  'Extrai comércios de Londrina do Google Maps (google-maps-scraper na VPS) para a lista de prospecção do StockFacil.',
  tipo, 9, 5, 'Diretor', true, 99
from public.agentes where chave = 'prospector';

create table public.stockfacil_buscas (
  id uuid primary key default gen_random_uuid(),
  termos text[] not null,
  cidade text not null default 'Londrina, PR',
  status text not null default 'na_fila' check (status in ('na_fila', 'buscando', 'pronta', 'erro')),
  encontrados integer,
  novos integer,
  erro text,
  trabalho_id uuid references public.trabalhos (id) on delete set null,
  criado_por uuid references public.membros (id) on delete set null default auth.uid(),
  created_at timestamptz not null default now(),
  concluida_em timestamptz
);

create table public.stockfacil_leads (
  id uuid primary key default gen_random_uuid(),
  place_id text unique,
  nome text not null,
  categoria text,
  termo text,                         -- termo de busca que encontrou o lead
  endereco text,
  bairro text,
  telefone text,
  telefone_digitos text generated always as (nullif(public.so_digitos(telefone), '')) stored,
  site text,
  emails text,
  nota numeric(2,1),
  avaliacoes integer,
  link_maps text,
  latitude numeric(9,6),
  longitude numeric(9,6),
  situacao text not null default 'novo' check (situacao in ('novo', 'contatado', 'interessado', 'demonstracao', 'cliente', 'descartado')),
  observacoes text,
  busca_id uuid references public.stockfacil_buscas (id) on delete set null,
  atualizado_por uuid references public.membros (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index stockfacil_leads_situacao_idx on public.stockfacil_leads (situacao, created_at desc);
create unique index stockfacil_leads_telefone_idx on public.stockfacil_leads (telefone_digitos) where telefone_digitos is not null;
create trigger stockfacil_leads_updated_at before update on public.stockfacil_leads for each row execute function public.tocar_updated_at();

alter table public.stockfacil_buscas enable row level security;
alter table public.stockfacil_leads enable row level security;
-- Só a diretoria comercial usa esta lista
create policy sf_buscas_ler on public.stockfacil_buscas for select to authenticated using (privado.eh_diretor_de('comercial'));
create policy sf_leads_ler on public.stockfacil_leads for select to authenticated using (privado.eh_diretor_de('comercial'));
create policy sf_leads_editar on public.stockfacil_leads for update to authenticated
  using (privado.eh_diretor_de('comercial')) with check (privado.eh_diretor_de('comercial'));
create policy sf_leads_excluir on public.stockfacil_leads for delete to authenticated using (privado.eh_diretor_de('comercial'));
revoke all on public.stockfacil_buscas, public.stockfacil_leads from anon;
revoke insert, update, delete on public.stockfacil_buscas from authenticated;
revoke insert on public.stockfacil_leads from authenticated;
revoke update on public.stockfacil_leads from authenticated;
grant update (situacao, observacoes, atualizado_por) on public.stockfacil_leads to authenticated;

-- Pede uma busca (o n8n roda o scraper e devolve os leads)
create or replace function public.buscar_leads_stockfacil(_termos text[], _cidade text default 'Londrina, PR')
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_busca uuid;
  v_termos text[];
  v_trab uuid;
begin
  if not privado.eh_diretor_de('comercial') then raise exception 'Só o Diretor Comercial busca leads do StockFacil'; end if;
  select array_agg(distinct t) into v_termos from (select nullif(trim(x), '') t from unnest(_termos) x) s where t is not null;
  if v_termos is null then raise exception 'Informe ao menos um tipo de comércio'; end if;
  if array_length(v_termos, 1) > 40 then raise exception 'No máximo 40 termos por busca'; end if;
  if exists (select 1 from public.stockfacil_buscas where status in ('na_fila', 'buscando')) then
    raise exception 'Já há uma busca em andamento. Espere terminar.';
  end if;
  insert into public.stockfacil_buscas (termos, cidade) values (v_termos, coalesce(nullif(trim(_cidade), ''), 'Londrina, PR'))
  returning id into v_busca;
  v_trab := privado.enfileirar('stockfacil', 'buscar_leads', jsonb_build_object(
    'busca_id', v_busca, 'cidade', coalesce(nullif(trim(_cidade), ''), 'Londrina, PR'),
    'consultas', (select jsonb_agg(t || ' em ' || coalesce(nullif(trim(_cidade), ''), 'Londrina, PR')) from unnest(v_termos) t)),
    null, 'stockfacil:' || v_busca);
  if v_trab is null then raise exception 'O agente "Leads StockFacil" está desligado em Config. do funil → Agentes'; end if;
  update public.stockfacil_buscas set trabalho_id = v_trab where id = v_busca;
  return v_busca;
end;
$$;
revoke all on function public.buscar_leads_stockfacil(text[], text) from public, anon;
grant execute on function public.buscar_leads_stockfacil(text[], text) to authenticated;

-- n8n avisa que começou a raspagem
create or replace function public.n8n_stockfacil_iniciada(_segredo text, _busca uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not privado.n8n_autorizado(_segredo) then raise exception 'não autorizado'; end if;
  update public.stockfacil_buscas set status = 'buscando' where id = _busca and status = 'na_fila';
end;
$$;
revoke all on function public.n8n_stockfacil_iniciada(text, uuid) from public;
grant execute on function public.n8n_stockfacil_iniciada(text, uuid) to anon, authenticated;

-- Resultado: grava os leads (sem duplicar por place_id ou telefone) e fecha a busca
create or replace function privado.aplicar_stockfacil(t public.trabalhos, r jsonb)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_busca uuid := (t.payload ->> 'busca_id')::uuid;
  l jsonb;
  v_total int := 0;
  v_novos int := 0;
  v_id uuid;
begin
  for l in select * from jsonb_array_elements(coalesce(r -> 'leads', '[]')) loop
    continue when nullif(trim(l ->> 'nome'), '') is null;
    -- Fechados de vez ficam de fora
    continue when coalesce(l ->> 'status', '') ilike '%perman%';
    v_total := v_total + 1;
    continue when exists (select 1 from public.stockfacil_leads s
      where (s.place_id = l ->> 'place_id' and l ->> 'place_id' <> '')
         or (s.telefone_digitos = nullif(public.so_digitos(l ->> 'telefone'), '')));
    insert into public.stockfacil_leads (place_id, nome, categoria, termo, endereco, bairro, telefone, site, emails, nota, avaliacoes,
      link_maps, latitude, longitude, busca_id)
    values (nullif(l ->> 'place_id', ''), trim(l ->> 'nome'), nullif(l ->> 'categoria', ''), nullif(l ->> 'termo', ''),
      nullif(l ->> 'endereco', ''), nullif(l ->> 'bairro', ''), nullif(l ->> 'telefone', ''), nullif(l ->> 'site', ''),
      nullif(l ->> 'emails', ''),
      case when (l ->> 'nota') ~ '^\d+(\.\d+)?$' then least((l ->> 'nota')::numeric, 5) end,
      case when (l ->> 'avaliacoes') ~ '^\d+$' then (l ->> 'avaliacoes')::int end,
      nullif(l ->> 'link', ''),
      case when (l ->> 'latitude') ~ '^-?\d+(\.\d+)?$' then (l ->> 'latitude')::numeric end,
      case when (l ->> 'longitude') ~ '^-?\d+(\.\d+)?$' then (l ->> 'longitude')::numeric end,
      v_busca)
    on conflict do nothing
    returning id into v_id;
    if v_id is not null then v_novos := v_novos + 1; end if;
  end loop;
  update public.stockfacil_buscas set status = 'pronta', encontrados = v_total, novos = v_novos, concluida_em = now(), erro = null
   where id = v_busca;
  perform privado.notificar_diretores('stockfacil', 'Leads StockFacil prontos',
    format('%s comércios encontrados, %s novos na lista.', v_total, v_novos), '/stockfacil', 'stockfacil:' || v_busca);
end;
$$;

create or replace function privado.aplicar_resultado_agente(t public.trabalhos, r jsonb)
returns void language plpgsql security definer set search_path = '' as $$
begin
  case t.agente
    when 'enriquecedor' then perform privado.aplicar_enriquecimento(t, r);
    when 'analista_gerencial' then perform privado.aplicar_relatorio(t, r);
    when 'ligacao' then perform privado.aplicar_ligacao(t, r);
    when 'redator' then
      if t.tipo = 'enviar_email' then perform privado.aplicar_envio(t, r); else perform privado.aplicar_redacao(t, r); end if;
    when 'monitor_respostas' then perform privado.aplicar_classificacao(t, r);
    when 'assistente_proposta' then perform privado.aplicar_proposta(t, r);
    when 'stockfacil' then perform privado.aplicar_stockfacil(t, r);
    else null;
  end case;
end;
$$;

-- Falha definitiva: a busca fica com erro (trigger simples, sem reescrever n8n_falhar)
create or replace function public.stockfacil_trabalho_com_erro()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.agente = 'stockfacil' and new.status = 'erro' and old.status is distinct from 'erro' then
    update public.stockfacil_buscas set status = 'erro', erro = new.erro where id = (new.payload ->> 'busca_id')::uuid;
  end if;
  return null;
end;
$$;
create trigger stockfacil_trabalho_com_erro after update of status on public.trabalhos
  for each row execute function public.stockfacil_trabalho_com_erro();
revoke all on function public.stockfacil_trabalho_com_erro() from public, anon, authenticated;
