-- =====================================================================
-- v2 · Fase 0 · PR 3 (parte 2) — Apaga as listas antigas de motivos e origens
-- Remapeia antes as referências (no banco atual não há nenhuma).
-- Em produção, rode pelo SQL Editor do Supabase (o conector MCP não executa exclusões).
-- =====================================================================
update public.negocios n set motivo_id = (select m.id from public.motivos m where m.chave = 'outro' and m.tipo = a.tipo and m.diretoria = 'comercial')
  from public.motivos a where n.motivo_id = a.id and a.chave is null;
update public.negocio_historico h set motivo_id = (select m.id from public.motivos m where m.chave = 'outro' and m.tipo = a.tipo and m.diretoria = 'comercial')
  from public.motivos a where h.motivo_id = a.id and a.chave is null;
update public.negocios n set origem_id = (select o.id from public.origens o where o.diretoria = 'comercial' and o.chave = 'manual')
  from public.origens a where n.origem_id = a.id and a.chave is null;
delete from public.motivos where chave is null;
delete from public.origens where chave is null;
