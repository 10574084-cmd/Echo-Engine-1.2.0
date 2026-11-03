package llua;

import llua.Fengari.ls;

/** The part of linc_luajit's `Lua` class that Psych Engine uses, for fengari. */
class Lua
{
	public static inline var LUA_GLOBALSINDEX:Int = -10002;
	public static inline var LUA_TNONE:Int = -1;
	public static inline var LUA_TNIL:Int = 0;
	public static inline var LUA_TBOOLEAN:Int = 1;
	public static inline var LUA_TLIGHTUSERDATA:Int = 2;
	public static inline var LUA_TNUMBER:Int = 3;
	public static inline var LUA_TSTRING:Int = 4;
	public static inline var LUA_TTABLE:Int = 5;
	public static inline var LUA_TFUNCTION:Int = 6;
	public static inline var LUA_TUSERDATA:Int = 7;
	public static inline var LUA_TTHREAD:Int = 8;

	public static inline var LUA_OK:Int = 0;
	public static inline var LUA_YIELD:Int = 1;
	public static inline var LUA_ERRRUN:Int = 2;
	public static inline var LUA_ERRSYNTAX:Int = 3;
	public static inline var LUA_ERRMEM:Int = 4;
	public static inline var LUA_ERRERR:Int = 6;

	public static inline function version():String return "Lua 5.3 (fengari)";
	public static inline function versionJIT():String return "fengari";

	public static function set_callbacks_function(f:Dynamic):Void {}

	public static inline function gettop(l:State):Int return Fengari.lua.lua_gettop(l);
	public static inline function settop(l:State, n:Int):Void Fengari.lua.lua_settop(l, n);
	public static inline function pop(l:State, n:Int):Void Fengari.lua.lua_settop(l, -n - 1);
	public static inline function type(l:State, idx:Int):Int return Fengari.lua.lua_type(l, idx);

	public static inline function pushnil(l:State):Void Fengari.lua.lua_pushnil(l);
	public static inline function pushboolean(l:State, b:Bool):Void Fengari.lua.lua_pushboolean(l, b);
	public static inline function pushstring(l:State, s:String):Void Fengari.lua.lua_pushstring(l, ls(s));
	public static inline function pushinteger(l:State, n:Int):Void Fengari.lua.lua_pushinteger(l, n);

	/** Whole numbers are pushed as Lua integers (LuaJIT only has doubles and prints 5, not 5.0). */
	public static function pushnumber(l:State, n:Float):Void
	{
		if (Math.isFinite(n) && Math.floor(n) == n && Math.abs(n) < 2147483647.0)
			Fengari.lua.lua_pushinteger(l, Std.int(n));
		else
			Fengari.lua.lua_pushnumber(l, n);
	}

	public static function pushvalue(l:State, idx:Int):Void
	{
		if (idx == LUA_GLOBALSINDEX) Fengari.lua.lua_pushglobaltable(l);
		else Fengari.lua.lua_pushvalue(l, idx);
	}

	public static inline function newtable(l:State):Void Fengari.lua.lua_createtable(l, 0, 0);
	public static inline function rawset(l:State, idx:Int):Void Fengari.lua.lua_rawset(l, idx);
	public static inline function rawget(l:State, idx:Int):Void Fengari.lua.lua_rawget(l, idx);
	public static inline function next(l:State, idx:Int):Int return Fengari.lua.lua_next(l, idx) ? 1 : 0;

	public static inline function getglobal(l:State, name:String):Int return Fengari.lua.lua_getglobal(l, ls(name));
	public static inline function setglobal(l:State, name:String):Void Fengari.lua.lua_setglobal(l, ls(name));

	public static function tostring(l:State, idx:Int):String
	{
		var s:Dynamic = Fengari.lua.lua_tojsstring(l, idx);
		return s == null ? "" : s;
	}

	public static inline function tonumber(l:State, idx:Int):Float return Fengari.lua.lua_tonumber(l, idx);
	public static inline function toboolean(l:State, idx:Int):Bool return Fengari.lua.lua_toboolean(l, idx);
	public static inline function isstring(l:State, idx:Int):Bool return Fengari.lua.lua_type(l, idx) == LUA_TSTRING;
	public static inline function isnumber(l:State, idx:Int):Bool return Fengari.lua.lua_type(l, idx) == LUA_TNUMBER;
	public static inline function isboolean(l:State, idx:Int):Bool return Fengari.lua.lua_type(l, idx) == LUA_TBOOLEAN;

	public static inline function pcall(l:State, nargs:Int, nresults:Int, errfunc:Int):Int
		return Fengari.lua.lua_pcall(l, nargs, nresults, errfunc);

	public static inline function close(l:State):Void Fengari.lua.lua_close(l);
}
