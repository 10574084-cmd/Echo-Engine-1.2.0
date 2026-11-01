// Echo Engine (Android app): serves the files that an update downloaded (see echo-update.js) instead of the ones the app came with.
// Everything else goes through untouched. It only exists inside the app; the web page does not register it.
const CACHE = 'echo-update';

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()));

self.addEventListener('fetch', (event) => {
	const request = event.request;
	if (request.method !== 'GET' || request.headers.has('range')) return;
	const url = new URL(request.url);
	if (url.origin !== self.location.origin) return;
	if (url.pathname === '/echo-sw.js' || url.pathname === '/update.json') return;

	event.respondWith((async () => {
		try {
			const cache = await caches.open(CACHE);
			const key = url.pathname.endsWith('/') ? new URL('index.html', url).href : url.origin + url.pathname;
			const hit = await cache.match(key);
			if (hit) return hit;
		} catch (e) { /* no cache: use the bundled file */ }
		return fetch(request);
	})());
});
