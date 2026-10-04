-- =====================================================================
-- Fase 3 — Anexos dos negócios e metas automáticas
-- =====================================================================

-- Anexos dos negócios (propostas, contratos, apresentações) no Supabase Storage
insert into storage.buckets (id, name, public, file_size_limit)
values ('anexos', 'anexos', false, 10485760)
on conflict (id) do nothing;

create table public.anexos (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references public.negocios (id) on delete cascade,
  nome text not null,
  caminho text not null unique,
  tamanho bigint not null check (tamanho > 0 and tamanho <= 10485760),
  tipo_mime text,
  enviado_por uuid references public.membros (id) on delete set null default auth.uid(),
  created_at timestamptz not null default now()
);
create index anexos_negocio_idx on public.anexos (negocio_id, created_at desc);
comment on table public.anexos is 'Arquivos anexados aos negócios. O arquivo fica no bucket "anexos" em negocios/<negocio_id>/<arquivo>.';

alter table public.anexos enable row level security;
create policy anexos_ler on public.anexos for select to authenticated using ((select privado.membro_ativo()));
create policy anexos_enviar on public.anexos for insert to authenticated
  with check (privado.pode_editar_negocio(negocio_id) and caminho like 'negocios/' || negocio_id || '/%');
create policy anexos_excluir on public.anexos for delete to authenticated
  using (enviado_por = (select auth.uid()) or privado.eh_diretor_de(privado.diretoria_do_funil((select n.funil_id from public.negocios n where n.id = negocio_id))));
grant select, insert, delete on public.anexos to authenticated;
revoke all on public.anexos from anon;

-- Regras do Storage: o 2º nível da pasta é o id do negócio
create policy anexos_storage_ler on storage.objects for select to authenticated
  using (bucket_id = 'anexos' and (select privado.membro_ativo()));
create policy anexos_storage_enviar on storage.objects for insert to authenticated
  with check (bucket_id = 'anexos' and (storage.foldername(name))[1] = 'negocios'
              and privado.pode_editar_negocio(((storage.foldername(name))[2])::uuid));
create policy anexos_storage_excluir on storage.objects for delete to authenticated
  using (bucket_id = 'anexos' and (owner_id = (select auth.uid())::text
         or privado.eh_diretor_de(privado.diretoria_do_funil((select n.funil_id from public.negocios n
              where n.id = ((storage.foldername(name))[2])::uuid)))));

-- Metas automáticas: cada meta pode apontar para um indicador calculado pelo portal.
-- Com indicador, realizado = cálculo automático + realizado_manual (ajuste, ex.: o que aconteceu antes do portal).
comment on column public.metas.indicador is
  'Chave do indicador automático (ver src/lib/indicadores.ts). Nulo = meta manual. Com indicador, realizado_manual vira ajuste somado ao cálculo.';
update public.metas set indicador = 'faturamento' where diretoria = 'comercial' and titulo = 'Faturamento da meta';
update public.metas set indicador = 'diagnosticos' where diretoria = 'comercial' and titulo = 'Diagnósticos marcados';
update public.metas set indicador = 'diagnosticos_fora_londrina' where diretoria = 'comercial' and titulo = 'Diagnósticos marcados fora de Londrina';
update public.metas set indicador = 'diagnosticos_pos_venda' where diretoria = 'comercial' and titulo = 'Diagnósticos oriundos de pós-vendas';
update public.metas set indicador = 'diagnosticos_membros_novos' where diretoria = 'comercial' and titulo = 'Diagnósticos marcados por membros novos';
update public.metas set indicador = 'contratos' where diretoria = 'comercial' and titulo = 'Contratos fechados';
update public.metas set indicador = 'propostas' where diretoria = 'comercial' and titulo = 'Propostas';
update public.metas set indicador = 'prospectday' where diretoria = 'comercial' and titulo = 'ProspectDay';
