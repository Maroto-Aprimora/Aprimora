# 13 · Temporário · Leads StockFacil

Fluxo criado no n8n pelo conector em 15/10/2026 (id `hSJfnqVuBNx0sDCE`, publicado).

- **Scraper:** projeto Docker `gmaps-aprimora` na mesma VPS (`gosom/google-maps-scraper`, modo `-web`), container
  `gmaps-scraper` só na rede interna `n8n-aprimora_default` (sem porta pública). O n8n chama `http://gmaps-scraper:8080`.
- **Fluxo:** a cada 2 min reserva 1 trabalho do agente `stockfacil` → `POST /api/v1/jobs` (termos "tipo em Londrina, PR",
  `lang: pt`, `depth: 2`, `max_time` de 10 a 22 min) → espera em ciclos de 1 min (até 26) → baixa o CSV → converte
  (título, categoria, endereço, bairro, telefone, site, nota, avaliações, place_id, link) → devolve ao portal
  (`privado.aplicar_stockfacil` tira duplicados por place_id/telefone e fechados de vez) → apaga o job no gosom.
- **Portal:** página `/stockfacil` (só o Diretor Comercial), exportação em `/stockfacil/exportar` (.xlsx ou `?formato=csv`).

Para desmontar quando acabar: arquivar o fluxo no n8n, apagar o projeto `gmaps-aprimora` no Docker Manager da Hostinger e,
se quiser, as tabelas `stockfacil_buscas` e `stockfacil_leads` com uma nova migração.
