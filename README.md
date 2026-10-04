# Portal Aprimora

Aplicativo web (PWA) da **Aprimora — Empresa Júnior de Engenharia de Produção da UTFPR Londrina**.

O portal começa pelo **módulo Comercial** e centraliza leads, funil de vendas, visitas, diagnósticos, agenda, tarefas, metas e indicadores. Também automatiza e-mails, lembretes e relatórios com N8N e IA. Depois o portal será expandido para as demais diretorias (Projetos, Presidência, RH e Marketing).

> Este código é patrimônio da Aprimora. Antes de contribuir, leia o documento de escopo.

## Documentação

| Documento | Descrição |
|---|---|
| [`docs/escopo/Escopo-Portal-Aprimora.pdf`](docs/escopo/Escopo-Portal-Aprimora.pdf) | Documento de escopo: versão de leitura (referência oficial) |
| [`docs/escopo/Escopo-Portal-Aprimora.docx`](docs/escopo/Escopo-Portal-Aprimora.docx) | Mesmo documento em Word, para comentários e revisão |
| [`docs/escopo/fonte/`](docs/escopo/fonte) | Fonte do documento (conteúdo + geradores). Edite aqui e gere de novo |

## Situação

- [x] Levantamento e documento de escopo v1.0
- [x] Fase 0: fundação (stack, login por pré-cadastro, diretorias e cargos, segurança no banco)
- [ ] Fases 1 a 7: veja a Seção 14 do escopo

## Stack prevista

Next.js + TypeScript + Tailwind/shadcn · Supabase (Postgres, Auth, RLS, Storage) · N8N · PWA. Os detalhes e as justificativas estão na Seção 11 do escopo.

## Começando

- Desenvolvimento: [`docs/DESENVOLVIMENTO.md`](docs/DESENVOLVIMENTO.md)
- Configurar e-mail e login (uma vez, pelo diretor): [`docs/CONFIGURAR-EMAIL-E-LOGIN.md`](docs/CONFIGURAR-EMAIL-E-LOGIN.md)
