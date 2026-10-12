# Portal Aprimora

Aplicativo web (PWA) da **Aprimora — Empresa Júnior de Engenharia de Produção da UTFPR Londrina**.

Na v2 o portal é o **sistema de trabalho exclusivo da Diretoria Comercial**: leads, funil de vendas, ligações, cadência, diagnósticos, agenda, tarefas, metas e indicadores, com agentes de IA (n8n + Gemini) que preparam o trabalho operacional para o time aprovar.

> Este código é patrimônio da Aprimora. Antes de contribuir, leia o documento de escopo.

## Documentação

| Documento | Descrição |
|---|---|
| [`docs/escopo/Planejamento-Estrategico-Comercial-v2.md`](docs/escopo/Planejamento-Estrategico-Comercial-v2.md) | **PE-PA-002**: planejamento da v2 (Comercial), agentes e roadmap. Referência atual |
| [`docs/tecnico/Documentacao-Tecnica-Portal-Aprimora.md`](docs/tecnico/Documentacao-Tecnica-Portal-Aprimora.md) | **DT-PA-001**: como o sistema está construído hoje |
| [`docs/escopo/Escopo-Portal-Aprimora.pdf`](docs/escopo/Escopo-Portal-Aprimora.pdf) | Documento de escopo: versão de leitura (referência oficial) |
| [`docs/escopo/Escopo-Portal-Aprimora.docx`](docs/escopo/Escopo-Portal-Aprimora.docx) | Mesmo documento em Word, para comentários e revisão |
| [`docs/escopo/fonte/`](docs/escopo/fonte) | Fonte do documento (conteúdo + geradores). Edite aqui e gere de novo |

## Situação

- [x] Levantamento e documento de escopo v1.0
- [x] Fase 0: fundação (stack, login por pré-cadastro, diretorias e cargos, segurança no banco)
- [x] Fase 1: CRM e funil (empresas, contatos, funil do Pipefy com SLA, rodízio, histórico, configurações, metas de 2026)
- [x] Fase 2: atividades e rotina (agenda com R.I/R.G, tarefas, notificações com push, transferência de carteira, auditoria)
- [x] Fase 2b: menu por diretoria, painel geral, pontuação (Vice-Presidência) e configuração de metas
- [x] Fase 3: indicadores do funil no painel comercial, metas automáticas, exportação (xlsx/csv) e anexos
- [x] v2 (PE-PA-002): Fase 0 — fundação do processo (código pronto; portão em `docs/testes/Roteiro-Portao-Fase-0.md`)
- [ ] v2: Fases 1 a 6 — veja a Seção 9 do PE-PA-002

## Stack prevista

Next.js + TypeScript + Tailwind/shadcn · Supabase (Postgres, Auth, RLS, Storage) · N8N · PWA. Os detalhes e as justificativas estão na Seção 11 do escopo.

## Começando

- Desenvolvimento: [`docs/DESENVOLVIMENTO.md`](docs/DESENVOLVIMENTO.md)
- Configurar e-mail e login (uma vez, pelo diretor): [`docs/CONFIGURAR-EMAIL-E-LOGIN.md`](docs/CONFIGURAR-EMAIL-E-LOGIN.md)
