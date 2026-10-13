-- =====================================================================
-- v2 · Fase 2 · 2.3 — O Avaliador só avalia ligação com conversa
-- Teste real (13/10): ligação sem conversa recebeu nota 1 em tudo e derrubaria a média do membro.
-- Não atendeu, caixa postal e número errado não geram avaliação.
-- =====================================================================

create or replace function privado.aplicar_ligacao(t public.trabalhos, r jsonb)
returns void language plpgsql security definer set search_path = '' as $$
declare
  l public.ligacoes%rowtype;
  v_notas jsonb;
  v_media numeric;
begin
  select * into l from public.ligacoes where id = (t.payload ->> 'ligacao_id')::uuid;
  if not found then return; end if;
  update public.ligacoes set transcricao = nullif(r ->> 'transcricao', ''), resumo = nullif(r ->> 'resumo', '') where id = l.id;
  perform privado.aprovacao_resultado_ligacao(l.id, t.id, r);

  -- Sem conversa não há o que avaliar (não derruba a média do membro)
  if coalesce(r ->> 'resultado', '') not in ('nao_atendeu', 'caixa_postal', 'numero_errado')
     and jsonb_typeof(r -> 'avaliacao' -> 'notas') = 'array' and exists (select 1 from public.agentes where chave = 'avaliador' and ativo) then
    select jsonb_agg(jsonb_build_object('chave', rc.chave, 'nome', rc.nome,
             'nota', least(4, greatest(1, (x ->> 'nota')::int)), 'comentario', coalesce(x ->> 'comentario', '')) order by rc.ordem),
           avg(least(4, greatest(1, (x ->> 'nota')::int)))
      into v_notas, v_media
      from jsonb_array_elements(r -> 'avaliacao' -> 'notas') x
      join public.rubrica_criterios rc on rc.chave = x ->> 'chave'
     where (x ->> 'nota') ~ '^[0-9]+$';
    if v_notas is not null then
      insert into public.avaliacoes_ligacao (ligacao_id, membro_id, notas, media, comentario)
      values (l.id, l.membro_id, v_notas, round(v_media, 2), nullif(r -> 'avaliacao' ->> 'comentario', ''))
      on conflict (ligacao_id) do update set notas = excluded.notas, media = excluded.media, comentario = excluded.comentario;
    end if;
  end if;
end;
$$;
