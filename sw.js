const NAME='iaionex-v1';
const FILES=['/','/index.html','/styles.css','/app.js','/logo.svg','/favicon.svg'];
self.addEventListener('install',e=>{e.waitUntil(caches.open(NAME).then(c=>c.addAll(FILES)).then(()=>self.skipWaiting()))});
self.addEventListener('activate',e=>{e.waitUntil(caches.keys().then(all=>Promise.all(all.filter(x=>x!==NAME).map(x=>caches.delete(x))))); self.clients.claim();});
self.addEventListener('fetch',e=>{e.respondWith(caches.match(e.request).then(r=>r||fetch(e.request)))});
