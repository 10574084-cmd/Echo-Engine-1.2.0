// Echo Engine for PC: the same game that runs on the web, inside a window.
// The game files (folder "www") are served through a private address (app://echo/) so the game sees a normal, secure web page:
// its saves live in the app's own storage and nothing from the internet is needed to start it.
const { app, BrowserWindow, Menu, protocol, net, shell, dialog } = require('electron');
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const { pathToFileURL } = require('url');

const ROOT = path.join(__dirname, 'www');

// ---- Automatic updates -----------------------------------------------------------------------------------------------------
// The game's web page is always the newest version. When the app starts (and every few hours) it downloads the page's list of files
// (update.json) and fetches only the files that changed, into the app's own storage. The next time the app opens it uses those
// files instead of the ones it came with. Nothing is installed and the player's saves are not touched.
const UPDATE_URL = 'https://10574084-cmd.github.io/Echo-Engine-1.2.0/';
const CHECK_EVERY_MS = 6 * 60 * 60 * 1000;
let updateDir = null;   // <app data>/update
let updateFiles = {};   // path -> {h, s}: files that are served from updateDir instead of the bundled ones
let updating = false;

function readJson(file) { try { return JSON.parse(fs.readFileSync(file, 'utf8')); } catch (e) { return null; } }

function loadUpdateState() {
	updateDir = path.join(app.getPath('userData'), 'update');
	const state = readJson(path.join(updateDir, 'state.json'));
	updateFiles = {};
	if (!state || !state.files) return;
	// only trust files that are still there with the right size (a half-written download is ignored)
	for (const [rel, info] of Object.entries(state.files)) {
		try { if (fs.statSync(path.join(updateDir, 'files', rel)).size === info.s) updateFiles[rel] = info; } catch (e) { /* missing: use the bundled file */ }
	}
}

function sha256(file) {
	return new Promise((resolve, reject) => {
		const hash = crypto.createHash('sha256');
		fs.createReadStream(file).on('data', (d) => hash.update(d)).on('end', () => resolve(hash.digest('hex'))).on('error', reject);
	});
}

async function checkForUpdate(win) {
	if (updating || process.env.ECHO_SMOKETEST || !net.isOnline()) return;
	updating = true;
	try {
		const res = await net.fetch(UPDATE_URL + 'update.json?t=' + Date.now(), { cache: 'no-store' });
		if (!res.ok) return;
		const remote = await res.json();
		if (!remote || !remote.files) return;

		// what the app has now: the bundled list, plus whatever an earlier update replaced
		const bundled = readJson(path.join(ROOT, 'update.json'));
		const have = Object.assign({}, bundled ? bundled.files : {}, updateFiles);
		const todo = Object.keys(remote.files).filter((rel) => !have[rel] || have[rel].h !== remote.files[rel].h);
		if (todo.length === 0) return;

		const filesDir = path.join(updateDir, 'files');
		let done = 0;
		const next = {};
		for (const rel of todo) {
			if (rel.includes('..') || path.isAbsolute(rel)) continue; // never write outside the update folder
			const info = remote.files[rel];
			const target = path.join(filesDir, rel);
			const part = target + '.part';
			fs.mkdirSync(path.dirname(target), { recursive: true });
			const r = await net.fetch(UPDATE_URL + rel.split('/').map(encodeURIComponent).join('/'), { cache: 'no-store' });
			if (!r.ok) throw new Error('HTTP ' + r.status + ' for ' + rel);
			fs.writeFileSync(part, Buffer.from(await r.arrayBuffer()));
			if ((await sha256(part)) !== info.h) { fs.unlinkSync(part); throw new Error('wrong hash for ' + rel); }
			fs.renameSync(part, target);
			next[rel] = info;
			done++;
		}

		// the new state replaces the old one in a single step, so an interrupted update leaves the previous one working
		const merged = Object.assign({}, updateFiles, next);
		fs.writeFileSync(path.join(updateDir, 'state.json.tmp'), JSON.stringify({ version: remote.version, files: merged }));
		fs.renameSync(path.join(updateDir, 'state.json.tmp'), path.join(updateDir, 'state.json'));

		if (done > 0 && win && !win.isDestroyed()) {
			const answer = await dialog.showMessageBox(win, {
				type: 'info', buttons: ['Restart now', 'Later'], defaultId: 0, cancelId: 1,
				title: 'Echo Engine', message: 'An update is ready (' + done + ' files, version ' + remote.version + ').',
				detail: 'Restart the game to use it. Your saves are kept.'
			});
			if (answer.response === 0) { app.relaunch(); app.exit(0); }
		}
	} catch (e) {
		console.error('Update check failed:', e && e.message ? e.message : e); // offline or the site is down: try again later
	} finally {
		updating = false;
	}
}

