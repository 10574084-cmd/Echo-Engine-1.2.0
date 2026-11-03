package llua;

/**
 * Lua for the web. The desktop engine uses LuaJIT through linc_luajit (native code); the browser cannot run that, so the `llua` package of
 * the web build re-implements the same small API on top of fengari, a Lua virtual machine written in JavaScript (webshim/html5/fengari.js).
 * FunkinLua, CallbackHandler and every other script file of Psych Engine stay exactly as they are.
 */
class Fengari
{
	public static var f(get, never):Dynamic;
	public static var lua(get, never):Dynamic;
	public static var lauxlib(get, never):Dynamic;
	public static var lualib(get, never):Dynamic;

	static var _f:Dynamic = null;

	static function get_f():Dynamic
	{
		if (_f == null) _f = js.Syntax.code("window.fengari");
		if (_f == null) throw "The Lua interpreter (fengari.js) did not load";
		return _f;
	}

	static inline function get_lua():Dynamic return get_f().lua;
	static inline function get_lauxlib():Dynamic return get_f().lauxlib;
	static inline function get_lualib():Dynamic return get_f().lualib;

	/** A JS string as a Lua string (UTF-8 bytes). */
	public static inline function ls(s:String):Dynamic
		return get_f().to_luastring(s == null ? "" : s);

	/** Lua 5.3 (fengari) vs LuaJIT (5.1): the old names and libraries that Psych Engine scripts still use. */
	public static final COMPAT:String = '
unpack = unpack or table.unpack
loadstring = loadstring or load
math.pow = math.pow or function(a, b) return a ^ b end
math.mod = math.mod or math.fmod
math.atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
math.log10 = math.log10 or function(x) return math.log(x, 10) end
math.cosh = math.cosh or function(x) return (math.exp(x) + math.exp(-x)) / 2 end
math.sinh = math.sinh or function(x) return (math.exp(x) - math.exp(-x)) / 2 end
math.tanh = math.tanh or function(x) local a, b = math.exp(x), math.exp(-x) return (a - b) / (a + b) end
table.getn = table.getn or function(t) return #t end
table.maxn = table.maxn or function(t) local n = 0 for k in pairs(t) do if type(k) == "number" and k > n then n = k end end return n end
string.gfind = string.gfind or string.gmatch
if not setfenv then
	function setfenv(f, env) return f end
	function getfenv() return _G end
end
if not bit then
	bit = {
		band = function(a, b) return (a & b) end,
		bor = function(a, b) return (a | b) end,
		bxor = function(a, b) return (a ~ b) end,
		bnot = function(a) return ~a end,
		lshift = function(a, n) return (a << n) end,
		rshift = function(a, n) return (a >> n) end,
		arshift = function(a, n) return a // (2 ^ n) end,
		tobit = function(a) return a end,
	}
end
';
}
