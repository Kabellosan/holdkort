// Caches map tiles from the kommune's WMS so each tile is only fetched once per phone.
const TILE_CACHE = "tiles-v1";
const APP_CACHE = "app-v1";
const APP_FILES = ["./", "index.html", "manifest.json", "icons/icon-192.png", "icons/icon-512.png"];
const SHELL_WAIT = 3000; // ms: on a weak connection the app opens from the phone after this, instead of waiting
const MAX_AGE_DAYS = 180; // the 2024 aerial photo doesn't change; keep tiles for half a year

self.addEventListener("install", e => {
  e.waitUntil(caches.open(APP_CACHE).then(c => c.addAll(APP_FILES)).then(() => self.skipWaiting()));
});
self.addEventListener("activate", e => e.waitUntil(self.clients.claim()));

self.addEventListener("fetch", e => {
  const url = new URL(e.request.url);

  // Map tiles: cache first, network only if missing or older than MAX_AGE_DAYS
  if (url.hostname === "kort.ikast-brande.dk" && url.pathname.endsWith("/wms") && url.searchParams.get("REQUEST") === "GetMap") {
    e.respondWith((async () => {
      const cache = await caches.open(TILE_CACHE);
      const hit = await cache.match(e.request.url);
      const stamp = await caches.open("tile-dates").then(c => c.match(e.request.url)).then(r => r ? r.text() : null);
      // The aerial photo keeps 180 days; other layers (the tilbudsliste lines) can change, so a week
      const days = /ortofoto/i.test(url.searchParams.get("LAYERS") || "") ? MAX_AGE_DAYS : 7;
      const fresh = stamp && (Date.now() - Number(stamp)) < days * 864e5;
      if (hit && fresh) return hit;
      try {
        const res = await fetch(e.request.url, { mode: "no-cors" });
        cache.put(e.request.url, res.clone());
        caches.open("tile-dates").then(c => c.put(e.request.url, new Response(String(Date.now()))));
        return res;
      } catch (err) {
        if (hit) return hit; // offline: serve the old tile
        throw err;
      }
    })());
    return;
  }

  if (e.request.method !== "GET") return;
  // Libraries: their address has a fixed version, so the copy on the phone is always right
  if (url.hostname === "cdn.jsdelivr.net") {
    e.respondWith(caches.match(e.request).then(hit => hit || fetch(e.request).then(res => {
      if (res.ok) { const copy = res.clone(); caches.open(APP_CACHE).then(c => c.put(e.request, copy)); }
      return res;
    })));
    return;
  }
  // App shell: network first, so a new version shows at once; but when the phone reloads the page on a weak
  // connection (it was thrown out of memory), the copy on the phone is used after SHELL_WAIT and offline.
  // The network answer still updates the copy for next time.
  if (url.origin === location.origin) {
    const net = fetch(e.request).then(res => {
      if (res.ok) { const copy = res.clone(); caches.open(APP_CACHE).then(c => c.put(e.request, copy)); }
      return res;
    });
    e.waitUntil(net.catch(() => {}));
    e.respondWith((async () => {
      const hit = await caches.match(e.request, {ignoreSearch: e.request.mode === "navigate"});
      if (!hit) return net;
      const late = new Promise(r => setTimeout(() => r(hit), SHELL_WAIT));
      return Promise.race([net.catch(() => hit), late]);
    })());
  }
});
