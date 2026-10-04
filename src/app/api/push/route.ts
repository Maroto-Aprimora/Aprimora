import { timingSafeEqual } from "node:crypto";
import webpush from "web-push";

/**
 * Recebe pedidos do banco (gatilho enviar_push via pg_net) e entrega as notificações push.
 * Protegido por um segredo compartilhado (PUSH_SEGREDO na Vercel = privado.config no banco).
 */
type Corpo = {
  assinaturas: { endpoint: string; keys: { p256dh: string; auth: string } }[];
  notificacao: { titulo: string; mensagem?: string | null; link?: string | null; tag?: string | null };
};

function segredoConfere(recebido: string | null) {
  const esperado = process.env.PUSH_SEGREDO;
  if (!esperado || !recebido) return false;
  const a = Buffer.from(recebido);
  const b = Buffer.from(esperado);
  return a.length === b.length && timingSafeEqual(a, b);
}

export async function POST(request: Request) {
  if (!segredoConfere(request.headers.get("x-push-segredo"))) {
    return Response.json({ erro: "não autorizado" }, { status: 401 });
  }
  const publica = process.env.NEXT_PUBLIC_VAPID_PUBLIC_KEY;
  const privada = process.env.VAPID_PRIVATE_KEY;
  if (!publica || !privada) return Response.json({ erro: "VAPID não configurado" }, { status: 500 });
  webpush.setVapidDetails("mailto:comercial@aprimoraej.com", publica, privada);

  const corpo = (await request.json()) as Corpo;
  const carga = JSON.stringify(corpo.notificacao);
  const resultados = await Promise.allSettled(
    (corpo.assinaturas ?? []).map((a) => webpush.sendNotification(a, carga, { TTL: 60 * 60 * 12 })),
  );
  const enviadas = resultados.filter((r) => r.status === "fulfilled").length;
  return Response.json({ enviadas, falhas: resultados.length - enviadas });
}
