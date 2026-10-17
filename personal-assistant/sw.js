const CACHE='bek-yordamchi-v70';
const ASSETS=['./reading-timer.js?v=70','./reading-device-sync.js?v=70','./','./index.html','./styles.css?v=70','./app.js?v=70','./book-costs.js?v=70','./book-cost-device-sync.js?v=70','./book-cost-export.js?v=70','./book-cost-sync.js?v=70','./book-cost-sync-config.js?v=70','./backup-migration.js?v=70','./decimal-fx.js?v=70','./currency-converter.js?v=70','./currency-rate-editor.js?v=70','./workspaces.js?v=70','./korea-products.js?v=70','./manifest.webmanifest','./icon.svg'];

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