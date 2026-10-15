// Fluxo criado no n8n pelo conector (id Qi0qL10XvG89MQHf). Código do Workflow SDK usado na criação.
import { workflow, node, trigger, sticky } from '@n8n/workflow-sdk';

const H = { parameters: [{ name: 'x-n8n-segredo', value: '={{ $env.PORTAL_N8N_SEGREDO }}' }] };

const nota = sticky('## APRIMORA | Agente | A9 Assistente de proposta\nA cada 2 minutos reserva 1 diagnóstico concluído no portal. O Gemini gratuito lê o mapa de maturidade, as respostas e comentários, as dores e as ligações e devolve: resumo do diagnóstico, serviços sugeridos (só da Carta de Serviços), rascunho de escopo e rascunho de proposta. O responsável revisa em Negócio → Proposta.', { width: 900, height: 200, color: 4 });

const cron = trigger({ type: 'n8n-nodes-base.scheduleTrigger', version: 1.2, config: { name: 'A cada 2 minutos',
  parameters: { rule: { interval: [{ field: 'minutes', minutesInterval: 2 }] } } } });

const reservar = node({ type: 'n8n-nodes-base.httpRequest', version: 4.2, config: { name: 'Reservar trabalhos', parameters: {
  method: 'POST', url: '={{ $env.PORTAL_URL }}/api/n8n/trabalhos/reservar', sendHeaders: true, headerParameters: H,
  sendBody: true, specifyBody: 'json', jsonBody: "={{ JSON.stringify({ agente: 'assistente_proposta', limite: 1 }) }}", options: { timeout: 30000 } } } });

const separar = node({ type: 'n8n-nodes-base.splitOut', version: 1, config: { name: 'Separar trabalhos',
  parameters: { fieldToSplitOut: 'trabalhos', options: {} } } });

const pedido = node({ type: 'n8n-nodes-base.code', version: 2, config: { name: 'Montar pedido ao Gemini', onError: 'continueErrorOutput', parameters: {
  mode: 'runOnceForEachItem', jsCode: `// Monta o pedido ao Gemini com o diagnóstico completo.
const p = $json.payload || {};
const servicos = p.servicos || [];
const prompt = [
  'Você é consultor sênior da Aprimora, empresa júnior de Engenharia de Produção da UEL (Londrina-PR), que atende pequenas e médias indústrias.',
  'A partir do DIAGNÓSTICO abaixo (notas de 1 = não existe a 4 = estruturado, por área), escreva em português do Brasil:',
  '1. resumo: o diagnóstico em 1 a 2 parágrafos, citando as áreas mais frágeis e as mais maduras, com base nas notas e comentários.',
  '2. servicos_sugeridos: de 1 a 3 serviços da Carta de Serviços (use exatamente o id e o nome da lista) que mais resolvem as áreas de menor nota e as dores; para cada um, um motivo curto ligado ao diagnóstico.',
  '3. escopo: rascunho do escopo do projeto em etapas numeradas (objetivo, atividades e entregáveis de cada etapa), coerente com os serviços sugeridos. Não invente prazos em dias nem valores.',
  '4. proposta: rascunho do texto da proposta comercial para o cliente (contexto do cliente, problema, solução da Aprimora, etapas resumidas, benefícios esperados, próximos passos). Tom profissional e próximo, sem prometer números que não estão no diagnóstico, sem preço.',
  'Não use markdown (sem #, ** ou tabelas); use parágrafos e listas com hífen.',
  '',
  'CARTA DE SERVIÇOS (id e nome): ' + JSON.stringify(servicos),
  '',
  'EMPRESA: ' + JSON.stringify(p.empresa || {}),
  'DORES MARCADAS: ' + JSON.stringify(p.dores_marcadas || []),
  'ANOTAÇÕES DE DORES: ' + (p.dores || ''),
  'MAPA DE MATURIDADE: ' + JSON.stringify((p.maturidade || []).filter((m) => m.respondidas > 0).map((m) => ({ area: m.nome, media: m.media }))),
  'RESPOSTAS: ' + JSON.stringify(p.respostas || []),
  'OBSERVAÇÕES DA VISITA: ' + (p.observacoes || ''),
  'RESUMOS DAS LIGAÇÕES: ' + JSON.stringify(p.ligacoes || []),
].join('\\n');
return { json: { corpo: {
  contents: [{ role: 'user', parts: [{ text: prompt }] }],
  generationConfig: { temperature: 0.4, responseMimeType: 'application/json', responseSchema: { type: 'OBJECT', properties: {
    resumo: { type: 'STRING' },
    servicos_sugeridos: { type: 'ARRAY', items: { type: 'OBJECT', properties: {
      servico_id: { type: 'STRING', enum: servicos.map((s) => s.id) }, nome: { type: 'STRING' }, motivo: { type: 'STRING' } },
      required: ['servico_id', 'nome', 'motivo'] } },
    escopo: { type: 'STRING' }, proposta: { type: 'STRING' } }, required: ['resumo', 'servicos_sugeridos', 'escopo', 'proposta'] } },
} } };` } } });

