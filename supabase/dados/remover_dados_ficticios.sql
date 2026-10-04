-- Remove TODOS os dados fictícios de teste. Rode antes da migração dos dados reais.
begin;
delete from public.negocios where ficticio;
delete from public.empresas where ficticio; -- contatos saem em cascata
commit;
