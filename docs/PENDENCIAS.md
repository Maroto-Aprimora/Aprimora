# Pendências fora do código

Itens que dependem de configuração ou decisão e ficaram para depois. Atualize ao resolver.

| Item | Por que importa | Como resolver |
|---|---|---|
| SMTP próprio no Supabase | Sem ele, os e-mails de convite, primeiro acesso e senha só chegam para quem é da equipe do projeto no Supabase, com limite de poucos por hora | Ativar a verificação em duas etapas no e-mail da Aprimora (gratuito) e usar senha de app do Google, ou usar o Brevo (300 e-mails/dia grátis). Passos em `CONFIGURAR-EMAIL-E-LOGIN.md` |
| Proteção contra senhas vazadas | Bloqueia senhas que já vazaram na internet | Só existe no plano pago do Supabase (Authentication → Policies) |
| Conta de teste | `teste.automatizado@aprimoraej.com` foi usada nos testes e está desativada | Excluir pelo painel do Supabase quando não for mais necessária |
| Regras da pontuação | Hoje a pontuação soma desde o início e o 6 é só um aviso visual | Definir se zera por semestre e o que acontece ao chegar em 6 e em 12 |
| Exportação completa do Pipefy | O relatório recebido tem só título, fase, criador e data | Exportar os cards com todos os campos (empresa, contato, telefone, e-mail, valor) para a migração |
| Remover dados fictícios | Os indicadores e metas somam os negócios de teste | Rodar `supabase/dados/remover_dados_ficticios.sql` antes de importar os dados reais |
