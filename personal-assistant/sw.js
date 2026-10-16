const CACHE='bek-yordamchi-v53';
const ASSETS=['./reading-timer.js?v=53','./reading-device-sync.js?v=53','./','./index.html','./styles.css?v=53','./app.js?v=53','./book-costs.js?v=53','./book-cost-device-sync.js?v=53','./book-cost-export.js?v=53','./book-cost-sync.js?v=53','./book-cost-sync-config.js?v=53','./backup-migration.js?v=53','./currency-converter.js?v=53','./korea-products.js?v=53','./manifest.webmanifest','./icon.svg'];

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