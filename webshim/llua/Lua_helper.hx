package llua;

import llua.Fengari.ls;

/** Registers Haxe functions so Lua scripts can call them (see psychlua.CallbackHandler for what happens on a call). */
class Lua_helper
{
	public static var sendErrorsToLua:Bool = true;
	public static var callbacks:Map<String, Dynamic> = new Map();

	public static function add_callback(l:State, name:String, f:Dynamic):Bool
	{
		if (f != null) callbacks.set(name, f); // null = "a function of this script only", see FunkinLua.addLocalCallback
		Fengari.lua.lua_pushcfunction(l, function(state:Dynamic):Int return psychlua.CallbackHandler.call(state, name));
		Fengari.lua.lua_setglobal(l, ls(name));
		return true;
	}

	public static function remove_callback(l:State, name:String):Bool
	{
		callbacks.remove(name);
		Fengari.lua.lua_pushnil(l);
		Fengari.lua.lua_setglobal(l, ls(name));
		return true;
	}
}
