// Gera o Documento de Escopo em PDF a partir de conteudo.js, usando HTML + Chromium (Playwright).
// Uso: node render-pdf.js   (requer playwright e o utilitário pdfunite, do poppler-utils)
// Funciona em duas passadas: a 1ª descobre em que página cada título cai; a 2ª escreve o sumário.
const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");
const { chromium } = require("playwright");
const { VERSAO, DATA, blocos } = require("./conteudo");
const { cores: C, fontes: F } = require("./marca");

const DIR = __dirname;
const TMP = fs.mkdtempSync(path.join(require("os").tmpdir(), "escopo-"));
const b64 = (f) => "data:image/" + (f.endsWith(".jpg") ? "jpeg" : "png") + ";base64," + fs.readFileSync(path.join(DIR, "imagens", f)).toString("base64");
const esc = (s) => String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
const inline = (s) => esc(s).replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>").replace(/`([^`]+)`/g, "<code>$1</code>");

const CSS = `
@page { size: A4; margin: 22mm 18mm 18mm 18mm; }
* { box-sizing: border-box; }
body { margin: 0; font-family: '${F.texto}', sans-serif; font-size: 10pt; line-height: 1.5; color: #222; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
h1, h2, h3 { font-family: '${F.titulo}', sans-serif; }
h1 { break-before: page; font-size: 20pt; color: ${C.azul}; margin: 0 0 14pt; padding-bottom: 6pt; border-bottom: 2.5pt solid ${C.laranja}; }
h2 { font-size: 13pt; color: ${C.azul}; margin: 18pt 0 6pt; break-after: avoid; }
h3 { font-size: 10.5pt; color: ${C.laranja}; margin: 12pt 0 4pt; break-after: avoid; }
p { margin: 0 0 7pt; text-align: justify; }
ul, ol { margin: 0 0 9pt; padding-left: 20pt; }
li { margin-bottom: 3pt; }
ul li::marker { color: ${C.laranja}; }
ol li::marker { color: ${C.azul}; font-weight: 700; }
code { font-family: Consolas, 'DejaVu Sans Mono', monospace; font-size: 8.5pt; color: ${C.azulProfundo}; background: ${C.fundoSuave}; padding: 0 3px; border-radius: 3px; }
table.t { width: 100%; border-collapse: collapse; margin: 4pt 0 12pt; font-size: 8.4pt; line-height: 1.38; }
table.t th { background: ${C.azul}; color: #fff; font-family: '${F.titulo}'; font-weight: 700; text-align: left; padding: 5pt 6pt; border: 0.6pt solid ${C.azul}; }
table.t td { padding: 4.5pt 6pt; border: 0.6pt solid #D5DCE4; vertical-align: top; }
table.t tr:nth-child(even) td { background: ${C.fundoSuave}; }
table.t tr { break-inside: avoid; }
table.t thead { display: table-header-group; }
table.t td.b { font-weight: 700; color: ${C.azulProfundo}; }
.call { break-inside: avoid; background: ${C.fundoSuave}; border-left: 5pt solid ${C.azul}; padding: 8pt 12pt; margin: 6pt 0 12pt; border-radius: 0 6px 6px 0; }
.call.warn { background: ${C.fundoLaranja}; border-left-color: ${C.laranja}; }
.call .ti { font-family: '${F.titulo}'; font-weight: 700; color: ${C.azul}; margin-bottom: 3pt; font-size: 9.8pt; }
.call.warn .ti { color: #B35A17; }
.call p { margin: 0 0 3pt; font-size: 9.4pt; text-align: left; }
figure { margin: 8pt 0 12pt; text-align: center; break-inside: avoid; }
figure img { width: 100%; }
figcaption { font-size: 8.5pt; color: ${C.cinza}; font-style: italic; margin-top: 4pt; }
.toc h2 { font-size: 22pt; margin: 0 0 14pt; }
.toc .l1, .toc .l2 { display: flex; align-items: baseline; gap: 6pt; }
.toc .l1 { font-family: '${F.titulo}'; font-weight: 700; color: ${C.azul}; font-size: 10pt; margin-top: 7pt; }
.toc .l2 { padding-left: 16pt; font-size: 9pt; color: #333; margin-top: 1.5pt; }
.toc .dots { flex: 1; border-bottom: 1px dotted #9AA5B1; transform: translateY(-3px); }
.toc .pg { min-width: 18pt; text-align: right; color: ${C.cinza}; }
.mk { position: absolute; font-size: 1px; color: #fff; }
.closing { text-align: center; margin-top: 40pt; }
.closing .w { font-family: '${F.titulo}'; letter-spacing: 8pt; color: ${C.azul}; font-size: 15pt; }
.closing .s { color: ${C.cinza}; font-size: 8.5pt; }
.closing .o { color: ${C.laranja}; font-size: 8.5pt; }
`;

