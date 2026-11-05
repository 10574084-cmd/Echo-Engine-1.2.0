package echo.mods;

/**
 * Reads the data files of an Echo mod. They can be written as plain JSON or as a small ".js" file that only holds one object:
 *
 *     export default { name: "Pico", scale: 1, anims: [ { name: 'idle', prefix: "Idle" }, ], };
 *     module.exports = { ... };     Echo.define({ ... });     const data = { ... };
 *
 * The object is READ, never run: it can have comments, keys without quotes, 'single quotes' and trailing commas, but no code
 * (no calls, no variables). That keeps mods from running anything just by being imported.
 */
class EchoData
{
	/** Parses a data file. fileName only decides the error message and whether ".json" is read strictly. Throws a String on a syntax error. */
	public static function parse(text:String, fileName:String = ''):Dynamic
	{
		if (text.charCodeAt(0) == 0xFEFF) text = text.substr(1);
		var p = new Reader(text);
		p.skipTrivia();
		p.skipWrapper();
		var value:Dynamic = p.readValue();
		p.skipTrivia();
		p.skipClosers();
		if (!p.atEnd()) throw p.error('unexpected "${p.peekChar()}" after the data');
		return value;
	}

	/** The same, but returns null and reports the problem instead of throwing. */
	public static function tryParse(text:String, fileName:String, warn:String->Void):Dynamic
	{
		try return parse(text, fileName)
		catch (e:Dynamic)
		{
			warn('$fileName: $e');
			return null;
		}
	}
}

private class Reader
{
	var s:String;
	var i:Int = 0;
	var wrapped:Int = 0; // "(" opened by Echo.define( ... )

	public function new(text:String)
	{
		s = text;
	}

	public function atEnd():Bool return i >= s.length;
	public function peekChar():String return i < s.length ? s.charAt(i) : '';

	public function error(message:String):String
	{
		var line = 1;
		for (k in 0...Std.int(Math.min(i, s.length))) if (s.charCodeAt(k) == 10) line++;
		return 'line $line: $message';
	}

	public function skipTrivia():Void
	{
		while (i < s.length)
		{
			var c = s.charCodeAt(i);
			if (c == 32 || c == 9 || c == 10 || c == 13) i++;
			else if (c == '/'.code && s.charCodeAt(i + 1) == '/'.code)
			{
				while (i < s.length && s.charCodeAt(i) != 10) i++;
			}
			else if (c == '/'.code && s.charCodeAt(i + 1) == '*'.code)
			{
				var end = s.indexOf('*/', i + 2);
				i = end < 0 ? s.length : end + 2;
			}
			else break;
		}
	}

	/** "export default", "module.exports =", "const x =", "Echo.define(" ... in front of the object. */
	public function skipWrapper():Void
	{
		var first = peekChar();
		if (first == '{' || first == '[' || first == '"' || first == "'" || first == '-' || (first >= '0' && first <= '9'))
			return; // plain data, nothing in front of it
		while (i < s.length && s.charAt(i) != '{' && s.charAt(i) != '[')
		{
			if (s.charAt(i) == '(') wrapped++;
			i++;
			skipTrivia();
		}
	}

	public function skipClosers():Void
	{
		while (i < s.length)
		{
			var c = s.charAt(i);
			if (c == ')' || c == ';' || c == ',' || c == ' ' || c == '\n' || c == '\r' || c == '\t') i++;
			else if (c == '/') skipTrivia();
			else break;
		}
	}

	public function readValue():Dynamic
	{
		skipTrivia();
		if (i >= s.length) throw error('the data ends too soon');
		var c = s.charAt(i);
		if (c == '{') return readObject();
		if (c == '[') return readArray();
		if (c == '"' || c == "'") return readString();
		if (c == '-' || c == '+' || c == '.' || (c >= '0' && c <= '9')) return readNumber();
		var word = readWord();
		return switch (word)
		{
			case 'true': true;
			case 'false': false;
			case 'null' | 'undefined': null;
			case 'NaN': 0;
			case 'Infinity': 1e30;
			default: throw error('"$word" is not data (only numbers, text, true/false/null, lists and objects are allowed)');
		}
	}

