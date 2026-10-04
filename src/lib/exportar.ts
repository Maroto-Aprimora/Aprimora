import "server-only";
import writeXlsxFile from "write-excel-file/node";

export type Planilha = { nome: string; colunas: string[]; linhas: (string | number | null)[][] };

/** CSV no padrão do Excel brasileiro: separador ";", BOM para acentos e uma planilha após a outra. */
export function gerarCsv(planilhas: Planilha[]) {
  const celula = (v: string | number | null) => {
    if (v == null) return "";
    const s = typeof v === "number" ? String(v).replace(".", ",") : v;
    return /[";\n\r]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
  };
  const blocos = planilhas.map((p) => [
    ...(planilhas.length > 1 ? [p.nome] : []),
    p.colunas.map(celula).join(";"),
    ...p.linhas.map((l) => l.map(celula).join(";")),
  ].join("\r\n"));
  return "﻿" + blocos.join("\r\n\r\n");
}

export async function gerarXlsx(planilhas: Planilha[]) {
  const folhas = planilhas.map((p) => ({
    sheet: p.nome.slice(0, 31),
    stickyRowsCount: 1,
    columns: p.colunas.map((c) => ({ width: Math.min(40, Math.max(12, c.length + 4)) })),
    data: [
      p.colunas.map((c) => ({ value: c, fontWeight: "bold" as const })),
      ...p.linhas.map((l) => l.map((v) => (v == null ? null : { value: v }))),
    ],
  }));
  return writeXlsxFile(folhas).toBuffer();
}
