import { workflow, node, trigger, sticky, newCredential, expr } from '@n8n/workflow-sdk';

const H = { parameters: [{ name: 'x-n8n-segredo', value: '={{ $env.PORTAL_N8N_SEGREDO }}' }] };

const nota = sticky('## APRIMORA | Agente | A6 Monitor de respostas\n**Caixa da comercial@** (a cada 5 minutos): lista as mensagens recebidas nos últimos 2 dias (sem as enviadas por nós), lê cada uma e entrega ao portal. O portal só guarda as que respondem um fio de e-mail enviado pela cadência (cada mensagem entra uma vez só), pausa a cadência e avisa o responsável.\n\n**Classificar** (a cada 2 minutos): o Gemini gratuito classifica a resposta (interessado, retornar depois, recusa, descadastro, resposta automática, outro). Interessado e retornar depois movem o card sozinhos; recusa e descadastro pedem aprovação em Tarefas.', { width: 900, height: 250, color: 4 });

const aCada5 = trigger({ type: 'n8n-nodes-base.scheduleTrigger', version: 1.2, config: { name: 'A cada 5 minutos',
  parameters: { rule: { interval: [{ field: 'minutes', minutesInterval: 5 }] } } } });

const listar = node({ type: 'n8n-nodes-base.httpRequest', version: 4.2, config: { name: 'Gmail: mensagens recebidas', credentials: { gmailOAuth2: newCredential('Gmail comercial@') }, parameters: {
  method: 'GET', url: 'https://gmail.googleapis.com/gmail/v1/users/me/messages',
  authentication: 'predefinedCredentialType', nodeCredentialType: 'gmailOAuth2',
  sendQuery: true, queryParameters: { parameters: [{ name: 'q', value: 'in:inbox newer_than:2d -from:me' }, { name: 'maxResults', value: '50' }] },
  options: { timeout: 30000 } } } });

const ids = node({ type: 'n8n-nodes-base.code', version: 2, config: { name: 'Separar mensagens', parameters: {
  mode: 'runOnceForAllItems', jsCode: `// Uma linha por mensagem (nenhuma mensagem nova: o fluxo para aqui).
return (($input.first().json.messages) || []).map((m) => ({ json: { id: m.id } }));` } } });

const ler = node({ type: 'n8n-nodes-base.httpRequest', version: 4.2, config: { name: 'Gmail: ler mensagem', credentials: { gmailOAuth2: newCredential('Gmail comercial@') }, parameters: {
  method: 'GET', url: '=https://gmail.googleapis.com/gmail/v1/users/me/messages/{{ $json.id }}?format=full',
  authentication: 'predefinedCredentialType', nodeCredentialType: 'gmailOAuth2', options: { timeout: 30000 } } } });

const montarLote = node({ type: 'n8n-nodes-base.code', version: 2, config: { name: 'Montar lote', parameters: {
  mode: 'runOnceForAllItems', jsCode: `// Extrai remetente, assunto, data e o texto (sem a parte citada) de cada mensagem.
const dec = (d) => Buffer.from(String(d || '').replace(/-/g, '+').replace(/_/g, '/'), 'base64').toString('utf8');
function texto(parte) {
  if (!parte) return '';
  if (parte.mimeType === 'text/plain' && parte.body && parte.body.data) return dec(parte.body.data);
  for (const p of parte.parts || []) { const t = texto(p); if (t) return t; }
  if (parte.mimeType === 'text/html' && parte.body && parte.body.data) return dec(parte.body.data).replace(/<[^>]+>/g, ' ');
  return '';
}
function semCitacao(t) {
  const linhas = [];
  for (const l of t.split(/\\r?\\n/)) {
    if (/^(Em .+escreveu:|On .+wrote:|-----Original Message-----|De: .+)/.test(l.trim())) break;
    if (!l.trim().startsWith('>')) linhas.push(l);
  }
  return linhas.join('\\n').replace(/\\n{3,}/g, '\\n\\n').trim();
}
const mensagens = $input.all().map((i) => {
  const m = i.json;
  const cab = {};
  for (const h of ((m.payload || {}).headers || [])) cab[h.name.toLowerCase()] = h.value;
  const corpo = semCitacao(texto(m.payload)) || m.snippet || '';
  return { gmail_id: m.id, thread_id: m.threadId, de: cab['from'] || '', assunto: cab['subject'] || '',
    trecho: corpo.slice(0, 4000), recebido_em: m.internalDate ? new Date(Number(m.internalDate)).toISOString() : undefined };
}).filter((m) => m.gmail_id && m.thread_id);
return [{ json: { mensagens } }];` } } });

const entregar = node({ type: 'n8n-nodes-base.httpRequest', version: 4.2, config: { name: 'Entregar ao portal', parameters: {
  method: 'POST', url: '={{ $env.PORTAL_URL }}/api/n8n/emails/respostas', sendHeaders: true, headerParameters: H,
  sendBody: true, specifyBody: 'json', jsonBody: '={{ JSON.stringify({ mensagens: $json.mensagens }) }}', options: { timeout: 30000 } } } });

const aCada2 = trigger({ type: 'n8n-nodes-base.scheduleTrigger', version: 1.2, config: { name: 'A cada 2 minutos',
  parameters: { rule: { interval: [{ field: 'minutes', minutesInterval: 2 }] } } } });

const reservar = node({ type: 'n8n-nodes-base.httpRequest', version: 4.2, config: { name: 'Reservar classificações', parameters: {
  method: 'POST', url: '={{ $env.PORTAL_URL }}/api/n8n/trabalhos/reservar', sendHeaders: true, headerParameters: H,
  sendBody: true, specifyBody: 'json', jsonBody: "={{ JSON.stringify({ agente: 'monitor_respostas', limite: 5 }) }}", options: { timeout: 30000 } } } });

