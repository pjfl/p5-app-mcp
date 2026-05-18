self.addEventListener('push', function(event) {
   const data = event.data ? event.data.json() : {};
   if (data.message) {
      const body = data.message;
      const title = data.title ? data.title : 'MCP Service Worker';
      event.waitUntil(self.registration.showNotification(title, { body }));
   }
   if (data.events) {
      event.waitUntil((async () => {
         const options = { includeUncontrolled: true };
         const allClients = await clients.matchAll(options);
         for (const client of allClients) {
            const url = new URL(client.url);
            if (url.pathname == '/mcp/state') client.postMessage(data);
         }
      })());
   }
});
