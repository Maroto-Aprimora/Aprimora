-- Roteiro de teste (dados fictícios): Fase 3 · cadência de e-mail (A5 Redator, A6 Monitor de respostas, A7 Organizador)
\set ON_ERROR_STOP 1
insert into public.pre_cadastros (email, nome) values ('dir@t.com', 'Diretor Teste'), ('ass@t.com', 'Assessor Teste');
insert into public.pre_cadastro_diretorias (pre_cadastro_id, diretoria, cargo)
  select id, 'comercial', case when email like 'dir%' then 'diretor' else 'assessor' end::public.cargo from public.pre_cadastros where email like '%@t.com';
insert into auth.users (id, email) values ('00000000-0000-0000-0000-00000000000d', 'dir@t.com'), ('00000000-0000-0000-0000-00000000000a', 'ass@t.com');
insert into privado.config (chave, valor) values ('n8n_segredo_hash', encode(extensions.digest('s', 'sha256'), 'hex'));
update public.agentes set ativo = true where chave in ('redator', 'monitor_respostas', 'organizador_dia');
-- Simula o n8n reservando um trabalho específico
create function privado.t_reservar(_id uuid) returns uuid language sql as $$
  update public.trabalhos set status = 'processando', reservado_em = now(), tentativas = tentativas + 1 where id = _id returning id $$;

select versao, nome, uso, regra, (select count(*) from public.copies_email_mensagens m where m.copy_id = c.id) mensagens from public.copies_email c order by versao;

-- Copy B na mesma regra (teste A/B) e uma copy específica para quem não tem site
insert into public.copies_email (nome, uso, regra) values ('Apresentação curta', 'cadencia', 'qualquer') returning versao as versao_b \gset
insert into public.copies_email_mensagens (copy_id, passo_id, assunto, corpo)
select c.id, p.id, 'Ideia para {{empresa}}', '{{saudacao}}, {{nome_contato}}. Versão B.' from public.copies_email c, public.cadencia_passos p
 where c.versao = :versao_b and p.canal = 'email' and p.dia = 0;
insert into public.copies_email (nome, uso, regra) values ('Sem site', 'cadencia', 'sem_site');
insert into public.copies_email_mensagens (copy_id, passo_id, assunto, corpo)
select c.id, p.id, 'Presença digital da {{empresa}}', 'Texto sem site' from public.copies_email c, public.cadencia_passos p
 where c.nome = 'Sem site' and p.canal = 'email' and p.dia = 0;

-- Três leads do assessor em E-mail (D0 hoje): dois com site e e-mail; um sem site; um sem e-mail nenhum
insert into public.empresas (id, nome, cidade, site, email_principal) values
 ('10000000-0000-0000-0000-000000000001', 'Metalúrgica Horizonte', 'Londrina', 'horizonte.com.br', 'contato@horizonte.com.br'),
 ('10000000-0000-0000-0000-000000000002', 'Laticínios Serra', 'Maringá', 'serra.com.br', null),
 ('10000000-0000-0000-0000-000000000003', 'Padaria Central', 'Cambé', null, 'padaria@central.com'),
 ('10000000-0000-0000-0000-000000000004', 'Gráfica Norte', 'Ibiporã', 'norte.com', null);
insert into public.contatos (id, empresa_id, nome, cargo, email, decisor) values
 ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'Carlos', 'Sócio', 'Carlos@Horizonte.com.br', true),
 ('20000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000002', 'Ana', 'Diretora', 'ana@serra.com.br', true);
insert into public.negocios (id, funil_id, empresa_id, titulo, fase_id, responsavel_id, contato_id)
select ('30000000-0000-0000-0000-00000000000' || i)::uuid, f.id, ('10000000-0000-0000-0000-00000000000' || i)::uuid, 'Lead ' || i,
       (select id from public.fases where chave = 'email'), '00000000-0000-0000-0000-00000000000a',
       case i when 1 then '20000000-0000-0000-0000-000000000001'::uuid end
from public.funis f, generate_series(1, 4) i where f.chave = 'comercial';

select (privado.email_destino(id)).email destino, titulo from public.negocios order by titulo;

