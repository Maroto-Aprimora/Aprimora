-- Roteiro de teste (dados fictícios): A1 Enriquecedor e A4 Analista gerencial pelo caminho da fila.
\set ON_ERROR_STOP 1
insert into public.pre_cadastros (email, nome) values ('dir@t.com', 'Diretor Teste'), ('ass@t.com', 'Assessor Teste');
insert into public.pre_cadastro_diretorias (pre_cadastro_id, diretoria, cargo)
  select id, 'comercial', case when email like 'dir%' then 'diretor' else 'assessor' end::public.cargo from public.pre_cadastros where email like '%@t.com';
insert into auth.users (id, email) values ('00000000-0000-0000-0000-00000000000d', 'dir@t.com'), ('00000000-0000-0000-0000-00000000000a', 'ass@t.com');
insert into privado.config (chave, valor) values ('n8n_segredo_hash', encode(extensions.digest('s', 'sha256'), 'hex'));
update public.agentes set ativo = true where chave in ('enriquecedor', 'analista_gerencial');

-- Assessor cria um lead: entra em Entrada e vai sozinho para Enriquecimento → trabalho na fila
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', false);
insert into public.empresas (id, nome, cidade, telefone) values ('10000000-0000-0000-0000-000000000001', 'Metalúrgica Horizonte', 'Londrina', '(43) 3333-0000');
insert into public.negocios (id, funil_id, empresa_id, titulo, fase_id)
select '30000000-0000-0000-0000-000000000001', f.id, '10000000-0000-0000-0000-000000000001', 'Metalúrgica Horizonte',
       (select id from public.fases where chave = 'entrada') from public.funis f where f.chave = 'comercial';
reset role;
select count(*) as trabalhos_enriquecedor, max(payload -> 'empresa' ->> 'nome') as empresa from public.trabalhos where agente = 'enriquecedor';

-- n8n devolve o resultado
select public.n8n_concluir('s', (public.n8n_reservar('s', 'enriquecedor', 1) -> 'trabalhos' -> 0 ->> 'id')::uuid, '{
  "dados_publicos": {"cnpj": "12345678000199", "razao_social": "METALURGICA HORIZONTE LTDA", "telefone": "(43) 9999-9999",
                     "endereco": "Rua A, 100", "cidade": "Cambé", "uf": "pr", "cnae": "Fabricação de estruturas metálicas", "porte": "ME", "situacao": "ATIVA"},
  "segmento": "Metalmecânico",
  "decisor": {"nome": "Carlos Souza", "cargo": "Sócio-administrador", "email": "", "linkedin": "https://linkedin.com/in/carlos"},
  "emails": ["contato@horizonte.com.br"],
  "hipoteses_dor": ["Atrasos na entrega", "Estoque sem controle"],
  "resumo": "Empresa de estruturas metálicas em Londrina.", "fontes": ["https://horizonte.com.br"]}'::jsonb) ->> 'ok' as concluiu;
select cnpj, razao_social, telefone as tel_mantido, cidade as cidade_mantida, uf, porte, (select nome from public.segmentos where id = segmento_id) segmento,
       enriquecido_em is not null as enriquecida from public.empresas;
select titulo, responsavel_id = '00000000-0000-0000-0000-00000000000a' as para_quem_criou, conteudo ->> 'decisor_nome' decisor from public.aprovacoes;
select titulo, descricao from public.tarefas where chave like 'completar_dados:%';

-- Assessor aprova editando o cargo: vira contato decisor, e-mail na empresa, dores no negócio
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', false);
update public.aprovacoes set conteudo = conteudo || '{"decisor_cargo": "Diretor industrial"}', status = 'aprovada';
reset role;
select nome, cargo, decisor, linkedin from public.contatos;
select email_principal from public.empresas;
select contato_id is not null as contato_no_negocio, dores_identificadas from public.negocios;

-- "Enriquecer agora" (diretor; o assessor só edita quando for responsável): recusa se já estiver na fila
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000d', false);
select public.enriquecer_negocio('30000000-0000-0000-0000-000000000001') is not null as reenfileirou;
do $$ begin perform public.enriquecer_negocio('30000000-0000-0000-0000-000000000001'); raise exception 'deveria ter falhado';
exception when others then if sqlerrm like 'deveria%' then raise; end if; raise notice 'OK recusou: %', sqlerrm; end $$;

-- A4: só o diretor gera; o relatório nasce com os números e espera a análise
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', false);
do $$ begin perform public.gerar_relatorio_ri(); raise exception 'deveria ter falhado';
exception when others then if sqlerrm like 'deveria%' then raise; end if; raise notice 'OK recusou: %', sqlerrm; end $$;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000d', false);
select public.gerar_relatorio_ri() as relatorio_id \gset
reset role;
select status, jsonb_array_length(dados -> 'membros') as membros, dados -> 'semana' -> 'resumo' ->> 'leadsNovos' as leads_semana from public.relatorios;
select public.n8n_concluir('s', (public.n8n_reservar('s', 'analista_gerencial', 1) -> 'trabalhos' -> 0 ->> 'id')::uuid,
  '{"analise": {"resumo": "Semana com 1 lead novo.", "destaques": ["Lead enriquecido sem digitação"], "pontos_atencao": [], "planos": []}}') ->> 'ok';
select status, analise ->> 'resumo' as resumo from public.relatorios;
-- Falha esgotada marca o relatório com erro
update public.agentes set ativo = true where chave = 'analista_gerencial';
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000d', false);
select public.gerar_relatorio_ri() is not null;
reset role;
do $$ declare i int; v uuid; begin
  for i in 1..3 loop
    update public.trabalhos set proximo_em = now() where agente = 'analista_gerencial' and status = 'pendente';
    v := (public.n8n_reservar('s', 'analista_gerencial', 1) -> 'trabalhos' -> 0 ->> 'id')::uuid;
    perform public.n8n_falhar('s', v, 'Gemini', 'cota excedida');
  end loop; end $$;
select status, erro from public.relatorios order by created_at;
