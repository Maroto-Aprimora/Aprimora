import { hojeBR, somarDias } from "@/lib/datas";

/** Período de análise em dias de Brasília (inclusive). */
export type Periodo = { de: string; ate: string; rotulo: string; chave: string };

const pad = (n: number) => String(n).padStart(2, "0");
const ultimoDia = (ano: number, mes: number) => new Date(Date.UTC(ano, mes, 0)).getUTCDate();

/** "4T2026" → 01/10/2026 a 31/12/2026 */
export function periodoDoTrimestre(t: string): Periodo {
  const tri = Number(t[0]);
  const ano = Number(t.slice(2));
  const mesFim = tri * 3;
  return {
    de: `${ano}-${pad(mesFim - 2)}-01`,
    ate: `${ano}-${pad(mesFim)}-${pad(ultimoDia(ano, mesFim))}`,
    rotulo: `${tri}º trimestre de ${ano}`,
    chave: t,
  };
}

export function trimestreDe(dia: string) {
  const [ano, mes] = dia.split("-").map(Number);
  return `${Math.floor((mes - 1) / 3) + 1}T${ano}`;
}

/** Lê ?periodo=mes|trimestre|ano|30d|personalizado&de=&ate= (padrão: trimestre atual). */
export function periodoDosParametros(sp: Record<string, string | string[] | undefined>): Periodo {
  const hoje = hojeBR();
  const [ano, mes] = hoje.split("-").map(Number);
  const tipo = typeof sp.periodo === "string" ? sp.periodo : "trimestre";
  const de = typeof sp.de === "string" ? sp.de : "";
  const ate = typeof sp.ate === "string" ? sp.ate : "";
  const valido = (d: string) => /^\d{4}-\d{2}-\d{2}$/.test(d);
  switch (tipo) {
    case "mes":
      return { de: `${ano}-${pad(mes)}-01`, ate: `${ano}-${pad(mes)}-${pad(ultimoDia(ano, mes))}`, rotulo: "Este mês", chave: "mes" };
    case "30d":
      return { de: somarDias(hoje, -29), ate: hoje, rotulo: "Últimos 30 dias", chave: "30d" };
    case "ano":
      return { de: `${ano}-01-01`, ate: `${ano}-12-31`, rotulo: `Ano de ${ano}`, chave: "ano" };
    case "personalizado":
      if (valido(de) && valido(ate) && de <= ate) return { de, ate, rotulo: `${de.split("-").reverse().join("/")} a ${ate.split("-").reverse().join("/")}`, chave: "personalizado" };
      break;
  }
  return { ...periodoDoTrimestre(trimestreDe(hoje)), chave: "trimestre" };
}

/** Limites em ISO (UTC) para consultar timestamptz: [inicio, fim). */
export function limitesIso(p: Pick<Periodo, "de" | "ate">) {
  return {
    inicio: new Date(`${p.de}T00:00:00-03:00`).toISOString(),
    fim: new Date(`${somarDias(p.ate, 1)}T00:00:00-03:00`).toISOString(),
  };
}
