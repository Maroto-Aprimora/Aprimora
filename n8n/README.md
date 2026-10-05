# n8n da Aprimora

Automações que rodam fora do portal: processamento das ligações (API4COM → Google Drive → Gemini) e
cadência de e-mails (Gmail). Roda numa **instância própria do n8n**, separada do n8n da agência, no mesmo VPS
por enquanto. Quando a Aprimora tiver um VPS próprio, a migração é copiar esta pasta e o volume de dados.

## Como as peças conversam

```
API4COM ──webhook──▶ PORTAL (guarda a ligação como "pendente" = fila)
                        ▲   │
     resultado/falha    │   │ reservar (até 3 por vez)
                        │   ▼
                     n8n da Aprimora ──▶ Google Drive (gravação na pasta do lead)
                                     └─▶ Gemini (transcrição + avaliação)

PORTAL (e-mails aprovados) ◀──reservar── n8n ──▶ Gmail (envio, 1 a cada 30 s)
Gmail (respostas) ──▶ n8n ──▶ PORTAL (é de um lead?) ──▶ Gemini (classifica) ──▶ PORTAL (atualiza o card)
```

Regras de desenho:
- **O portal é a fila.** Nada que chega da API4COM depende do n8n estar no ar: o portal guarda e o n8n busca
  quando puder. Se o n8n cair por um dia, as ligações esperam e são processadas depois.
- **O n8n nunca fala direto com o banco.** Só com a API do portal (`/api/n8n/*`), autenticada pelo cabeçalho
  `x-n8n-segredo`. Assim as regras de acesso continuam num lugar só.
- **Trocar de VPS = trocar um endereço** (`N8N_URL` na Vercel). A API4COM continua apontando para o portal.

## Os fluxos (`fluxos/`)

Padrão de nome: `APRIMORA | Área | Ação`. Coloque a etiqueta `aprimora` em todos.

| Arquivo | Fluxo | Quando roda | O que faz |
|---|---|---|---|
| `01-ligacoes-processar-fila.json` | Ligações · Processar fila | A cada 2 min | Reserva até 3 ligações, processa uma por vez com 20 s de pausa: cria a pasta do lead no Drive (se não existir), baixa a gravação, salva no Drive, pede ao Gemini transcrição e avaliação pelos critérios do diretor e devolve ao portal |
| `02-email-enviar-cadencia.json` | E-mail · Enviar cadência | Dias úteis, 8h–18h, a cada 10 min | Reserva até 10 e-mails **aprovados** e com envio vencido; envia um a cada 30 s pelo Gmail |
| `03-email-monitorar-respostas.json` | E-mail · Monitorar respostas | A cada 5 min | Para cada e-mail novo, pergunta ao portal se é resposta de lead; se for, o Gemini classifica e o portal atualiza o card |
| `04-sistema-monitor-fila.json` | Sistema · Monitor da fila | De hora em hora, 7h–21h | Avisa os diretores se a fila acumular (mais de 30, mais antiga com mais de 3 h) ou houver mais de 5 erros em 24 h |
| `05-sistema-tratamento-erros.json` | Sistema · Tratamento de erros | Quando outro fluxo quebra | Avisa o portal (auditoria + notificação aos diretores) |

### Modo de espera para muitas ligações ao mesmo tempo

Três camadas, da mais importante para a menos:
1. **Fila no portal**: 50 ligações seguidas viram 50 linhas "pendentes"; o n8n pega 3 a cada 2 minutos.
2. **Uma por vez com pausa**: dentro de cada lote, `Uma por vez` + `Pausa de 20 s` (≈ 3 avaliações por minuto,
   abaixo do limite do Gemini gratuito). Para acelerar ou frear, mude o `limite` em *Reservar ligações na fila*
   e a duração da pausa.
3. **Limite de execuções simultâneas** (`N8N_CONCURRENCY_PRODUCTION_LIMIT=2`): se dois lotes coincidirem,
   o terceiro espera a vez. O portal reserva com trava, então uma ligação nunca é processada duas vezes, e
   devolve à fila o que ficou "processando" por mais de 30 minutos.

Cada nó que fala com serviço externo tenta de novo sozinho (até 3 vezes; no Gemini com 30 s entre tentativas,
o que cobre o "limite por minuto excedido"). Se ainda assim falhar, o portal registra a tentativa e, depois de 3,
marca a ligação com erro no card.

Capacidade aproximada: 3 a cada 2 min ≈ 90 ligações por hora, bem acima do volume esperado.

### Limpeza automática

Configurada no `docker-compose.yml`, vale para todos os fluxos:
- execuções com mais de **7 dias** são apagadas, e o total é limitado a **5.000** (`EXECUTIONS_DATA_PRUNE*`);
- execuções **bem-sucedidas não são guardadas**, só as com erro (para investigar);
- o banco SQLite é compactado a cada reinício (`DB_SQLITE_VACUUM_ON_STARTUP`);
- áudios ficam em disco durante o processamento, não na memória (`N8N_DEFAULT_BINARY_DATA_MODE=filesystem`),
  e o n8n apaga esses arquivos junto com a execução;
- logs do container limitados a 3 arquivos de 10 MB.

