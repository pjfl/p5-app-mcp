self.addEventListener('push', function(event) {
   const data = event.data ? event.data.json() : {};
   if (data['native']) {
      const body = data.message || 'No message';
      const options = data.options || {};
      const title = options.title ? options.title : 'Service Worker';
      event.waitUntil(self.registration.showNotification(title, { body }));
   }
   else {
      event.waitUntil((async () => {
         const options = { includeUncontrolled: true };
         const allClients = await clients.matchAll(options);
         for (const client of allClients) client.postMessage(data);
      })());
   }
});