-- Tarefas do dia: D0 vira trabalho do Redator (3 leads com e-mail) e tarefa manual (lead sem e-mail)
select privado.gerar_tarefas_diarias() as gerados;
select t.payload ->> 'para' para, t.payload -> 'copy' ->> 'nome' copy, t.payload -> 'mensagem' ->> 'assunto' assunto from public.trabalhos t
 where t.agente = 'redator' order by para;
select titulo from public.tarefas order by titulo;
select tipo, titulo, mensagem from public.notificacoes where tipo = 'resumo_dia';
-- Rodar de novo não duplica
select privado.gerar_tarefas_diarias() as gerados_na_repeticao;

-- n8n devolve a redação do lead 1: vira e-mail em rascunho e "Aprovar e-mail" para o assessor
select public.n8n_concluir('s', privado.t_reservar(t.id), '{"assunto":"Metalúrgica Horizonte: atrasos na entrega","corpo":"Bom dia, Carlos.\n\nTexto pronto."}') ->> 'ok' concluiu
from public.trabalhos t where t.payload ->> 'para' = 'carlos@horizonte.com.br';
select status, para, assunto, uso from public.emails;
select tipo, titulo, conteudo ->> 'para' para from public.aprovacoes;

-- Aprovar com variável sobrando é recusado
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', false);
do $$ begin
  update public.aprovacoes set conteudo = conteudo || '{"corpo":"Olá {{nome_contato}}"}', status = 'aprovada', decidido_por = auth.uid() where tipo = 'email';
  raise exception 'deveria ter falhado';
exception when others then if sqlerrm like 'deveria%' then raise; end if; raise notice 'OK recusou: %', sqlerrm; end $$;
-- Aprovar com edição: vai para a fila de envio na janela comercial
update public.aprovacoes set conteudo = conteudo || '{"corpo":"Bom dia, Carlos.\n\nTexto revisado."}', status = 'aprovada', decidido_por = auth.uid() where tipo = 'email';
reset role;
select e.status, e.corpo, t.tipo, t.proximo_em >= now() - interval '1 minute' janela_ok from public.emails e join public.trabalhos t on t.id = e.envio_trabalho_id;

-- n8n envia e devolve os ids do Gmail
update public.trabalhos set proximo_em = now() where tipo = 'enviar_email';
select public.n8n_concluir('s', privado.t_reservar((select id from public.trabalhos where tipo = 'enviar_email' and status = 'pendente' order by created_at limit 1)), '{"gmail_id":"g1","thread_id":"th1"}') ->> 'ok' enviou;
select status, gmail_id, thread_id, enviado_em is not null from public.emails;

-- Monitor: mensagem de outro fio é ignorada; a resposta do Carlos entra, notifica e vai para classificação; repetir não duplica
select public.n8n_registrar_respostas('s', '[
  {"gmail_id":"g1","thread_id":"th1","de":"comercial@aprimoraej.com","trecho":"o próprio e-mail"},
  {"gmail_id":"x9","thread_id":"outro","de":"spam@x.com","trecho":"promoção"},
  {"gmail_id":"r1","thread_id":"th1","de":"Carlos <carlos@horizonte.com.br>","assunto":"Re: atrasos","trecho":"Tenho interesse, podemos falar semana que vem?"}]') resposta;
select public.n8n_registrar_respostas('s', '[{"gmail_id":"r1","thread_id":"th1","trecho":"x"}]') ->> 'respostas' respostas_na_repeticao;
select tipo, titulo from public.notificacoes where tipo = 'resposta_email';

-- Classificação "interessado": o card vai sozinho para Oportunidade e a cadência pausa
select public.n8n_concluir('s', privado.t_reservar(t.id), '{"classificacao":"interessado","resumo":"Quer conversar na semana que vem."}') ->> 'ok' classificou
from public.trabalhos t where t.agente = 'monitor_respostas';
select (select nome from public.fases where id = n.fase_id) fase, re.classificacao, re.aplicada_em is not null aplicada
from public.negocios n join public.respostas_email re on re.negocio_id = n.id;
select privado.teve_contato('30000000-0000-0000-0000-000000000001', privado.hoje()) teve_contato;

