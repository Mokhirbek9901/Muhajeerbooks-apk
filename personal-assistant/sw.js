const CACHE='bek-yordamchi-v67';
const ASSETS=['./reading-timer.js?v=67','./reading-device-sync.js?v=67','./','./index.html','./styles.css?v=67','./app.js?v=67','./book-costs.js?v=67','./book-cost-device-sync.js?v=67','./book-cost-export.js?v=67','./book-cost-sync.js?v=67','./book-cost-sync-config.js?v=67','./backup-migration.js?v=67','./currency-converter.js?v=67','./currency-rate-editor.js?v=67','./workspaces.js?v=67','./korea-products.js?v=67','./manifest.webmanifest','./icon.svg'];

self.addEventListener('install',event=>{
  event.waitUntil(caches.open(CACHE).then(cache=>cache.addAll(ASSETS)));
  self.skipWaiting();
});

self.addEventListener('activate',event=>{
  event.waitUntil(
    caches.keys().then(keys=>Promise.all(keys.filter(k=>k!==CACHE).map(k=>caches.delete(k))))
  );
  self.clients.claim();
});

self.addEventListener('fetch',event=>{
  if(event.request.method!=='GET') return;
  event.respondWith(
    fetch(event.request).then(response=>{
      const clone=response.clone();
      caches.open(CACHE).then(cache=>cache.put(event.request,clone)).catch(()=>{});
      return response;
    }).catch(()=>caches.match(event.request).then(hit=>hit||caches.match('./index.html')))
  );
});