const separar = node({ type: 'n8n-nodes-base.splitOut', version: 1, config: { name: 'Separar trabalhos',
  parameters: { fieldToSplitOut: 'trabalhos', options: {} } } });

const pedido = node({ type: 'n8n-nodes-base.code', version: 2, config: { name: 'Montar pedido ao Gemini', onError: 'continueErrorOutput', parameters: {
  mode: 'runOnceForEachItem', jsCode: `const p = $json.payload || {};
const prompt = [
  'Você classifica respostas de leads a e-mails comerciais da Aprimora (consultoria de Engenharia de Produção).',
  'Hoje é ' + p.hoje + '. Classifique a RESPOSTA em uma das opções:',
  '- interessado: quer conversar, pediu proposta, reunião, mais informações ou fez pergunta de quem tem interesse;',
  '- retornar_depois: tem interesse mas pede contato em outro momento (informe retorno_em AAAA-MM-DD; sem data clara, deixe vazio);',
  '- recusa: não tem interesse, já tem fornecedor, não é o momento sem previsão;',
  '- descadastro: pede para não receber mais e-mails / remover da lista;',
  '- ausencia: resposta automática (férias, fora do escritório, não monitorado);',
  '- outro: nada disso (ex.: encaminhou para outra pessoa, dúvida sem sinal claro).',
  'resumo: uma frase em português do Brasil dizendo o que o lead respondeu e o próximo passo sugerido.',
  '',
  'E-MAIL QUE ENVIAMOS · ' + ((p.email_enviado || {}).assunto || '') + '\\n' + ((p.email_enviado || {}).corpo || ''),
  '',
  'RESPOSTA de ' + (p.de || '') + ' (' + (p.empresa || '') + ') · ' + (p.assunto || '') + '\\n' + (p.trecho || ''),
].join('\\n');
return { json: { corpo: {
  contents: [{ role: 'user', parts: [{ text: prompt }] }],
  generationConfig: { temperature: 0.1, responseMimeType: 'application/json', responseSchema: { type: 'OBJECT', properties: {
    classificacao: { type: 'STRING', enum: ['interessado', 'retornar_depois', 'recusa', 'descadastro', 'ausencia', 'outro'] },
    resumo: { type: 'STRING' }, retorno_em: { type: 'STRING' } }, required: ['classificacao', 'resumo', 'retorno_em'] } },
} } };` } } });

const gemini = node({ type: 'n8n-nodes-base.httpRequest', version: 4.2, config: { name: 'Gemini: classificar', onError: 'continueErrorOutput', parameters: {
  method: 'POST', url: 'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent', sendHeaders: true,
  headerParameters: { parameters: [{ name: 'x-goog-api-key', value: '={{ $env.GEMINI_API_KEY }}' }] },
  sendBody: true, specifyBody: 'json', jsonBody: '={{ JSON.stringify($json.corpo) }}', options: { timeout: 60000 } } } });

const lerClasse = node({ type: 'n8n-nodes-base.code', version: 2, config: { name: 'Ler classificação', onError: 'continueErrorOutput', parameters: {
  mode: 'runOnceForEachItem', jsCode: `const t = $('Separar trabalhos').item.json;
const c = ($json.candidates || [])[0] || {};
const texto = ((c.content || {}).parts || []).map((p) => p.text || '').join('').trim();
if (!texto) throw new Error('Gemini respondeu sem texto (' + (c.finishReason || 'sem motivo') + ')');
let r;
try { r = JSON.parse(texto); } catch (err) { throw new Error('JSON inválido do Gemini: ' + err.message); }
const retorno = /^\\d{4}-\\d{2}-\\d{2}$/.test(String(r.retorno_em || '').trim()) ? String(r.retorno_em).trim() : '';
return { json: { trabalho_id: t.id, resultado: { classificacao: r.classificacao || 'outro', resumo: String(r.resumo || '').trim(), retorno_em: retorno } } };` } } });

const devolver = node({ type: 'n8n-nodes-base.httpRequest', version: 4.2, config: { name: 'Devolver resultado ao portal', parameters: {
  method: 'POST', url: '={{ $env.PORTAL_URL }}/api/n8n/trabalhos/{{ $json.trabalho_id }}/resultado', sendHeaders: true, headerParameters: H,
  sendBody: true, specifyBody: 'json', jsonBody: '={{ JSON.stringify({ resultado: $json.resultado }) }}', options: { timeout: 30000 } } } });

const falha = node({ type: 'n8n-nodes-base.httpRequest', version: 4.2, config: { name: 'Registrar falha no portal', parameters: {
  method: 'POST', url: "={{ $env.PORTAL_URL }}/api/n8n/trabalhos/{{ $('Separar trabalhos').item.json.id }}/falha", sendHeaders: true, headerParameters: H,
  sendBody: true, specifyBody: 'json',
  jsonBody: "={{ JSON.stringify({ etapa: 'classificar', mensagem: String(($json.error && ($json.error.message || JSON.stringify($json.error))) || 'erro sem mensagem').slice(0, 1500) }) }}",
  options: { timeout: 30000 } } } });

export default workflow('a6-monitor', 'APRIMORA | Agente | A6 Monitor de respostas')
  .add(nota)
  .add(aCada5).to(listar).to(ids).to(ler).to(montarLote).to(entregar)
  .add(aCada2).to(reservar).to(separar).to(pedido.onError(falha).to(gemini.onError(falha).to(lerClasse.onError(falha).to(devolver))));
