// Caches map tiles from the kommune's WMS so each tile is only fetched once per phone.
const TILE_CACHE = "tiles-v1";
const APP_CACHE = "app-v1";
const APP_FILES = ["./", "index.html", "manifest.json"];
const MAX_AGE_DAYS = 30; // the aerial photo changes once a year; refresh tiles monthly

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
      const fresh = stamp && (Date.now() - Number(stamp)) < MAX_AGE_DAYS * 864e5;
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

  // App shell and libraries: network first, cache fallback for offline
  if (e.request.method === "GET" && (url.origin === location.origin || url.hostname === "cdn.jsdelivr.net")) {
    e.respondWith(fetch(e.request).then(res => {
      const copy = res.clone(); caches.open(APP_CACHE).then(c => c.put(e.request, copy)); return res;
    }).catch(() => caches.match(e.request)));
  }
});
