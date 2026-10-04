"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { criarClienteServidor } from "@/lib/supabase/server";
import { mensagemDeErro } from "@/lib/erros";

export type Resultado<T = undefined> = { ok: true; dados?: T } | { ok: false; erro: string };

const nulo = (v: unknown) => (typeof v === "string" && v.trim() === "" ? null : typeof v === "string" ? v.trim() : v);
const txt = z.preprocess(nulo, z.string().nullable().optional());
const email = z.preprocess(nulo, z.string().email("E-mail inválido.").nullable().optional());
const uuid = z.preprocess(nulo, z.string().uuid().nullable().optional());
const data = z.preprocess(nulo, z.string().regex(/^\d{4}-\d{2}-\d{2}$/).nullable().optional());

const esquemaEmpresa = z.object({
  nome: z.string().trim().min(2, "Informe o nome da empresa."),
  razao_social: txt,
  cnpj: z.preprocess(nulo, z.string().refine((v) => v.replace(/\D/g, "").length === 14, "CNPJ deve ter 14 dígitos.").nullable().optional()),
  segmento_id: uuid,
  telefone: txt,
  email_principal: email,
  email_secundario: email,
  email_terciario: email,
  site: txt,
  rede_social: txt,
  endereco: txt,
  cidade: txt,
  uf: z.preprocess((v) => (typeof v === "string" && v.trim() ? v.trim().toUpperCase() : null), z.string().length(2, "UF com 2 letras.").nullable().optional()),
  observacoes: txt,
});

const esquemaContato = z.object({
  nome: z.string().trim().min(2, "Informe o nome do contato."),
  cargo: txt,
  decisor: z.boolean().default(false),
  email: email,
  telefone: txt,
  linkedin: txt,
  nao_contatar: z.boolean().default(false),
  observacoes: txt,
});

const esquemaLead = z.object({
  empresa: esquemaEmpresa,
  decisor: esquemaContato.partial().extend({ nome: txt }),
  negocio: z.object({
    fase_id: z.string().uuid("Escolha a fase."),
    origem_id: z.string().uuid("Informe a origem do lead."),
    origem_detalhe: txt,
    responsavel_id: uuid,
    data_coldcall_1: data,
    data_coldcall_2: data,
    dores_identificadas: txt,
  }),
});

/** Cria empresa + decisor (opcional) + negócio no funil, de uma vez. */
export async function criarLead(entrada: unknown): Promise<Resultado<{ negocioId: string }>> {
  const v = esquemaLead.safeParse(entrada);
  if (!v.success) return { ok: false, erro: v.error.issues[0].message };
  const supabase = await criarClienteServidor();

  const { data: empresa, error: e1 } = await supabase.from("empresas").insert(v.data.empresa).select("id, nome").single();
  if (e1) return { ok: false, erro: mensagemDeErro(e1) };

  let contatoId: string | null = null;
  if (v.data.decisor.nome) {
    const { data: contato, error: e2 } = await supabase
      .from("contatos")
      .insert({ ...v.data.decisor, nome: v.data.decisor.nome, decisor: true, empresa_id: empresa.id })
      .select("id")
      .single();
    if (e2) return { ok: false, erro: mensagemDeErro(e2) };
    contatoId = contato.id;
  }

  const { data: fase } = await supabase.from("fases").select("funil_id").eq("id", v.data.negocio.fase_id).single();
  if (!fase) return { ok: false, erro: "Fase inválida." };
  const { data: negocio, error: e3 } = await supabase
    .from("negocios")
    .insert({ ...v.data.negocio, funil_id: fase.funil_id, empresa_id: empresa.id, contato_id: contatoId, titulo: empresa.nome })
    .select("id")
    .single();
  if (e3) return { ok: false, erro: mensagemDeErro(e3) };

  revalidatePath("/funil");
  revalidatePath("/empresas");
  revalidatePath("/painel");
  return { ok: true, dados: { negocioId: negocio.id } };
}

export async function salvarEmpresa(id: string, dados: unknown): Promise<Resultado> {
  const v = esquemaEmpresa.safeParse(dados);
  if (!v.success) return { ok: false, erro: v.error.issues[0].message };
  const supabase = await criarClienteServidor();
  const { data: r, error } = await supabase.from("empresas").update(v.data).eq("id", id).select("id");
  if (error) return { ok: false, erro: mensagemDeErro(error) };
  if (!r?.length) return { ok: false, erro: "Você não tem permissão para editar esta empresa." };
  revalidatePath(`/empresas/${id}`);
  revalidatePath("/empresas");
  return { ok: true };
}

export async function salvarContato(empresaId: string, contatoId: string | null, dados: unknown): Promise<Resultado> {
  const v = esquemaContato.safeParse(dados);
  if (!v.success) return { ok: false, erro: v.error.issues[0].message };
  const supabase = await criarClienteServidor();
  const q = contatoId
    ? supabase.from("contatos").update(v.data).eq("id", contatoId).select("id")
    : supabase.from("contatos").insert({ ...v.data, empresa_id: empresaId }).select("id");
  const { data: r, error } = await q;
  if (error) return { ok: false, erro: mensagemDeErro(error) };
  if (!r?.length) return { ok: false, erro: "Você não tem permissão para alterar este contato." };
  revalidatePath(`/empresas/${empresaId}`);
  return { ok: true };
}

export async function excluirContato(empresaId: string, contatoId: string): Promise<Resultado> {
  const supabase = await criarClienteServidor();
  const { data: r, error } = await supabase.from("contatos").delete().eq("id", contatoId).select("id");
  if (error) return { ok: false, erro: mensagemDeErro(error) };
  if (!r?.length) return { ok: false, erro: "Você não tem permissão para excluir este contato." };
  revalidatePath(`/empresas/${empresaId}`);
  return { ok: true };
}

export async function excluirEmpresa(id: string): Promise<Resultado> {
  const supabase = await criarClienteServidor();
  const { data: r, error } = await supabase.from("empresas").delete().eq("id", id).select("id");
  if (error) {
    if (/foreign key|violates/i.test(error.message)) return { ok: false, erro: "Exclua ou mova os negócios desta empresa antes." };
    return { ok: false, erro: mensagemDeErro(error) };
  }
  if (!r?.length) return { ok: false, erro: "Só o diretor pode excluir empresas." };
  revalidatePath("/empresas");
  return { ok: true };
}

export type Semelhante = { id: string; nome: string; cidade: string | null; motivo: string };

/** Empresas parecidas, para avisar sobre possível duplicidade antes de cadastrar. */
export async function buscarSemelhantes(nome: string, cnpj?: string, telefone?: string, site?: string): Promise<Semelhante[]> {
  if ((nome ?? "").trim().length < 3 && !cnpj && !telefone) return [];
  const dominio = (site ?? "").replace(/^https?:\/\//, "").replace(/^www\./, "").split("/")[0] || undefined;
  const supabase = await criarClienteServidor();
  const { data } = await supabase.rpc("empresas_semelhantes", {
    _nome: nome ?? "", _cnpj: cnpj || undefined, _telefone: telefone || undefined, _dominio: dominio,
  });
  return (data ?? []).map((d) => ({ id: d.id, nome: d.nome, cidade: d.cidade, motivo: d.motivo }));
}
