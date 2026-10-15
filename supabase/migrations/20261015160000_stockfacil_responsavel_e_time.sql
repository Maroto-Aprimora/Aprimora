-- Leads StockFacil: campo "Responsável" (no lugar das observações na tabela) e acesso de todo o time do Comercial
-- (ver, buscar, editar e excluir), decisão do Diretor Comercial em 15/10/2026.

alter table public.stockfacil_leads add column responsavel_id uuid references public.membros (id) on delete set null;
create index stockfacil_leads_responsavel_idx on public.stockfacil_leads (responsavel_id);
grant update (responsavel_id) on public.stockfacil_leads to authenticated;

alter policy sf_buscas_ler on public.stockfacil_buscas using ((select privado.membro_ativo()));
alter policy sf_leads_ler on public.stockfacil_leads using ((select privado.membro_ativo()));
alter policy sf_leads_editar on public.stockfacil_leads
  using (privado.pertence_a('comercial')) with check (privado.pertence_a('comercial'));
alter policy sf_leads_excluir on public.stockfacil_leads using (privado.pertence_a('comercial'));

create or replace function public.buscar_leads_stockfacil(_termos text[], _cidade text default 'Londrina, PR')
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_busca uuid;
  v_termos text[];
  v_trab uuid;
begin
  if not privado.pertence_a('comercial') then raise exception 'Só membros do Comercial buscam leads do StockFacil'; end if;
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

-- Aviso de busca pronta: quem pediu (e os diretores)
create or replace function public.stockfacil_busca_pronta()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.status = 'pronta' and old.status is distinct from 'pronta' and new.criado_por is not null then
    perform privado.notificar(new.criado_por, 'stockfacil', 'Leads StockFacil prontos',
      format('%s comércios encontrados, %s novos na lista.', new.encontrados, new.novos), '/stockfacil', 'stockfacil_membro:' || new.id);
  end if;
  return null;
end;
$$;
create trigger stockfacil_busca_pronta after update of status on public.stockfacil_buscas
  for each row execute function public.stockfacil_busca_pronta();
revoke all on function public.stockfacil_busca_pronta() from public, anon, authenticated;
