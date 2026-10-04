-- =====================================================================
-- Fase 2b — Navegação por diretoria, Vice-Presidência e pontuação
-- =====================================================================

-- RH passa a se chamar Vice-Presidência (o slug "rh" fica, para não quebrar referências).
-- Ordem do menu: Presidência, Vice-Presidência, Projetos, Comercial, Marketing.
update public.diretorias set nome = 'Vice-Presidência', ordem = 2 where slug = 'rh';
update public.diretorias set ordem = 1 where slug = 'presidencia';
update public.diretorias set ordem = 3 where slug = 'projetos';
update public.diretorias set ordem = 4 where slug = 'comercial';
update public.diretorias set ordem = 5 where slug = 'marketing';

-- O último processo seletivo terminou no fim de maio de 2026
update public.processos_seletivos set nome = 'Processo seletivo 2026/1', data = '2026-05-31' where data = '2026-08-01';
update public.pre_cadastros set data_entrada = '2026-05-31' where data_entrada = '2026-08-01';
update public.membros set data_entrada = '2026-05-31' where data_entrada = '2026-08-01';

-- ---------------------------------------------------------------------
-- Pontuação (gerida pela Vice-Presidência)
-- Pontos de punição por atividades não realizadas: de 0 a 12, com marco no 6.
-- Cada lançamento soma (ou abona, se negativo). Lançamentos não são apagados, só cancelados.
-- ---------------------------------------------------------------------
create table public.pontuacoes (
  id uuid primary key default gen_random_uuid(),
  membro_id uuid not null references public.membros (id) on delete cascade,
  pontos smallint not null check (pontos between -12 and 12 and pontos <> 0),
  motivo text not null check (length(trim(motivo)) >= 3),
  data date not null default current_date,
  cancelado_em timestamptz,
  cancelado_por uuid references public.membros (id) on delete set null,
  criado_por uuid references public.membros (id) on delete set null default auth.uid(),
  created_at timestamptz not null default now()
);
create index pontuacoes_membro_idx on public.pontuacoes (membro_id) where cancelado_em is null;
comment on table public.pontuacoes is
  'Sistema de pontos da Aprimora (punição). Total = soma dos lançamentos não cancelados, limitado a 0..12; marco em 6.';

-- Só o cancelamento pode mudar depois de lançado
create or replace function public.proteger_pontuacao()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if (new.membro_id, new.pontos, new.motivo, new.data, new.criado_por, new.created_at)
     is distinct from (old.membro_id, old.pontos, old.motivo, old.data, old.criado_por, old.created_at) then
    raise exception 'Um lançamento de pontos não pode ser editado; cancele e lance de novo';
  end if;
  if new.cancelado_em is not null and old.cancelado_em is null then
    new.cancelado_por := (select auth.uid());
  end if;
  return new;
end;
$$;
create trigger proteger_pontuacao before update on public.pontuacoes
  for each row execute function public.proteger_pontuacao();

-- Avisa a pessoa quando recebe pontos
create or replace function public.notificar_pontuacao()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_total int;
begin
  select greatest(0, least(12, coalesce(sum(pontos), 0))) into v_total
    from public.pontuacoes where membro_id = new.membro_id and cancelado_em is null;
  perform privado.notificar(new.membro_id, 'pontuacao',
    case when new.pontos > 0 then 'Você recebeu ' || new.pontos || ' ponto(s)' else 'Você teve ' || abs(new.pontos) || ' ponto(s) abonado(s)' end,
    new.motivo || ' · total atual: ' || v_total || '/12', '/vice-presidencia/pontuacao', 'pontuacao:' || new.id);
  return null;
end;
$$;
create trigger notificar_pontuacao after insert on public.pontuacoes
  for each row execute function public.notificar_pontuacao();

revoke all on function public.proteger_pontuacao(), public.notificar_pontuacao() from public, anon, authenticated;

alter table public.pontuacoes enable row level security;
-- Cada um vê a própria pontuação; diretores veem a de todos
create policy pontuacoes_ler on public.pontuacoes for select to authenticated
  using (membro_id = (select auth.uid()) or (select privado.eh_diretor()));
-- Só a diretoria da Vice-Presidência lança e cancela
create policy pontuacoes_lancar on public.pontuacoes for insert to authenticated
  with check ((select privado.eh_diretor_de('rh')));
create policy pontuacoes_cancelar on public.pontuacoes for update to authenticated
  using ((select privado.eh_diretor_de('rh'))) with check ((select privado.eh_diretor_de('rh')));

grant select, insert, update on public.pontuacoes to authenticated;
revoke all on public.pontuacoes from anon;

-- Tarefas são gerais: quem é responsável enxerga a tarefa mesmo sendo de outra diretoria
alter policy tarefas_ler on public.tarefas
  using (privado.pertence_a(diretoria) or privado.eh_diretor() or privado.responsavel_da_tarefa(id));
