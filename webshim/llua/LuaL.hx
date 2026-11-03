package llua;

import llua.Fengari.ls;

class LuaL
{
	public static function newstate():State
	{
		var l = Fengari.lauxlib.luaL_newstate();
		Fengari.lualib.luaL_openlibs(l);
		Fengari.lauxlib.luaL_dostring(l, ls(Fengari.COMPAT));
		return l;
	}

	public static inline function openlibs(l:State):Void {} // newstate already did it

	public static function dostring(l:State, s:String):Int
		return Fengari.lauxlib.luaL_dostring(l, ls(s));

	/** Runs a script file (from the virtual file system of the web build). */
	public static function dofile(l:State, path:String):Int
	{
		var code:String;
		try
		{
			code = sys.io.File.getContent(path);
		}
		catch (e:Dynamic)
		{
			Fengari.lua.lua_pushstring(l, ls('cannot open $path'));
			return Lua.LUA_ERRSYNTAX;
		}

		var bytes = ls(code);
		var status:Int = Fengari.lauxlib.luaL_loadbuffer(l, bytes, bytes.length, ls('@' + path));
		if (status != Lua.LUA_OK) return status;
		return Fengari.lua.lua_pcall(l, 0, -1, 0); // LUA_MULTRET
	}

	public static function error(l:State, message:String):Int
	{
		Fengari.lua.lua_pushstring(l, ls(message));
		return Fengari.lua.lua_error(l);
	}
}
