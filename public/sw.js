// Service worker do Portal Aprimora: recebe notificações push e abre o link ao tocar.
self.addEventListener("install", () => self.skipWaiting());
self.addEventListener("activate", (event) => event.waitUntil(self.clients.claim()));

self.addEventListener("push", (event) => {
  let dados = {};
  try {
    dados = event.data ? event.data.json() : {};
  } catch {
    dados = { titulo: "Portal Aprimora", mensagem: event.data ? event.data.text() : "" };
  }
  event.waitUntil(
    self.registration.showNotification(dados.titulo || "Portal Aprimora", {
      body: dados.mensagem || "",
      icon: "/icone-192.png",
      badge: "/icone-192.png",
      tag: dados.tag || undefined,
      data: { link: dados.link || "/painel" },
    }),
  );
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  const link = (event.notification.data && event.notification.data.link) || "/painel";
  event.waitUntil(
    self.clients.matchAll({ type: "window", includeUncontrolled: true }).then((janelas) => {
      for (const j of janelas) {
        if ("focus" in j) {
          j.navigate(link);
          return j.focus();
        }
      }
      return self.clients.openWindow(link);
    }),
  );
});
