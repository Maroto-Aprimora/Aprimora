-- =====================================================================
-- Edição compartilhada dos cards (decisão do Diretor Comercial, 14/10/2026)
-- - Todo membro do Comercial edita qualquer negócio e empresa do funil: troca o responsável, registra atividades
--   (reuniões) e envia/exclui anexos. Excluir negócio e empresa continua só com o diretor.
-- - Desempenho individual aberto ao time: todos veem as avaliações e o plano de melhoria de todos.
-- =====================================================================

create or replace function privado.pode_editar_negocio(_negocio uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.negocios n where n.id = _negocio
    and privado.pertence_a(privado.diretoria_do_funil(n.funil_id)));
$$;

create or replace function privado.pode_editar_empresa(_empresa uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select privado.pertence_a('comercial');
$$;

alter policy negocios_editar on public.negocios
  using (privado.pode_editar_negocio(id)) with check (privado.pode_editar_negocio(id));

-- Anexos: quem edita o negócio também exclui
alter policy anexos_excluir on public.anexos using (privado.pode_editar_negocio(negocio_id));
alter policy anexos_storage_excluir on storage.objects
  using (bucket_id = 'anexos' and (storage.foldername(name))[1] = 'negocios'
         and privado.pode_editar_negocio(((storage.foldername(name))[2])::uuid));

-- Atividades ligadas a um lead: quem edita o negócio também edita a atividade
create or replace function privado.pode_gerir_atividade(_atividade uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.atividades a where a.id = _atividade
    and (privado.participa_da_atividade(a.id)
         or (a.negocio_id is not null and privado.pode_editar_negocio(a.negocio_id))
         or (a.diretoria is null and privado.eh_diretor())
         or (a.diretoria is not null and privado.eh_diretor_de(a.diretoria))));
$$;

-- Desempenho individual: todos veem de todos
alter policy avaliacoes_ler on public.avaliacoes_ligacao using ((select privado.membro_ativo()));

create or replace function public.plano_melhoria(_membro uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_nome text;
  v_rel record;
  v_plano jsonb;
begin
  if not privado.membro_ativo() then raise exception 'Sem permissão'; end if;
  select nome into v_nome from public.membros where id = _membro;
  for v_rel in
    select r.id, r.de, r.ate, r.revisado_em, r.analise from public.relatorios r
     where r.status = 'pronto' and r.revisado_em is not null and r.analise is not null
     order by r.ate desc, r.revisado_em desc limit 10
  loop
    select p into v_plano from jsonb_array_elements(coalesce(v_rel.analise -> 'planos', '[]')) p
     where public.normalizar(p ->> 'membro') = public.normalizar(v_nome) limit 1;
    if v_plano is not null then
      return jsonb_build_object('de', v_rel.de, 'ate', v_rel.ate, 'revisado_em', v_rel.revisado_em, 'plano', v_plano);
    end if;
  end loop;
  return null;
end;
$$;
