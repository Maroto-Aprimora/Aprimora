# Documento de Escopo

- `Escopo-Portal-Aprimora.pdf`: versão oficial de leitura.
- `Escopo-Portal-Aprimora.docx`: versão editável. Ao abrir, o Word pergunta se deve atualizar os campos; responda **Sim** para preencher o sumário.

## Como alterar o documento

O texto **não** é editado direto no DOCX ou no PDF. Ele vive em `fonte/conteudo.js`, escrito em blocos simples (títulos, parágrafos, listas e tabelas). Assim os dois formatos ficam sempre iguais e o histórico de mudanças fica legível no Git.

```bash
cd docs/escopo/fonte
npm install          # docx + playwright
npm run build        # diagramas → DOCX → PDF
```

| Arquivo | Função |
|---|---|
| `conteudo.js` | Todo o texto do documento |
| `marca.js` | Cores e fontes da identidade visual da Aprimora |
| `render-docx.js` | Gera o Word |
| `render-pdf.js` | Gera o PDF (HTML + Chromium); requer `pdfunite` (poppler-utils) e as fontes Montserrat e Open Sans instaladas |
| `diagramas/*.html` → `imagens/*.png` | Diagramas (gerados por `shot.js`) |

Ao mudar o escopo, atualize a versão (`VERSAO`) e a tabela "Controle do documento" em `conteudo.js`.