-- Lead 2: e-mail enviado; a resposta é descadastro → contato marcado "não contatar" e aprovação para encerrar
select public.n8n_concluir('s', privado.t_reservar(t.id), '{"assunto":"Oi","corpo":"Texto"}') ->> 'ok' from public.trabalhos t where t.payload ->> 'para' = 'ana@serra.com.br';
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', false);
update public.aprovacoes set status = 'aprovada', decidido_por = auth.uid() where tipo = 'email' and status = 'pendente' and conteudo ->> 'para' = 'ana@serra.com.br';
reset role;
update public.trabalhos set proximo_em = now() where tipo = 'enviar_email' and status = 'pendente';
select public.n8n_concluir('s', privado.t_reservar((select id from public.trabalhos where tipo = 'enviar_email' and status = 'pendente' order by created_at limit 1)), '{"gmail_id":"g2","thread_id":"th2"}') ->> 'ok' enviou;
select public.n8n_registrar_respostas('s', '[{"gmail_id":"r2","thread_id":"th2","de":"Ana <ana@serra.com.br>","trecho":"Por favor, remover"}]') ->> 'respostas';
select public.n8n_concluir('s', privado.t_reservar(t.id), '{"classificacao":"descadastro","resumo":"Pediu para ser removida."}') ->> 'ok'
from public.trabalhos t where t.agente = 'monitor_respostas' and t.status <> 'concluido';
select nome, nao_contatar from public.contatos order by nome;
select tipo, titulo, conteudo ->> 'motivo' motivo from public.aprovacoes where tipo = 'resposta_recusa';
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', false);
update public.aprovacoes set status = 'aprovada', decidido_por = auth.uid() where tipo = 'resposta_recusa';
reset role;
select (select nome from public.fases where id = n.fase_id) fase, (select nome from public.motivos where id = n.motivo_id) motivo, n.encerrado_em is not null encerrado
from public.negocios n where n.id = '30000000-0000-0000-0000-000000000002';
select (privado.email_destino('30000000-0000-0000-0000-000000000002')).email is null bloqueado_por_nao_contatar;

-- Lead 3 (sem site): descartar o e-mail cancela o rascunho
select public.n8n_concluir('s', privado.t_reservar(t.id), '{"assunto":"Oi","corpo":"Texto"}') ->> 'ok' from public.trabalhos t where t.payload ->> 'para' = 'padaria@central.com';
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', false);
update public.aprovacoes set status = 'descartada', decidido_por = auth.uid() where tipo = 'email' and status = 'pendente';
reset role;
select para, status from public.emails order by para;

-- Envio que falha 3 vezes: e-mail com erro e aviso ao responsável
insert into public.emails (negocio_id, membro_id, para, assunto, corpo, status) values ('30000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000a', 'x@y.com', 'a', 'b', 'aprovado') returning id as eid \gset
select privado.enfileirar('redator', 'enviar_email', jsonb_build_object('email_id', :'eid'), '30000000-0000-0000-0000-000000000001', 'enviar:teste') is not null;
update public.trabalhos set max_tentativas = 1 where chave = 'enviar:teste';
select public.n8n_falhar('s', privado.t_reservar((select id from public.trabalhos where tipo = 'enviar_email' and status = 'pendente' order by created_at limit 1)), 'gmail', 'quota') ->> 'status';
select status, erro from public.emails where id = :'eid';

-- Pediu e-mail na ligação: Redator prepara o material
insert into public.ligacoes (negocio_id, membro_id, origem, resultado_id)
select '30000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000a', 'manual', id from public.resultados_ligacao where chave = 'pediu_email';
select payload ->> 'uso' uso, payload -> 'copy' ->> 'nome' copy from public.trabalhos where chave like 'pediu_email:%';

-- Indicadores (diretor)
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000d', false);
select public.indicadores_email(privado.hoje() - 7, privado.hoje()) indicadores;
-- O assessor não cria copies
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', false);
do $$ begin insert into public.copies_email (nome) values ('x'); raise exception 'deveria ter falhado';
exception when others then if sqlerrm like 'deveria%' then raise; end if; raise notice 'OK recusou: %', sqlerrm; end $$;
reset role;
drop function privado.t_reservar(uuid);
