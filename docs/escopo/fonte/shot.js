// Renderiza os diagramas (diagramas/*.html) em PNG (imagens/*.png) com o Chromium do Playwright.
// Uso: node shot.js
const path = require("path");
const { chromium } = require("playwright");
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ deviceScaleFactor: 2 });
  for (const n of ["funil", "arquitetura", "cadencia"]) {
    await p.goto("file://" + path.join(__dirname, "diagramas", n + ".html"));
    await p.waitForTimeout(300);
    await (await p.$(".wrap")).screenshot({ path: path.join(__dirname, "imagens", n + ".png") });
  }
  await b.close();
})();
