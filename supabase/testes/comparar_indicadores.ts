/* eslint-disable */
// @ts-nocheck
// Compara o cálculo antigo (TypeScript, indicadores_v1.ts) com o novo (SQL) sobre os mesmos dados.
// Uso: npx tsx supabase/testes/comparar_indicadores.ts <dados.json> <sql.json> <metas_sql.json> [responsavel]
import { readFileSync } from "node:fs";
import { calcularIndicadores, valorIndicadorMeta } from "./indicadores_v1";

const [dadosArq, sqlArq, metasArq, resp] = process.argv.slice(2);
const dados = JSON.parse(readFileSync(dadosArq, "utf8"));
const sql = JSON.parse(readFileSync(sqlArq, "utf8"));
const metasSql: Record<string, number> = JSON.parse(readFileSync(metasArq, "utf8"));
const antigo = calcularIndicadores(dados, resp || null);

let erros = 0;
const igual = (a: unknown, b: unknown) =>
  typeof a === "number" || typeof b === "number" ? (a == null && b == null) || Math.abs(Number(a) - Number(b)) < 1e-6 : a === b;
function comparar(nome: string, a: unknown, b: unknown) {
  if (!igual(a, b)) { erros++; console.log(`DIFERENTE ${nome}: antigo=${JSON.stringify(a)} novo=${JSON.stringify(b)}`); }
}
// Listas: compara como conjuntos (a ordem de empates pode variar), pela chave indicada
function compararLista(nome: string, a: any[], b: any[], chave: string, campos: string[]) {
  const mb = new Map(b.map((x) => [x[chave], x]));
  if (a.length !== b.length) { erros++; console.log(`DIFERENTE ${nome}: ${a.length} linhas no antigo, ${b.length} no novo`); }
  for (const x of a) {
    const y = mb.get(x[chave]);
    if (!y) { erros++; console.log(`DIFERENTE ${nome}: falta ${x[chave]} no novo`); continue; }
    for (const c of campos) comparar(`${nome}[${x[chave]}].${c}`, x[c], y[c]);
  }
}

for (const k of Object.keys(antigo.resumo)) comparar(`resumo.${k}`, (antigo.resumo as any)[k], sql.resumo[k]);
compararLista("funil", antigo.funil, sql.funil, "chave", ["quantidade", "conversao"]);
compararLista("tempoPorFase", antigo.tempoPorFase, sql.tempoPorFase, "fase", ["sla", "mediaDias", "amostras"]);
compararLista("pessoas", antigo.pessoas, sql.pessoas.filter((p: any) => p.leads + p.diagnosticos + p.propostas + p.contratos + p.atividades > 0),
  "id", ["leads", "diagnosticos", "propostas", "contratos", "faturamento", "atividades"]);
compararLista("origens", antigo.origens, sql.origens, "origem", ["leads", "diagnosticos", "contratos"]);
compararLista("motivosPerda", antigo.motivosPerda, sql.motivosPerda, "motivo", ["quantidade"]);
compararLista("motivosDesqualificacao", antigo.motivosDesqualificacao, sql.motivosDesqualificacao, "motivo", ["quantidade"]);
compararLista("atividadesPorTipo", antigo.atividadesPorTipo, sql.atividadesPorTipo, "tipo", ["realizadas", "agendadas", "canceladas"]);
for (const [chave, valor] of Object.entries(metasSql)) comparar(`meta.${chave}`, valorIndicadorMeta(dados, chave, resp || null), valor);

console.log(erros ? `${erros} diferença(s)` : `OK: todos os números iguais${resp ? ` (responsável ${resp})` : ""}`);
process.exit(erros ? 1 : 0);