const gemini = node({ type: 'n8n-nodes-base.httpRequest', version: 4.2, config: { name: 'Gemini: analisar diagnóstico', onError: 'continueErrorOutput', retryOnFail: true, maxTries: 3, waitBetweenTries: 5000, parameters: {
  method: 'POST', url: 'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent', sendHeaders: true,
  headerParameters: { parameters: [{ name: 'x-goog-api-key', value: '={{ $env.GEMINI_API_KEY }}' }] },
  sendBody: true, specifyBody: 'json', jsonBody: '={{ JSON.stringify($json.corpo) }}', options: { timeout: 180000 } } } });

const ler = node({ type: 'n8n-nodes-base.code', version: 2, config: { name: 'Ler resposta', onError: 'continueErrorOutput', parameters: {
  mode: 'runOnceForEachItem', jsCode: `const t = $('Separar trabalhos').item.json;
const c = ($json.candidates || [])[0] || {};
const texto = ((c.content || {}).parts || []).map((p) => p.text || '').join('').trim();
if (!texto) throw new Error('Gemini respondeu sem texto (' + (c.finishReason || 'sem motivo') + ')');
let r;
try { r = JSON.parse(texto); } catch (err) { throw new Error('JSON inválido do Gemini: ' + err.message); }
const ok = (v) => (typeof v === 'string' ? v.trim() : '');
return { json: { trabalho_id: t.id, resultado: {
  resumo: ok(r.resumo), escopo: ok(r.escopo), proposta: ok(r.proposta),
  servicos_sugeridos: Array.isArray(r.servicos_sugeridos) ? r.servicos_sugeridos.slice(0, 3) : [],
} } };` } } });

const devolver = node({ type: 'n8n-nodes-base.httpRequest', version: 4.2, config: { name: 'Devolver resultado ao portal', parameters: {
  method: 'POST', url: '={{ $env.PORTAL_URL }}/api/n8n/trabalhos/{{ $json.trabalho_id }}/resultado', sendHeaders: true, headerParameters: H,
  sendBody: true, specifyBody: 'json', jsonBody: '={{ JSON.stringify({ resultado: $json.resultado }) }}', options: { timeout: 30000 } } } });

const falha = node({ type: 'n8n-nodes-base.httpRequest', version: 4.2, config: { name: 'Registrar falha no portal', parameters: {
  method: 'POST', url: "={{ $env.PORTAL_URL }}/api/n8n/trabalhos/{{ $('Separar trabalhos').item.json.id }}/falha", sendHeaders: true, headerParameters: H,
  sendBody: true, specifyBody: 'json',
  jsonBody: "={{ JSON.stringify({ etapa: 'assistente', mensagem: String(($json.error && ($json.error.message || JSON.stringify($json.error))) || 'erro sem mensagem').slice(0, 1500) }) }}",
  options: { timeout: 30000 } } } });

export default workflow('a9-assistente-proposta', 'APRIMORA | Agente | A9 Assistente de proposta')
  .add(nota)
  .add(cron).to(reservar).to(separar).to(pedido.onError(falha).to(gemini.onError(falha).to(ler.onError(falha).to(devolver))));
