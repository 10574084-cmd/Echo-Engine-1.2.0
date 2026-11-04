// Bundles fengari (a Lua VM written in JS, MIT) for the browser without needing webpack:
//   node bundle.js <fengari repo dir> <sprintf-js dir> <out.js>
const fs = require('fs'), path = require('path');
const [repo, sprintfDir, out] = process.argv.slice(2);
const stubs = { fs: '{}', path: '{}', os: '{platform:function(){return "browser"}}', 'readline-sync': '{setDefaultOptions:function(){},prompt:function(){return ""}}', tmp: '{}', child_process: '{}' };
const modules = {}; // id -> source
function resolve(from, req) {
	if (req === 'sprintf-js') return path.join(sprintfDir, 'src/sprintf.js');
	let p = path.resolve(path.dirname(from), req);
	if (fs.existsSync(p + '.js')) return p + '.js';
	if (fs.existsSync(p) && fs.statSync(p).isFile()) return p;
	return path.join(p, 'index.js');
}
function add(file) {
	if (file in modules) return;
	let src = fs.readFileSync(file, 'utf8');
	const scan = src.replace(/^\s*\/\/.*$/gm, '');
	if (file.endsWith('luaconf.js')) src = src.replace('conf.LUA_COMPAT_FLOATSTRING || false', 'true'); // print 5, not 5.0, like LuaJIT (what Psych Engine scripts expect)
	src = src.split("'::'").join("':' + ':'").split('"::"').join('":" + ":"'); // Lime treats ::name:: in templates as variables
	modules[file] = null;
	const re = /require\(\s*['"]([^'"]+)['"]\s*\)/g;
	let m; const map = {};
	while ((m = re.exec(scan))) {
		const r = m[1];
		if (Object.prototype.hasOwnProperty.call(stubs, r)) { map[r] = 'stub:' + r; continue; }
		const f = resolve(file, r); map[r] = f; add(f);
	}
	modules[file] = { src, map };
}
const entry = path.join(repo, 'src/fengari.js');
add(entry);
let js = '(function(){\n"use strict";\nvar __td = new TextDecoder(); var __out = function(x){ return {write: function(b){ console.log(typeof b === "string" ? b : __td.decode(b)); }, fd: 1}; };\nvar process = {env: {}, platform: "browser", argv: [], versions: {node: "0"}, cwd: function(){ return "/"; }, uptime: function(){ return performance.now() / 1000; }, stdin: {fd: 0}, stdout: __out(), stderr: __out(), exit: function(){}}; // fengari reads the process object of node; webpack would provide a shim\nvar Buffer = {from: function(x){ return x; }};\nvar global = window;\nvar __defs = {};\nvar __cache = {};\nvar __stubs = {' +
	Object.keys(stubs).map(k => JSON.stringify('stub:' + k) + ':' + stubs[k]).join(',') + '};\n' +
	'function __req(id){ if (id in __stubs) return __stubs[id]; if (__cache[id]) return __cache[id].exports; var m = __cache[id] = {exports:{}}; __defs[id](m, m.exports, function(r){ return __req(__maps[id][r]); }); return m.exports; }\nvar __maps = {};\n';
for (const [file, mod] of Object.entries(modules)) {
	js += '__maps[' + JSON.stringify(file) + '] = ' + JSON.stringify(mod.map) + ';\n';
	js += '__defs[' + JSON.stringify(file) + '] = function(module, exports, require){\n' + mod.src + '\n};\n';
}
js += 'window.fengari = __req(' + JSON.stringify(entry) + ');\n})();\n';
fs.writeFileSync(out, js);
console.log('modules:', Object.keys(modules).length, 'size:', js.length);
