#!/bin/bash
# Compara indicadores antigos (TS) e novos (SQL) num banco local já com dados (fase0_pr6_dados.sql).
# Uso: bash supabase/testes/comparar_indicadores.sh <host-socket> <porta> <de> <ate> [responsavel]
set -e
RAIZ=$(cd "$(dirname "$0")/../.." && pwd); H=$1; PORTA=$2; DE=$3; ATE=$4; RESP=${5:-}
TMP=$(mktemp -d)
PSQL="psql -h $H -p $PORTA -U postgres -d portal -At"
$PSQL -v de="$DE" -v ate="$ATE" -f "$RAIZ/supabase/testes/dados_comerciais.sql" > "$TMP/dados.json"
R=${RESP:+"'$RESP'"}; R=${R:-null}
$PSQL -c "select public.indicadores_comerciais('$DE', '$ATE', $R)" > "$TMP/sql.json"
$PSQL -c "select json_object_agg(k, public.valor_indicador_meta(k, '$DE', '$ATE', $R)) from unnest(array['faturamento','contratos','propostas',
  'diagnosticos','oportunidades','diagnosticos_fora_londrina','diagnosticos_pos_venda','diagnosticos_membros_novos','leads_novos','prospectday','coldcalls']) k" > "$TMP/metas.json"
cd "$RAIZ" && npx -y tsx supabase/testes/comparar_indicadores.ts "$TMP/dados.json" "$TMP/sql.json" "$TMP/metas.json" $RESP
