# Roteiro de teste — portão da Fase 3 (Cadência de e-mail)

Portão do PE-PA-002: **o toque de e-mail chega pronto para aprovar, sai pela comercial@ e a resposta do lead
move o card sozinha.**

Os testes automáticos de banco estão em `supabase/testes/fase3_cadencia_email.sql` (escolha de copy e alternância A/B,
copy específica para empresa sem site, tarefa manual quando o lead não tem e-mail, aprovação recusada com `{{ }}`
sobrando, envio na janela, resposta no fio certo sem duplicar, interessado → Oportunidade, descadastro → "não contatar"
e Lead não qualificado, descarte cancela o rascunho, falha de envio, "Pediu e-mail" na ligação, só o diretor cria copies).

## Preparação (uma vez)

1. **Cliente OAuth no Google Cloud** (com a conta de administrador do Google Workspace da Aprimora):
   1. https://console.cloud.google.com → criar o projeto **Portal Aprimora**.
   2. **APIs e serviços → Biblioteca**: ativar a **Gmail API**.
   3. **Tela de consentimento OAuth**: tipo de usuário **Interno** (só contas @aprimoraej.com; não precisa de
      verificação do Google), nome "Portal Aprimora", e-mail de suporte comercial@.
   4. **Credenciais → Criar credenciais → ID do cliente OAuth → Aplicativo da Web**. Em **URIs de redirecionamento
      autorizados**, colar: `https://srv2043014.hstgr.cloud/rest/oauth2-credential/callback`.
   5. Copiar o **ID do cliente** e a **Chave secreta** (não mande no chat).
2. **No n8n** → Credentials → **Add credential → Gmail OAuth2 API**: nome **Gmail comercial@**, colar ID e chave e
   clicar em **Sign in with Google** entrando com a conta **comercial@aprimoraej.com**.
3. Me avise que a credencial existe: eu ligo a credencial nos nós dos fluxos **10 (A5 Redator)** e
   **11 (A6 Monitor de respostas)** e publico os dois.
4. No portal, **Config. do funil → Copy**: revisar as três copies iniciais (V1 Apresentação padrão, V2 Material
   pedido na ligação, V3 Follow-up da proposta) e, em "Envio pela comercial@", o nome do remetente e o horário.
5. **Config. do funil → Agentes**: ligar **Redator** e **Monitor de respostas** (o Organizador do dia já está ligado).

## Copies (guia Copy)

- [ ] Clicar num chip de variável com o cursor no corpo insere a variável ali.
- [ ] **Nova copy** com regra "Segmento" exige escolher o segmento; salvar sem assunto num e-mail preenchido é recusado.
- [ ] Desativar uma copy: ela fica cinza e deixa de ser usada; ativar uma copy sem e-mail é recusado.
- [ ] Duas copies ativas na regra "Qualquer empresa": leads novos se alternam entre elas (veja o "Copy V…" no e-mail
      de cada negócio).

## A5 · Redator e envio

Use um lead fictício com **o seu e-mail** no contato.

- [ ] Mover o lead para **E-mail**: no dia útil seguinte às 7h30 (ou rodando a cadência), o toque D0 chega em
      **Tarefas → Para aprovar** como "Aprovar e-mail · …", com Para, Assunto e E-mail já preenchidos, sem `{{ }}`.
- [ ] Editar o texto e **Aprovar e enviar**: em até 2 minutos (dentro do horário de envio) o e-mail chega na sua caixa
      vindo de "Aprimora Consultoria <comercial@aprimoraej.com>"; no negócio, o cartão **E-mails** mostra "Enviado".
- [ ] Fora do horário (ex.: 19h), o aprovado fica "Na fila de envio" e sai na abertura do próximo dia útil.
- [ ] **Descartar**: o e-mail aparece como "Descartado" e o toque não volta.
- [ ] Lead sem e-mail nenhum: o toque vira a tarefa manual de antes.
- [ ] Registrar uma ligação com resultado **Pediu e-mail**: chega "Aprovar e-mail · Material pedido na ligação".
- [ ] D3 (ou o próximo toque de e-mail): sai **no mesmo fio** do D0 na sua caixa.

## A6 · Monitor de respostas

- [ ] Responder o e-mail com "Tenho interesse, podemos conversar?": em até ~7 minutos o responsável recebe
      "Resposta de …" no sino, o card vai sozinho para **Oportunidade** e a resposta aparece no negócio com o resumo.
- [ ] Responder outro lead com "Me procure em março": o card vai para **Retornar futuro** com a data.
- [ ] Responder com "Por favor, me remova da lista": o contato fica "não contatar" e chega em Tarefas
      "Encerrar lead? … pediu para não receber e-mails"; **Encerrar lead** leva a Lead não qualificado com o motivo.
- [ ] Resposta automática de férias: aparece como "Resposta automática" e a cadência continua.
- [ ] E-mails de fora da cadência na caixa da comercial@ não aparecem no portal.

## A7 · Organizador do dia e indicadores

- [ ] Às 7h30 de um dia útil cada membro com tarefas recebe "Seu dia" (tarefas, ligações, para aprovar, compromissos).
- [ ] **Painel comercial → Cadência de e-mail**: enviados, respondidos, taxa e a tabela por copy batem com o teste.
- [ ] **Config. do funil → Copy**: cada copy mostra enviados, respostas e taxa (últimos 90 dias).

## Depois do roteiro

- [ ] Excluir os leads fictícios de teste.
- [ ] Registrar aqui a data da validação e liberar a Fase 4.
