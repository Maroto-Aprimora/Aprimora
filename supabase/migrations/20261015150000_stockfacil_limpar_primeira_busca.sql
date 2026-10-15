-- Ajuste dos dados da primeira busca do StockFacil (o fluxo 13 já foi corrigido): o gosom devolve o id interno do job em
-- input_id (não o termo), o endereço começa com o nome da loja e lojas sem avaliação vêm com nota 0.
update public.stockfacil_leads set termo = null,
  endereco = case when endereco like nome || ' - %' then substr(endereco, length(nome) + 4) else endereco end,
  nota = case when coalesce(avaliacoes, 0) = 0 then null else nota end
where busca_id is not null;