protocol.registerSchemesAsPrivileged([
	{ scheme: 'app', privileges: { standard: true, secure: true, supportFetchAPI: true, stream: true, corsEnabled: true } }
]);

function createWindow() {
	const win = new BrowserWindow({
		width: 1280,
		height: 720,
		minWidth: 640,
		minHeight: 360,
		backgroundColor: '#000000',
		autoHideMenuBar: true,
		title: 'Echo Engine',
		webPreferences: {
			contextIsolation: true,
			sandbox: true,
			nodeIntegration: false,
			autoplayPolicy: 'no-user-gesture-required',
			backgroundThrottling: false
		}
	});
	Menu.setApplicationMenu(null);

	// F11 = full screen, as in most games
	win.webContents.on('before-input-event', (event, input) => {
		if (input.type === 'keyDown' && input.key === 'F11') {
			win.setFullScreen(!win.isFullScreen());
			event.preventDefault();
		}
	});

	// the game never opens other windows or leaves its own address (links go to the normal browser)
	win.webContents.setWindowOpenHandler(({ url }) => {
		if (/^https:\/\//.test(url)) shell.openExternal(url);
		return { action: 'deny' };
	});
	win.webContents.on('will-navigate', (event, url) => {
		if (!url.startsWith('app://echo/')) event.preventDefault();
	});

	win.loadURL('app://echo/index.html');

	// look for a newer version a little after the game started (not while it is loading), then every few hours
	if (!process.env.ECHO_SMOKETEST) {
		setTimeout(() => checkForUpdate(win), 20000);
		setInterval(() => checkForUpdate(win), CHECK_EVERY_MS);
	}

	// used by the build machine to check that the packaged app really starts (never set for players)
	if (process.env.ECHO_SMOKETEST) {
		win.webContents.on('did-fail-load', (e, code, desc) => { console.error('LOAD FAILED', code, desc); app.exit(1); });
		setTimeout(async () => {
			try {
				const ok = await win.webContents.executeJavaScript("!!document.querySelector('canvas')");
				console.log('game canvas present:', ok);
				app.exit(ok ? 0 : 2);
			} catch (e) { console.error(e); app.exit(3); }
		}, 30000);
	}
}

app.whenReady().then(() => {
	loadUpdateState();
	protocol.handle('app', (request) => {
		const url = new URL(request.url);
		let rel = decodeURIComponent(url.pathname);
		if (rel === '/' || rel === '') rel = '/index.html';
		const file = path.normalize(path.join(ROOT, rel));
		// never serve anything outside the game folder
		if (file !== ROOT && !file.startsWith(ROOT + path.sep)) return new Response('Forbidden', { status: 403 });
		// a file that an update replaced comes from the update folder
		const relKey = rel.replace(/^\//, '');
		if (updateFiles[relKey]) return net.fetch(pathToFileURL(path.join(updateDir, 'files', relKey)).toString());
		return net.fetch(pathToFileURL(file).toString());
	});
	createWindow();
	app.on('activate', () => {
		if (BrowserWindow.getAllWindows().length === 0) createWindow();
	});
});

app.on('window-all-closed', () => app.quit());
