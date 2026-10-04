"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { criarClienteServidor } from "@/lib/supabase/server";
import { mensagemDeErro } from "@/lib/erros";

export type Resultado = { ok: true } | { ok: false; erro: string };

function revalidar() {
  revalidatePath("/configuracoes");
  revalidatePath("/funil");
}

const esquemaFase = z.object({
  nome: z.string().trim().min(2),
  descricao: z.string().trim().nullable(),
  sla_dias: z.number().int().positive().nullable(),
  acao_sla: z.enum(["alertar", "mover"]).nullable(),
  fase_destino_sla: z.string().uuid().nullable(),
  probabilidade: z.number().min(0).max(1),
  distribui_responsavel: z.boolean(),
  ativa: z.boolean(),
});

export async function salvarFase(id: string, dados: z.input<typeof esquemaFase>): Promise<Resultado> {
  const v = esquemaFase.safeParse(dados);
  if (!v.success) return { ok: false, erro: v.error.issues[0].message };
  if (v.data.acao_sla === "mover" && (!v.data.fase_destino_sla || !v.data.sla_dias))
    return { ok: false, erro: "Para mover automaticamente, informe o SLA em dias e a fase de destino." };
  const supabase = await criarClienteServidor();
  const { data, error } = await supabase.from("fases").update(v.data).eq("id", id).select("id");
  if (error) return { ok: false, erro: mensagemDeErro(error) };
  if (!data?.length) return { ok: false, erro: "Só o Diretor Comercial altera as fases." };
  revalidar();
  return { ok: true };
}

const esquemaCampo = z.object({
  fase_id: z.string().uuid(),
  rotulo: z.string().trim().min(2),
  tipo: z.enum(["texto", "texto_longo", "data", "numero", "moeda", "membros", "selecao", "booleano", "link"]),
  obrigatorio: z.boolean(),
  opcoes: z.array(z.string()).nullable(),
});

function chaveDe(rotulo: string) {
  return rotulo.toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "").replace(/[^a-z0-9]+/g, "_").replace(/^_|_$/g, "").slice(0, 40);
}

export async function salvarCampo(id: string | null, dados: z.input<typeof esquemaCampo>): Promise<Resultado> {
  const v = esquemaCampo.safeParse(dados);
  if (!v.success) return { ok: false, erro: v.error.issues[0].message };
  const supabase = await criarClienteServidor();
  const q = id
    ? supabase.from("fase_campos").update({ rotulo: v.data.rotulo, obrigatorio: v.data.obrigatorio, opcoes: v.data.opcoes }).eq("id", id).select("id")
    : supabase.from("fase_campos").insert({ ...v.data, chave: chaveDe(v.data.rotulo), ordem: 50 }).select("id");
  const { data, error } = await q;
  if (error) return { ok: false, erro: mensagemDeErro(error) };
  if (!data?.length) return { ok: false, erro: "Só o Diretor Comercial altera os campos." };
  revalidar();
  return { ok: true };
}

export async function excluirCampo(id: string): Promise<Resultado> {
  const supabase = await criarClienteServidor();
  const { data, error } = await supabase.from("fase_campos").delete().eq("id", id).select("id");
  if (error) return { ok: false, erro: mensagemDeErro(error) };
  if (!data?.length) return { ok: false, erro: "Só o Diretor Comercial altera os campos." };
  revalidar();
  return { ok: true };
}

const TABELAS = ["motivos", "origens", "segmentos", "servicos"] as const;
type TabelaLista = (typeof TABELAS)[number];

export async function salvarItem(
  tabela: TabelaLista,
  id: string | null,
  dados: { nome: string; ativo: boolean; tipo?: "perda" | "desqualificacao"; descricao?: string | null; area?: "negocios" | "producao" | "qualidade" },
): Promise<Resultado> {
  if (!TABELAS.includes(tabela)) return { ok: false, erro: "Tabela inválida." };
  const nome = dados.nome.trim();
  if (nome.length < 2) return { ok: false, erro: "Informe o nome." };
  const supabase = await criarClienteServidor();
  const base = { nome, ativo: dados.ativo, diretoria: "comercial" };
  // Cada tabela tem colunas próprias; por isso um caminho para cada uma.
  const q =
    tabela === "motivos"
      ? id
        ? supabase.from("motivos").update(base).eq("id", id).select("id")
        : supabase.from("motivos").insert({ ...base, tipo: dados.tipo ?? "perda" }).select("id")
      : tabela === "servicos"
        ? id
          ? supabase.from("servicos").update({ ...base, ...(dados.descricao !== undefined ? { descricao: dados.descricao } : {}) }).eq("id", id).select("id")
          : supabase.from("servicos").insert({ ...base, area: dados.area ?? "negocios", descricao: dados.descricao ?? null }).select("id")
        : id
          ? supabase.from(tabela).update(base).eq("id", id).select("id")
          : supabase.from(tabela).insert(base).select("id");
  const { data, error } = await q;
  if (error) return { ok: false, erro: mensagemDeErro(error) };
  if (!data?.length) return { ok: false, erro: "Só o Diretor Comercial altera as configurações." };
  revalidar();
  return { ok: true };
}
