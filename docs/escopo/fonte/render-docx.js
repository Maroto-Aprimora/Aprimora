// Gera o Documento de Escopo em Word (.docx) a partir de conteudo.js.
// Uso: node render-docx.js   (requer o pacote npm "docx" v9)
const fs = require("fs");
const path = require("path");
const {
  Document, Packer, Paragraph, TextRun, ImageRun, Table, TableRow, TableCell,
  WidthType, ShadingType, BorderStyle, AlignmentType, HeadingLevel, LevelFormat,
  Header, Footer, PageNumber, PageBreak, TabStopType, VerticalAlign, TableOfContents,
} = require("docx");
const { VERSAO, DATA, blocos } = require("./conteudo");
const marca = require("./marca");

const DIR = __dirname;
const img = (f) => fs.readFileSync(path.join(DIR, "imagens", f));
const { NAVY, NAVY_DARK, ORANGE, LIGHT_BLUE, BG_SOFT, BG_ORANGE, GRAY, HFONT, BFONT } = marca.docx;
const PAGE_W = 11906, MARGIN = 1134, CONTENT_W = PAGE_W - 2 * MARGIN; // A4, margens de 2 cm

// Suporta **negrito** e `código` dentro das strings.
function runs(text, base = {}) {
  const out = [];
  const re = /(\*\*[^*]+\*\*|`[^`]+`)/g;
  let last = 0, m;
  while ((m = re.exec(text))) {
    if (m.index > last) out.push(new TextRun({ text: text.slice(last, m.index), ...base }));
    const t = m[0];
    if (t.startsWith("**")) out.push(new TextRun({ text: t.slice(2, -2), bold: true, ...base }));
    else out.push(new TextRun({ text: t.slice(1, -1), font: "Consolas", size: 18, color: NAVY_DARK, ...base }));
    last = m.index + t.length;
  }
  if (last < text.length) out.push(new TextRun({ text: text.slice(last), ...base }));
  return out;
}

const P = (text, opts = {}) => new Paragraph({
  children: runs(text, opts.run || {}),
  spacing: { after: 120, line: 300 },
  alignment: opts.align || AlignmentType.JUSTIFIED,
  ...(opts.p || {}),
});

function H1(text) {
  return new Paragraph({ heading: HeadingLevel.HEADING_1, children: [new TextRun(text)], pageBreakBefore: true });
}
function H2(text) {
  return new Paragraph({ heading: HeadingLevel.HEADING_2, children: [new TextRun(text)] });
}
const H3 = (text) => new Paragraph({ heading: HeadingLevel.HEADING_3, children: [new TextRun(text)] });

const bullets = (items, level = 0) => items.flatMap((it) => {
  if (Array.isArray(it)) return bullets(it, level + 1);
  return [new Paragraph({ numbering: { reference: "bullets", level }, children: runs(it), spacing: { after: 60, line: 288 } })];
});
let numInst = 0;
const numbered = (items) => {
  const inst = ++numInst;
  return items.map((it) => new Paragraph({ numbering: { reference: "numbers", level: 0, instance: inst }, children: runs(it), spacing: { after: 60, line: 288 } }));
};

const cellBorder = { style: BorderStyle.SINGLE, size: 4, color: "D5DCE4" };
const borders = { top: cellBorder, bottom: cellBorder, left: cellBorder, right: cellBorder };

function table(headers, rows, widths, opts = {}) {
  const total = widths.reduce((a, b) => a + b, 0);
  const scale = CONTENT_W / total;
  const w = widths.map((x) => Math.round(x * scale));
  w[w.length - 1] = CONTENT_W - w.slice(0, -1).reduce((a, b) => a + b, 0);
  const fs = opts.size || 17;
  const mk = (txt, i, header, zebra) => new TableCell({
    width: { size: w[i], type: WidthType.DXA },
    borders,
    shading: { type: ShadingType.CLEAR, fill: header ? NAVY : zebra ? BG_SOFT : "FFFFFF", color: "auto" },
    margins: { top: 70, bottom: 70, left: 100, right: 100 },
    verticalAlign: VerticalAlign.CENTER,
    children: String(txt).split("\n").map((line) => new Paragraph({
      spacing: { after: 20, line: 264 },
      children: header
        ? [new TextRun({ text: line, bold: true, color: "FFFFFF", font: HFONT, size: fs })]
        : runs(line, { size: fs, ...(i === 0 && opts.boldFirst ? { bold: true, color: NAVY_DARK } : {}) }),
    })),
  });
  return [new Table({
    width: { size: CONTENT_W, type: WidthType.DXA },
    columnWidths: w,
    rows: [
      new TableRow({ tableHeader: true, children: headers.map((h, i) => mk(h, i, true)) }),
      ...rows.map((r, ri) => new TableRow({ cantSplit: true, children: r.map((c, i) => mk(c, i, false, ri % 2 === 1)) })),
    ],
  }), new Paragraph({ spacing: { after: 120 }, children: [] })];
}

// Caixa de destaque (nota, decisão, atenção)
function callout(title, lines, kind = "info") {
  const fill = kind === "warn" ? BG_ORANGE : BG_SOFT;
  const bar = kind === "warn" ? ORANGE : NAVY;
  const none = { style: BorderStyle.NONE, size: 0, color: "FFFFFF" };
  return [new Table({
    width: { size: CONTENT_W, type: WidthType.DXA },
    columnWidths: [CONTENT_W],
    rows: [new TableRow({ children: [new TableCell({
      width: { size: CONTENT_W, type: WidthType.DXA },
      borders: { top: none, bottom: none, right: none, left: { style: BorderStyle.SINGLE, size: 36, color: bar } },
      shading: { type: ShadingType.CLEAR, fill, color: "auto" },
      margins: { top: 120, bottom: 120, left: 220, right: 180 },
      children: [
        new Paragraph({ spacing: { after: 60 }, children: [new TextRun({ text: title, bold: true, font: HFONT, color: bar === ORANGE ? "B35A17" : NAVY, size: 20 })] }),
        ...[].concat(lines).map((l) => new Paragraph({ spacing: { after: 40, line: 288 }, children: runs(l, { size: 19 }) })),
      ],
    })] })],
  }), new Paragraph({ spacing: { after: 120 }, children: [] })];
}

function figure(file, wpx, hpx, caption) {
  const maxW = 640;
  const h = Math.round((hpx * maxW) / wpx);
  return [
    new Paragraph({ alignment: AlignmentType.CENTER, spacing: { before: 120, after: 60 },
      children: [new ImageRun({ type: "png", data: img(file), transformation: { width: maxW, height: h },
        altText: { title: caption, description: caption, name: file } })] }),
    new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 200 },
      children: [new TextRun({ text: caption, italics: true, size: 17, color: GRAY })] }),
  ];
}

const spacer = (after = 120) => new Paragraph({ spacing: { after }, children: [] });
// ---------- CAPA ----------
const none = { style: BorderStyle.NONE, size: 0, color: "FFFFFF" };
const capa = [
  new Table({
    width: { size: CONTENT_W, type: WidthType.DXA },
    columnWidths: [CONTENT_W],
    rows: [new TableRow({ height: { value: 7600, rule: "atLeast" }, children: [new TableCell({
      width: { size: CONTENT_W, type: WidthType.DXA },
      borders: { top: none, bottom: none, left: none, right: none },
      shading: { type: ShadingType.CLEAR, fill: NAVY, color: "auto" },
      verticalAlign: VerticalAlign.CENTER,
      children: [
        new Paragraph({ alignment: AlignmentType.CENTER, spacing: { before: 300 },
          children: [new ImageRun({ type: "jpg", data: img("logo-quadrada.jpg"), transformation: { width: 300, height: 300 },
            altText: { title: "Logo Aprimora", description: "Logo oficial da Aprimora", name: "logo" } })] }),
        new Paragraph({ alignment: AlignmentType.CENTER, spacing: { before: 120, after: 300 },
          children: [new TextRun({ text: "SOLUÇÕES EM PRODUÇÃO E GESTÃO EMPRESARIAL", font: HFONT, size: 18, color: LIGHT_BLUE, characterSpacing: 40 })] }),
      ],
    })] })],
  }),
  new Paragraph({ spacing: { before: 600, after: 0 }, children: [new TextRun({ text: "DOCUMENTO DE ESCOPO", font: HFONT, bold: true, size: 22, color: ORANGE, characterSpacing: 60 })] }),
  new Paragraph({ spacing: { before: 60, after: 0 }, children: [new TextRun({ text: "Portal Aprimora", font: HFONT, bold: true, size: 64, color: NAVY })] }),
  new Paragraph({ spacing: { after: 240 }, border: { bottom: { style: BorderStyle.SINGLE, size: 18, color: ORANGE, space: 8 } },
    children: [new TextRun({ text: "Módulo Comercial (MVP) e visão para a plataforma da empresa júnior", font: HFONT, size: 28, color: NAVY_DARK })] }),
  ...[
    ["Versão", `${VERSAO}, proposta para validação da diretoria`],
    ["Data", DATA],
    ["Responsável", "Diretoria Comercial da Aprimora"],
    ["Público", "Todos os membros da Aprimora, atuais e futuros"],
    ["Repositório", "github.com/Maroto-Aprimora/PortalAprimora (privado)"],
  ].map(([k, v]) => new Paragraph({ spacing: { after: 40 }, children: [
    new TextRun({ text: `${k}:  `, bold: true, color: NAVY, font: HFONT, size: 19 }),
    new TextRun({ text: v, size: 19, color: "333333" }),
  ] })),
  new Paragraph({ children: [new PageBreak()] }),
];

// ---------- SUMÁRIO (campo do Word; atualizado ao abrir o arquivo) ----------
const sumario = [
  new Paragraph({ spacing: { after: 240 }, children: [new TextRun({ text: "Sumário", font: HFONT, bold: true, size: 40, color: NAVY })] }),
  new TableOfContents("Sumário", { hyperlink: true, headingStyleRange: "1-2" }),
];

// ---------- Blocos neutros → elementos do Word ----------
function render(b) {
  switch (b.t) {
    case "h1": return [H1(b.text)];
    case "h2": return [H2(b.text)];
    case "h3": return [H3(b.text)];
    case "p": return [P(b.text)];
    case "ul": return bullets(b.items);
    case "ol": return numbered(b.items);
    case "table": return table(b.headers, b.rows, b.widths, b.opts);
    case "callout": return callout(b.title, b.lines, b.kind);
    case "figure": return figure(b.file, b.w, b.h, b.caption);
    case "closing": return [
      spacer(400),
      new Paragraph({ alignment: AlignmentType.CENTER, children: [new TextRun({ text: "APRIMORA", font: HFONT, size: 28, color: NAVY, characterSpacing: 200 })] }),
      new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 40 }, children: [new TextRun({ text: "Empresa Júnior de Engenharia de Produção · UTFPR Londrina", size: 17, color: GRAY })] }),
      new Paragraph({ alignment: AlignmentType.CENTER, children: [new TextRun({ text: "aprimoraej.com · contato@aprimoraej.com · @aprimora.ej", size: 17, color: ORANGE })] }),
    ];
    default: throw new Error("Bloco desconhecido: " + b.t);
  }
}
const corpo = blocos.flatMap(render);

const header = new Header({ children: [new Paragraph({
  border: { bottom: { style: BorderStyle.SINGLE, size: 6, color: ORANGE, space: 4 } },
  tabStops: [{ type: TabStopType.RIGHT, position: CONTENT_W }],
  children: [
    new TextRun({ text: "APRIMORA", font: HFONT, bold: true, size: 16, color: NAVY, characterSpacing: 80 }),
    new TextRun({ text: `\tPortal Aprimora · Documento de Escopo v${VERSAO}`, size: 15, color: GRAY }),
  ],
})] });
const footer = new Footer({ children: [new Paragraph({
  tabStops: [{ type: TabStopType.RIGHT, position: CONTENT_W }],
  children: [
    new TextRun({ text: "Uso interno · Aprimora EJ", size: 15, color: GRAY }),
    new TextRun({ children: ["\t", PageNumber.CURRENT], size: 16, color: NAVY, bold: true, font: HFONT }),
  ],
})] });

const conteudoFinal = [...sumario, ...corpo];

const doc = new Document({
  features: { updateFields: true },
  creator: "Diretoria Comercial — Aprimora",
  title: "Portal Aprimora — Documento de Escopo",
  description: "Escopo do Portal Aprimora (Módulo Comercial)",
  styles: {
    default: { document: { run: { font: BFONT, size: 20, color: "222222" } } },
    paragraphStyles: [
      { id: "Heading1", name: "Heading 1", basedOn: "Normal", next: "Normal", quickFormat: true,
        run: { font: HFONT, size: 36, bold: true, color: NAVY },
        paragraph: { spacing: { before: 0, after: 240 }, outlineLevel: 0,
          border: { bottom: { style: BorderStyle.SINGLE, size: 12, color: ORANGE, space: 6 } } } },
      { id: "Heading2", name: "Heading 2", basedOn: "Normal", next: "Normal", quickFormat: true,
        run: { font: HFONT, size: 26, bold: true, color: NAVY },
        paragraph: { spacing: { before: 300, after: 120 }, outlineLevel: 1, keepNext: true } },
      { id: "Heading3", name: "Heading 3", basedOn: "Normal", next: "Normal", quickFormat: true,
        run: { font: HFONT, size: 21, bold: true, color: ORANGE },
        paragraph: { spacing: { before: 200, after: 80 }, outlineLevel: 2, keepNext: true } },
    ],
  },
  numbering: { config: [
    { reference: "bullets", levels: [0, 1, 2].map((l) => ({ level: l, format: LevelFormat.BULLET, text: ["●", "○", "▪"][l], alignment: AlignmentType.LEFT,
      style: { run: { color: ORANGE }, paragraph: { indent: { left: 400 + l * 360, hanging: 260 } } } })) },
    { reference: "numbers", levels: [{ level: 0, format: LevelFormat.DECIMAL, text: "%1.", alignment: AlignmentType.LEFT,
      style: { run: { color: NAVY, bold: true }, paragraph: { indent: { left: 440, hanging: 320 } } } }] },
  ] },
  sections: [
    { properties: { page: { size: { width: PAGE_W, height: 16838 }, margin: { top: MARGIN, bottom: MARGIN, left: MARGIN, right: MARGIN } } },
      children: capa },
    { properties: { page: { size: { width: PAGE_W, height: 16838 }, margin: { top: 1300, bottom: 1134, left: MARGIN, right: MARGIN, header: 560, footer: 500 } } },
      headers: { default: header }, footers: { default: footer }, children: conteudoFinal },
  ],
});

Packer.toBuffer(doc).then((buf) => {
  const out = path.join(DIR, "..", "Escopo-Portal-Aprimora.docx");
  fs.writeFileSync(out, buf);
  console.log("ok", out);
});
