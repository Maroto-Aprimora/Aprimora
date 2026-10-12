# n8n da Aprimora

Automações que rodam fora do portal: processamento das ligações (API4COM → Google Drive → Gemini) e
cadência de e-mails (Gmail). Roda numa **VPS própria da Aprimora** (Hostinger), em https://srv2043014.hstgr.cloud.

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
- **Trocar de VPS não mexe no portal nem na API4COM**: é o n8n que busca trabalho no portal, então basta subir a mesma pasta no VPS novo com o mesmo `.env`.

## Os fluxos (`fluxos/`)

Padrão de nome: `APRIMORA | Área | Ação`. Coloque a etiqueta `aprimora` em todos.

| Arquivo | Fluxo | Quando roda | O que faz |
|---|---|---|---|
| `00-sistema-teste-fila.json` | Sistema · Teste da fila | A cada 2 min | Reserva os trabalhos do agente "Teste da fila" e devolve cada um como concluído (portão da Fase 1) |
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

## Instalação atual (12/10/2026)

- **VPS:** Hostinger KVM 2 (2 vCPU, 8 GB, Ubuntu 24.04), `srv2043014.hstgr.cloud` / `179.236.67.145`, só da Aprimora.
- **Endereço do n8n:** https://srv2043014.hstgr.cloud (endereço gratuito da Hostinger; o portal continua em
  `aprimora.vercel.app`). Para usar um domínio próprio no futuro, troque `N8N_DOMINIO` e suba de novo.
- **Projeto Docker:** `n8n-aprimora`, criado pelo Docker Manager da Hostinger com este `docker-compose.yml`:
  `caddy-aprimora` (HTTPS automático com Let's Encrypt, portas 80/443) e `n8n-aprimora` (sem porta exposta).
- **Variáveis** (`N8N_ENCRYPTION_KEY`, `PORTAL_N8N_SEGREDO`, `GEMINI_API_KEY`…): ficam só no projeto da Hostinger
  (hPanel → VPS → Docker Manager → n8n-aprimora → Environment). Nunca no GitHub. A `N8N_ENCRYPTION_KEY` também é
  copiada pelo n8n para o volume `n8n_aprimora_dados`; perdê-la significa perder as credenciais salvas.

## Instalar em outra VPS

1. **Endereço**: use o nome da VPS (ex.: `srvNNNN.hstgr.cloud`) ou crie um registro `A` de um domínio para o IP.
2. **Variáveis**: a partir do `.env.example`. `N8N_ENCRYPTION_KEY` e `PORTAL_N8N_SEGREDO` com `openssl rand -hex 32`;
   `PORTAL_N8N_SEGREDO` igual à `N8N_SEGREDO` da Vercel.
3. **Subir**: `docker compose -p n8n-aprimora --env-file .env up -d` (ou Docker Manager da Hostinger, colando o
   `docker-compose.yml` e as variáveis). O Caddy emite o certificado sozinho em menos de um minuto.
4. **Conta**: abra o endereço e crie **na hora** o usuário dono com o e-mail da Aprimora (até isso, qualquer pessoa
   que abrir o endereço pode se cadastrar como dona).
5. **Credenciais** (Settings → Credentials): *Google Drive OAuth2* e *Gmail OAuth2* na conta Google da Aprimora,
   com a URL de retorno `https://<endereço>/rest/oauth2-credential/callback`; o Gemini e o portal usam as variáveis.
6. **Importar** os fluxos de `fluxos/` e definir **Sistema · Tratamento de erros** como *Error workflow* dos outros.
7. **Ativar** os fluxos só depois que as rotas `/api/n8n/*` do portal estiverem publicadas.

## Contrato com o portal

Todas as rotas exigem o cabeçalho `x-n8n-segredo` (= `N8N_SEGREDO` na Vercel) e respondem JSON. Por trás, cada rota
chama uma função `n8n_*` do banco, que confere o segredo de novo (hash em `privado.config`).

**Fila genérica (Fase 1, publicada)**

| Rota | Entrada | Resposta |
|---|---|---|
| `POST /api/n8n/trabalhos/reservar` | `{ agente?, limite? }` (até 20) | `{ trabalhos: [{ id, agente, tipo, negocio_id, payload, tentativa }] }` — marca como "processando"; só agentes ligados; o que ficar processando por mais de 30 min volta à fila |
| `POST /api/n8n/trabalhos/:id/resultado` | `{ resultado: { …, aprovacao?: { tipo, titulo, resumo?, conteudo: {campo: texto}, responsavel_id? } } }` | `{ ok }` — com `aprovacao`, o item vai para a Caixa de aprovação do responsável do negócio |
| `POST /api/n8n/trabalhos/:id/falha` | `{ etapa?, mensagem? }` | `{ ok, tentativas, max_tentativas, status }` — volta à fila em 5/10 min; na 3ª falha fica com erro e avisa os diretores |
| `GET /api/n8n/saude` | — | `{ pendentes, processando, mais_antiga_minutos, erros_24h, concluidos_24h, ultimo_concluido_em, aprovacoes_pendentes }` |
| `POST /api/n8n/alerta` | `{ tipo, detalhes }` | `{ ok }` (auditoria + notificação aos diretores) |
| `POST /api/n8n/erro` | `{ fluxo, execucao_id, execucao_url, no, mensagem }` | `{ ok }` (auditoria + notificação) |

**Rotas específicas previstas** (fluxos 01 a 03, entram nas Fases 2 e 3 sobre a mesma fila):
`/api/n8n/ligacoes/*`, `/api/n8n/negocios/:id/pasta-drive`, `/api/n8n/emails/*` e a rota da API4COM
`POST /api/integracoes/api4com?token=…`. Até lá, **não ative os fluxos 01, 02 e 03**.

## Limites e cuidados conhecidos

- **Tamanho do áudio**: o envio direto ao Gemini aceita até ~18 MB (cerca de 15–20 min em MP3). Ligações maiores
  falham com mensagem clara; se forem comuns, trocamos para a *File API* do Gemini.
- **Plano gratuito do Gemini**: tem limite de pedidos por minuto e por dia, e o Google pode usar o conteúdo
  enviado para melhorar os produtos. Avise na ligação que ela é gravada e analisada (LGPD). Com o plano pago, os dados
  deixam de ser usados para treino.
- **Gmail**: contas Google Workspace enviam até ~2.000 e-mails por dia; o fluxo envia no máximo 1 a cada 30 s.
- **Atualizar o n8n**: `docker compose -p n8n-aprimora pull && docker compose -p n8n-aprimora up -d`
  (faça backup do volume antes).