Limites do container: **1 vCPU e 1,5 GB de RAM**. Se a Aprimora passar disso, só ela fica lenta; a agência não sente.
Ajuste em `deploy.resources.limits` conforme a folga do VPS.

## Instalar no VPS (uma vez)

1. **DNS**: crie o subdomínio (ex.: `n8n-aprimora.seudominio.com.br`) apontando para o IP do VPS.
2. **Pasta**: copie esta pasta `n8n/` para o VPS (ex.: `/opt/n8n-aprimora`) e crie o `.env` a partir do `.env.example`.
   - `N8N_ENCRYPTION_KEY`: `openssl rand -hex 32`. **Guarde em lugar seguro**: sem ela as credenciais salvas não abrem.
   - `PORTAL_N8N_SEGREDO`: `openssl rand -hex 32`, o mesmo valor que vai na Vercel como `N8N_SEGREDO`.
3. **Subir**: `docker compose -p n8n-aprimora --env-file .env up -d`.
4. **Proxy reverso**: publique `https://n8n-aprimora.seudominio` → `127.0.0.1:5679` no Nginx/Caddy/Traefik que já
   atende o n8n da agência (é só mais um site/rota, com HTTPS).
5. **Conta**: abra o subdomínio e crie o usuário dono com o e-mail institucional da Aprimora (não o da agência).
6. **Credenciais** (Settings → Credentials):
   - *Google Drive OAuth2* e *Gmail OAuth2*, conectadas na conta Google da Aprimora;
   - o Gemini e o portal usam as variáveis do `.env`, sem credencial no n8n.
7. **Importar** os 5 arquivos de `fluxos/` (Workflows → Import from file), escolher as credenciais do Google nos nós
   do Drive e do Gmail e definir **Sistema · Tratamento de erros** como *Error workflow* dos outros quatro.
8. **Ativar** os fluxos só depois que as rotas `/api/n8n/*` do portal estiverem publicadas.

## Contrato com o portal (rotas a implementar no portal)

Todas exigem o cabeçalho `x-n8n-segredo` e respondem JSON.

| Rota | Entrada | Resposta |
|---|---|---|
| `POST /api/n8n/ligacoes/reservar` | `{ limite }` | `{ ligacoes: [{ id, negocio_id, gravacao_url, nome_arquivo, nome_pasta, drive_pasta_id, empresa, membro, fase, objetivo, criterios: [texto] }] }` (marca como "processando") |
| `POST /api/n8n/negocios/:id/pasta-drive` | `{ pasta_id }` | `{ pasta_id }` |
| `POST /api/n8n/ligacoes/:id/resultado` | `{ drive_arquivo_id, drive_link, transcricao, resumo, nota, criterios[], pontos_fortes[], melhorias[], objecoes[], falou_com_decisor, interesse_cliente, proximo_passo, modelo, tokens }` | `{ ok }` |
| `POST /api/n8n/ligacoes/:id/falha` | `{ etapa, mensagem }` | `{ ok, tentativas }` |
| `POST /api/n8n/emails/reservar` | `{ limite }` | `{ emails: [{ id, para, assunto, corpo_html, remetente_nome, responder_para }] }` |
| `POST /api/n8n/emails/:id/enviado` | `{ gmail_id, thread_id }` | `{ ok }` |
| `POST /api/n8n/emails/:id/falha` | `{ mensagem }` | `{ ok }` |
| `POST /api/n8n/emails/resposta` | `{ message_id, thread_id, de, assunto, trecho, recebido_em }` | `{ lead: true, email_id, texto_resposta, ultimo_enviado }` ou `{ lead: false }` |
| `POST /api/n8n/emails/:id/classificacao` | `{ classificacao, resumo, proximo_passo, retorno_em? }` | `{ ok }` |
| `GET /api/n8n/saude` | — | `{ ligacoes_pendentes, mais_antiga_minutos, erros_24h, emails_pendentes }` |
| `POST /api/n8n/alerta` | `{ tipo, detalhes }` | `{ ok }` (notifica os diretores) |
| `POST /api/n8n/erro` | `{ fluxo, execucao_id, execucao_url, no, mensagem }` | `{ ok }` (auditoria + notificação) |

E a rota que a API4COM chama: `POST /api/integracoes/api4com?token=…` (formato do evento a confirmar na documentação
da API4COM). Ela grava a ligação e só a coloca na fila se foi **atendida, tem gravação e durou mais de 30 s**.

## Limites e cuidados conhecidos

- **Tamanho do áudio**: o envio direto ao Gemini aceita até ~18 MB (cerca de 15–20 min em MP3). Ligações maiores
  falham com mensagem clara; se forem comuns, trocamos para a *File API* do Gemini.
- **Plano gratuito do Gemini**: tem limite de pedidos por minuto e por dia, e o Google pode usar o conteúdo
  enviado para melhorar os produtos. Avise na ligação que ela é gravada e analisada (LGPD). Com o plano pago, os dados
  deixam de ser usados para treino.
- **Gmail**: contas Google Workspace enviam até ~2.000 e-mails por dia; o fluxo envia no máximo 1 a cada 30 s.
- **Atualizar o n8n**: `docker compose -p n8n-aprimora pull && docker compose -p n8n-aprimora up -d`
  (faça backup do volume antes).
