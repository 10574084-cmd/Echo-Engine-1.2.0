package llua;

/** Haxe values to Lua values and back (what linc_luajit's Convert does). */
class Convert
{
	public static function toLua(l:State, val:Dynamic):Bool
	{
		switch (Type.typeof(val))
		{
			case TNull:
				Lua.pushnil(l);
			case TBool:
				Lua.pushboolean(l, val);
			case TInt:
				Lua.pushinteger(l, val);
			case TFloat:
				Lua.pushnumber(l, val);
			case TClass(String):
				Lua.pushstring(l, val);
			case TClass(Array):
				arrayToLua(l, val);
			case TObject:
				objectToLua(l, val);
			case TClass(haxe.ds.StringMap):
				var map:Map<String, Dynamic> = val;
				Lua.newtable(l);
				for (k => v in map)
				{
					Lua.pushstring(l, k);
					toLua(l, v);
					Lua.rawset(l, -3);
				}
			default:
				Lua.pushnil(l);
				return false;
		}
		return true;
	}

	static function arrayToLua(l:State, arr:Array<Dynamic>):Void
	{
		Lua.newtable(l);
		for (i in 0...arr.length)
		{
			Lua.pushinteger(l, i + 1);
			toLua(l, arr[i]);
			Lua.rawset(l, -3);
		}
	}

	static function objectToLua(l:State, o:Dynamic):Void
	{
		Lua.newtable(l);
		for (field in Reflect.fields(o))
		{
			Lua.pushstring(l, field);
			toLua(l, Reflect.field(o, field));
			Lua.rawset(l, -3);
		}
	}

	public static function fromLua(l:State, v:Int):Dynamic
	{
		switch (Lua.type(l, v))
		{
			case Lua.LUA_TBOOLEAN:
				return Lua.toboolean(l, v);
			case Lua.LUA_TNUMBER:
				return Lua.tonumber(l, v);
			case Lua.LUA_TSTRING:
				return Lua.tostring(l, v);
			case Lua.LUA_TTABLE:
				return tableFromLua(l, v);
			default:
				return null; // nil, functions, userdata...
		}
	}

	static function tableFromLua(l:State, v:Int):Dynamic
	{
		if (v < 0) v = Lua.gettop(l) + v + 1; // the stack moves while we walk the table

		var entries:Array<{key:Dynamic, value:Dynamic}> = [];
		var onlyNumbers = true;
		Lua.pushnil(l);
		while (Lua.next(l, v) != 0)
		{
			var key:Dynamic = (Lua.type(l, -2) == Lua.LUA_TNUMBER) ? Lua.tonumber(l, -2) : Lua.tostring(l, -2);
			if (!(key is Float)) onlyNumbers = false;
			entries.push({key: key, value: fromLua(l, -1)});
			Lua.pop(l, 1);
		}

		if (onlyNumbers)
		{
			var arr:Array<Dynamic> = [];
			for (e in entries)
			{
				var idx = Std.int(e.key) - 1;
				if (idx >= 0) arr[idx] = e.value;
			}
			return arr;
		}

		var obj:Dynamic = {};
		for (e in entries) Reflect.setField(obj, Std.string(e.key), e.value);
		return obj;
	}
}