	function readObject():Dynamic
	{
		var obj:Dynamic = {};
		i++; // {
		while (true)
		{
			skipTrivia();
			if (i >= s.length) throw error('missing "}"');
			if (s.charAt(i) == '}') { i++; break; }
			if (s.charAt(i) == ',') { i++; continue; }

			var key:String = (s.charAt(i) == '"' || s.charAt(i) == "'") ? readString() : readWord();
			if (key == '') throw error('a name was expected, found "${peekChar()}"');
			skipTrivia();
			if (s.charAt(i) != ':') throw error('":" was expected after "$key"');
			i++;
			Reflect.setField(obj, key, readValue());
		}
		return obj;
	}

	function readArray():Array<Dynamic>
	{
		var list:Array<Dynamic> = [];
		i++; // [
		while (true)
		{
			skipTrivia();
			if (i >= s.length) throw error('missing "]"');
			if (s.charAt(i) == ']') { i++; break; }
			if (s.charAt(i) == ',') { i++; continue; }
			list.push(readValue());
		}
		return list;
	}

	function readString():String
	{
		var quote = s.charAt(i);
		i++;
		var out = new StringBuf();
		while (true)
		{
			if (i >= s.length) throw error('a text is not closed');
			var c = s.charAt(i);
			if (c == quote) { i++; break; }
			if (c == '\\')
			{
				i++;
				var e = s.charAt(i);
				switch (e)
				{
					case 'n': out.add('\n');
					case 't': out.add('\t');
					case 'r': out.add('\r');
					case 'b': out.add('\x08');
					case 'f': out.add('\x0C');
					case 'u':
						var hex = s.substr(i + 1, 4);
						var code = Std.parseInt('0x' + hex);
						if (code == null) throw error('bad \\u escape');
						out.addChar(code);
						i += 4;
					case '\n': // line continuation
					default: out.add(e);
				}
				i++;
			}
			else { out.add(c); i++; }
		}
		return out.toString();
	}

	function readNumber():Dynamic
	{
		var start = i;
		if (s.charAt(i) == '-' || s.charAt(i) == '+') i++;
		if (s.charAt(i) == '0' && (s.charAt(i + 1) == 'x' || s.charAt(i + 1) == 'X'))
		{
			i += 2;
			while (i < s.length && ~/^[0-9a-fA-F]$/.match(s.charAt(i))) i++;
		}
		else
		{
			while (i < s.length && ~/^[0-9.eE+\-]$/.match(s.charAt(i)))
			{
				// a sign only belongs to the number right after an exponent
				var ch = s.charAt(i);
				if ((ch == '+' || ch == '-') && !(s.charAt(i - 1) == 'e' || s.charAt(i - 1) == 'E')) break;
				i++;
			}
		}
		var text = s.substring(start, i);
		if (StringTools.startsWith(text, '+')) text = text.substr(1);
		var f = Std.parseFloat(text);
		if (Math.isNaN(f) && !StringTools.startsWith(text, '0x') && !StringTools.startsWith(text, '-0x')) throw error('"$text" is not a number');
		if (StringTools.startsWith(text, '0x') || StringTools.startsWith(text, '-0x'))
		{
			var neg = StringTools.startsWith(text, '-');
			var n = Std.parseInt(neg ? text.substr(1) : text);
			return neg ? -n : n;
		}
		if (f == Math.floor(f) && Math.abs(f) < 2147483647)
		{
			var whole:Dynamic = Std.int(f);
			return whole;
		}
		return f;
	}

	function readWord():String
	{
		var start = i;
		while (i < s.length && ~/^[A-Za-z0-9_$\-]$/.match(s.charAt(i))) i++;
		return s.substring(start, i);
	}
}
