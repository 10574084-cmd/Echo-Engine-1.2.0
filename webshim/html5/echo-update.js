// Echo Engine (Android app): updates itself when the phone is on Wi-Fi.
// The web page is always the newest version: this script downloads its list of files (update.json), fetches only the files that
// changed and keeps them in the app's storage; echo-sw.js serves them the next time the game opens. Saves are not touched.
// It does nothing in a normal browser.
(function () {
	'use strict';
	var cap = window.Capacitor;
	if (!cap || !(cap.isNativePlatform ? cap.isNativePlatform() : false) || !('serviceWorker' in navigator) || !window.caches) return;

	var SITE = 'https://10574084-cmd.github.io/Echo-Engine-1.2.0/';
	var CACHE = 'echo-update';
	var STATE = '/__echo_update_state';
	var CHECK_AFTER_MS = 30000;
	var CHECK_EVERY_MS = 6 * 60 * 60 * 1000;

	function get(k) { try { return localStorage.getItem(k); } catch (e) { return null; } }
	function put(k, v) { try { localStorage.setItem(k, v); } catch (e) { /* private mode */ } }

	function toast(text) {
		var d = document.createElement('div');
		d.textContent = text;
		d.style.cssText = 'position:fixed;left:50%;bottom:24px;transform:translateX(-50%);max-width:80%;padding:10px 18px;border-radius:8px;' +
			'font:16px sans-serif;color:#fff;background:rgba(20,20,20,0.9);z-index:20;pointer-events:none';
		document.body.appendChild(d);
		setTimeout(function () { d.remove(); }, 9000);
	}

	// ---- safety net: if an update makes the game fail to start three times in a row, go back to the files the app came with
	var fails = Number(get('echoUpdBoot') || 0);
	if (fails >= 3) {
		put('echoUpdBoot', '0');
		caches.delete(CACHE).then(function () {
			return navigator.serviceWorker.getRegistrations();
		}).then(function (regs) {
			regs.forEach(function (r) { r.unregister(); });
			location.reload();
		});
		return;
	}
	put('echoUpdBoot', String(fails + 1));
	setTimeout(function () { put('echoUpdBoot', '0'); }, 25000); // the game ran for a while: it started fine

	navigator.serviceWorker.register('./echo-sw.js').catch(function () { /* the app still works with its own files */ });

	// ---- only on Wi-Fi (or a cable), never on mobile data
	function onWifi() {
		return new Promise(function (resolve) {
			try {
				if (cap.nativePromise) {
					cap.nativePromise('Network', 'getStatus').then(function (s) {
						resolve(!!s && s.connected && (s.connectionType === 'wifi' || s.connectionType === 'ethernet'));
					}, function () { resolve(fallback()); });
					return;
				}
			} catch (e) { /* use the browser's own information */ }
			resolve(fallback());
		});
		function fallback() {
			var c = navigator.connection;
			return !!(c && (c.type === 'wifi' || c.type === 'ethernet') && !c.saveData);
		}
	}

	function sha256(buffer) {
		return crypto.subtle.digest('SHA-256', buffer).then(function (d) {
			return Array.prototype.map.call(new Uint8Array(d), function (b) { return ('0' + b.toString(16)).slice(-2); }).join('');
		});
	}

	function localUrl(rel) {
		var u = new URL(location.origin + '/');
		u.pathname = '/' + rel;
		return u.href;
	}

	function remoteUrl(rel) {
		return SITE + rel.split('/').map(encodeURIComponent).join('/');
	}

	var running = false;

	function check() {
		if (running || !navigator.onLine) return Promise.resolve();
		running = true;
		var cache, remote, todo;
		return onWifi().then(function (ok) {
			if (!ok) throw 'no wifi';
			return caches.open(CACHE);
		}).then(function (c) {
			cache = c;
			return fetch(SITE + 'update.json?t=' + Date.now(), { cache: 'no-store' });
		}).then(function (r) {
			if (!r.ok) throw 'no list';
			return r.json();
		}).then(function (j) {
			remote = j;
			// what the app has now: the list it came with, plus the files that earlier updates replaced
			return Promise.all([
				fetch('./update.json').then(function (r) { return r.ok ? r.json() : { files: {} }; }, function () { return { files: {} }; }),
				cache.match(STATE).then(function (r) { return r ? r.json() : { files: {} }; })
			]);
		}).then(function (lists) {
			var have = Object.assign({}, lists[0].files, lists[1].files);
			todo = Object.keys(remote.files).filter(function (rel) {
				return !have[rel] || have[rel].h !== remote.files[rel].h;
			});
			if (todo.length === 0) return;
			var changed = {};
			var i = 0;
			function nextFile() {
				if (i >= todo.length) return Promise.resolve();
				var rel = todo[i++];
				var info = remote.files[rel];
				return fetch(remoteUrl(rel), { cache: 'no-store' }).then(function (r) {
					if (!r.ok) throw 'HTTP ' + r.status;
					var type = r.headers.get('content-type') || 'application/octet-stream';
					return r.arrayBuffer().then(function (buf) {
						return sha256(buf).then(function (hash) {
							if (hash !== info.h) throw 'wrong hash ' + rel;
							return cache.put(localUrl(rel), new Response(buf, { status: 200, headers: { 'content-type': type } }));
						});
					});
				}).then(function () {
					changed[rel] = info;
					return nextFile();
				});
			}
			return nextFile().then(function () {
				return cache.match(STATE).then(function (r) { return r ? r.json() : { files: {} }; });
			}).then(function (old) {
				var state = { version: remote.version, files: Object.assign({}, old.files, changed) };
				return cache.put(STATE, new Response(JSON.stringify(state), { headers: { 'content-type': 'application/json' } }));
			}).then(function () {
				toast('Update downloaded (' + todo.length + ' files). Close the game and open it again to use it.');
			});
		}).catch(function () { /* no Wi-Fi, offline or the site is down: try again later */
		}).then(function () { running = false; });
	}

	setTimeout(check, CHECK_AFTER_MS);
	setInterval(check, CHECK_EVERY_MS);
})();