function corpoHtml(paginas, marcadores) {
  const heads = [];
  let n = 0;
  const html = blocos.map((b) => {
    switch (b.t) {
      case "h1": case "h2": {
        const id = "h" + n++;
        heads.push({ id, level: b.t === "h1" ? 1 : 2, text: b.text });
        const mk = marcadores ? `<span class="mk">§${id}§</span>` : "";
        return `<${b.t} id="${id}">${mk}${esc(b.text)}</${b.t}>`;
      }
      case "h3": return `<h3>${esc(b.text)}</h3>`;
      case "p": return `<p>${inline(b.text)}</p>`;
      case "ul": return `<ul>${b.items.map((i) => `<li>${inline(i)}</li>`).join("")}</ul>`;
      case "ol": return `<ol>${b.items.map((i) => `<li>${inline(i)}</li>`).join("")}</ol>`;
      case "table": {
        const tot = b.widths.reduce((a, c) => a + c, 0);
        const cols = b.widths.map((w) => `<col style="width:${((w / tot) * 100).toFixed(2)}%">`).join("");
        const fs = b.opts.size ? `style="font-size:${(b.opts.size / 2) * 0.98}pt"` : "";
        const rows = b.rows.map((r) => `<tr>${r.map((c, i) => `<td${i === 0 && b.opts.boldFirst ? ' class="b"' : ""}>${String(c).split("\n").map(inline).join("<br>")}</td>`).join("")}</tr>`).join("");
        return `<table class="t" ${fs}><colgroup>${cols}</colgroup><thead><tr>${b.headers.map((h) => `<th>${esc(h)}</th>`).join("")}</tr></thead><tbody>${rows}</tbody></table>`;
      }
      case "callout": return `<div class="call ${b.kind === "warn" ? "warn" : ""}"><div class="ti">${esc(b.title)}</div>${b.lines.map((l) => `<p>${inline(l)}</p>`).join("")}</div>`;
      case "figure": return `<figure><img src="${b64(b.file)}" alt="${esc(b.caption)}"><figcaption>${esc(b.caption)}</figcaption></figure>`;
      case "closing": return `<div class="closing"><div class="w">APRIMORA</div><div class="s">Empresa Júnior de Engenharia de Produção · UTFPR Londrina</div><div class="o">aprimoraej.com · contato@aprimoraej.com · @aprimora.ej</div></div>`;
      default: throw new Error("Bloco desconhecido: " + b.t);
    }
  }).join("\n");
  const toc = `<div class="toc"><h2>Sumário</h2>${heads.map((h) => `<div class="l${h.level}"><span>${esc(h.text)}</span><span class="dots"></span><span class="pg">${paginas[h.id] ?? "00"}</span></div>`).join("")}</div>`;
  return { html: `<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><style>${CSS}</style></head><body>${toc}${html}</body></html>`, heads };
}

