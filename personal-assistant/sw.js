const CACHE='bek-yordamchi-v52';
const ASSETS=['./reading-timer.js?v=52','./reading-device-sync.js?v=52','./','./index.html','./styles.css?v=52','./app.js?v=52','./book-costs.js?v=52','./book-cost-device-sync.js?v=52','./book-cost-export.js?v=52','./book-cost-sync.js?v=52','./book-cost-sync-config.js?v=52','./currency-converter.js?v=52','./korea-products.js?v=52','./manifest.webmanifest','./icon.svg'];

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