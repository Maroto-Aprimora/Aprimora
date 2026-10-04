/** Traduz mensagens comuns do Supabase/Postgres para português. */
export function mensagemDeErro(erro: unknown): string {
  const msg = erro instanceof Error ? erro.message : typeof erro === "object" && erro && "message" in erro ? String((erro as { message: unknown }).message) : String(erro);
  if (/Invalid login credentials/i.test(msg)) return "E-mail ou senha incorretos.";
  if (/Email not confirmed/i.test(msg)) return "Confirme seu e-mail pelo link enviado antes de entrar.";
  if (/não está pré-cadastrado|Database error saving new user/i.test(msg))
    return "Este e-mail não está pré-cadastrado. Peça ao diretor da sua diretoria para cadastrá-lo.";
  if (/rate limit|only request this after/i.test(msg)) return "Muitas tentativas. Aguarde um minuto e tente de novo.";
  if (/Password should be at least/i.test(msg)) return "A senha precisa ter pelo menos 8 caracteres.";
  if (/same.*password|different from the old/i.test(msg)) return "A nova senha precisa ser diferente da atual.";
  if (/row-level security|permission denied/i.test(msg)) return "Você não tem permissão para fazer isso.";
  if (/duplicate key.*cnpj/i.test(msg)) return "Já existe uma empresa com este CNPJ.";
  if (/duplicate key/i.test(msg)) return "Este registro já existe.";
  return msg;
}
