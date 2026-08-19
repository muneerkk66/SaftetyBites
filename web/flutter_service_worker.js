self.addEventListener('install', function() {
  self.skipWaiting();
});

self.addEventListener('activate', function(event) {
  event.waitUntil((async function() {
    const cacheNames = await caches.keys();
    await Promise.all(cacheNames.map(function(name) {
      return caches.delete(name);
    }));
    await self.registration.unregister();

    const clients = await self.clients.matchAll({
      type: 'window',
      includeUncontrolled: true,
    });
    for (const client of clients) {
      await client.navigate(client.url);
    }
  })());
});