const capaHtml = `<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><style>
@page { size: A4; margin: 0; }
body { margin: 0; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
.c { position: relative; width: 210mm; height: 297mm; background: ${C.azul}; overflow: hidden; color: #fff; font-family: '${F.texto}'; }
.tri1 { position: absolute; right: 0; top: 0; width: 70mm; height: 70mm; background: ${C.azulClaro}; clip-path: polygon(0 0, 100% 0, 50% 100%); opacity: .9; }
.tri2 { position: absolute; left: 0; bottom: 0; width: 95mm; height: 95mm; background: ${C.laranja}; clip-path: polygon(0 100%, 0 0, 100% 100%); }
.ln1 { position: absolute; right: 22mm; top: -10mm; width: 1.2mm; height: 120mm; background: #fff; transform: rotate(-42deg); transform-origin: top; opacity: .85; }
.logo { position: absolute; top: 34mm; left: 50%; transform: translateX(-50%); width: 100mm; }
.tag { position: absolute; top: 140mm; width: 100%; text-align: center; font-family: '${F.titulo}'; font-size: 9pt; letter-spacing: 3pt; color: ${C.azulClaro}; }
.txt { position: absolute; left: 24mm; right: 24mm; top: 168mm; }
.k { font-family: '${F.titulo}'; font-weight: 700; color: ${C.laranja}; letter-spacing: 4pt; font-size: 11pt; }
.t { font-family: '${F.titulo}'; font-weight: 800; font-size: 40pt; line-height: 1.1; margin: 4mm 0 3mm; }
.s { font-family: '${F.titulo}'; font-size: 14pt; color: #E3ECF3; padding-bottom: 6mm; border-bottom: 1mm solid ${C.laranja}; }
.meta { position: absolute; right: 24mm; bottom: 22mm; text-align: right; font-size: 9.5pt; line-height: 1.7; color: #E3ECF3; }
.meta b { font-family: '${F.titulo}'; color: #fff; }
</style></head><body><div class="c">
<div class="tri1"></div><div class="ln1"></div><div class="tri2"></div>
<img class="logo" src="${b64("logo-quadrada.jpg")}" alt="Logo Aprimora">
<div class="tag">SOLUÇÕES EM PRODUÇÃO E GESTÃO EMPRESARIAL</div>
<div class="txt"><div class="k">DOCUMENTO DE ESCOPO</div><div class="t">Portal Aprimora</div>
<div class="s">Módulo Comercial (MVP) e visão para a plataforma da empresa júnior</div></div>
<div class="meta"><b>Versão</b> ${VERSAO}, proposta para validação · <b>Data</b> ${DATA}<br>
<b>Responsável</b> Diretoria Comercial da Aprimora<br><b>Público</b> todos os membros, atuais e futuros</div>
</div></body></html>`;

const header = `<div style="width:100%;margin:0 18mm;padding-bottom:3px;border-bottom:1.2px solid ${C.laranja};display:flex;justify-content:space-between;font-family:'${F.texto}';font-size:7.5px;color:${C.cinza}">
<span style="font-family:'${F.titulo}';font-weight:700;letter-spacing:2px;color:${C.azul}">APRIMORA</span><span>Portal Aprimora · Documento de Escopo v${VERSAO}</span></div>`;
const footer = `<div style="width:100%;margin:0 18mm;display:flex;justify-content:space-between;font-family:'${F.texto}';font-size:7.5px;color:${C.cinza}">
<span>Uso interno · Aprimora EJ</span><span style="font-family:'${F.titulo}';font-weight:700;color:${C.azul};font-size:8.5px" class="pageNumber"></span></div>`;

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage();
  const printBody = async (html, out) => {
    await page.setContent(html, { waitUntil: "load" });
    await page.pdf({ path: out, format: "A4", printBackground: true, displayHeaderFooter: true, headerTemplate: header, footerTemplate: footer, margin: { top: "22mm", bottom: "18mm", left: "18mm", right: "18mm" } });
  };
  // 1ª passada: marcadores invisíveis para localizar os títulos
  const p1 = path.join(TMP, "p1.pdf");
  const { heads } = corpoHtml({}, true);
  await printBody(corpoHtml({}, true).html, p1);
  const total = Number(/Pages:\s+(\d+)/.exec(execFileSync("pdfinfo", [p1]).toString())[1]);
  const paginas = {};
  for (let i = 1; i <= total; i++) {
    const txt = execFileSync("pdftotext", ["-f", String(i), "-l", String(i), p1, "-"]).toString();
    for (const m of txt.matchAll(/§(h\d+)§/g)) paginas[m[1]] ??= i;
  }
  const faltando = heads.filter((h) => !paginas[h.id]);
  if (faltando.length) console.warn("Títulos sem página:", faltando.map((h) => h.text));
  // 2ª passada: sem marcadores, com as páginas no sumário
  const corpo = path.join(TMP, "corpo.pdf");
  await printBody(corpoHtml(paginas, false).html, corpo);
  const capa = path.join(TMP, "capa.pdf");
  await page.setContent(capaHtml, { waitUntil: "load" });
  await page.pdf({ path: capa, format: "A4", printBackground: true, margin: { top: 0, bottom: 0, left: 0, right: 0 } });
  await browser.close();
  const out = path.join(DIR, "..", "Escopo-Portal-Aprimora.pdf");
  execFileSync("pdfunite", [capa, corpo, out]);
  console.log("ok", out, `(${total + 1} páginas)`);
})();
