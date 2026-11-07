import echo.mods.EchoData;
import echo.mods.EchoModLoader;
import haxe.io.Bytes;
import sys.FileSystem;
import sys.io.File;

/** ECHO_IN=<echo mod folder> ECHO_OUT=<output folder> haxe -cp <copy of source/echo/mods under echo/mods> -cp tools/test --main EchoModTest --interp
 *  Reads a mod folder, runs the Echo Mods loader on it and writes the result, so the output can be checked without the game. */
class EchoModTest
{
	static function walk(root:String, rel:String, out:Map<String, Bytes>):Void
	{
		var dir = rel == '' ? root : root + '/' + rel;
		for (name in FileSystem.readDirectory(dir))
		{
			var r = rel == '' ? name : rel + '/' + name;
			if (FileSystem.isDirectory(root + '/' + r)) walk(root, r, out);
			else out.set(r, File.getBytes(root + '/' + r));
		}
	}

	static function selfTest():Void
	{
		var a:Dynamic = EchoData.parse("// c\nexport default { a: 1, 'b': [1, 2, ], c: \"x\\ny\", d: { e: true, f: null }, g: -0.5, h: 0x10, };");
		if (a.a != 1 || a.b.length != 2 || a.c != "x\ny" || a.d.e != true || a.d.f != null || a.g != -0.5 || a.h != 16) throw 'parse 1 failed: ' + haxe.Json.stringify(a);
		var b:Dynamic = EchoData.parse("module.exports = {x: 2};");
		if (b.x != 2) throw 'parse 2 failed';
		var c:Dynamic = EchoData.parse("Echo.define({ n: 'a/*b*/c', /* hi */ m: [] });");
		if (c.n != 'a/*b*/c') throw 'parse 3 failed';
		var d:Dynamic = EchoData.parse("{\"j\": [1,2,{\"k\":3e2}]}");
		if (d.j[2].k != 300) throw 'parse 4 failed';
		var bad = false;
		try EchoData.parse("export default { a: alert(1) };") catch (e:Dynamic) bad = true;
		if (!bad) throw 'code must not be accepted';
		Sys.println('data parser: ok');
	}

	/** Echo chart -> chart of the engine -> Echo chart (what the chart editor saves) must give the same notes. */
	static function roundTrip(files:Map<String, Bytes>):Void
	{
		var checked = 0, bad = 0;
		for (k in files.keys())
		{
			var m = ~/^charts\/([^\/]+)\/([^\/]+)\.js(on)?$/;
			if (!m.match(k)) continue;
			var song = m.matched(1), diff = m.matched(2);
			var orig:Dynamic = EchoData.parse(files.get(k).toString());
			var psychPath = diff.toLowerCase() == 'normal' ? 'data/$song/$song.json' : 'data/$song/$song-' + diff.toLowerCase() + '.json';
			if (!files.exists(psychPath)) continue;
			var j:Dynamic = haxe.Json.parse(files.get(psychPath).toString());
			var psych:Dynamic = Std.isOfType(j.song, String) ? j : j.song;
			var back:Dynamic = echo.mods.EchoChart.fromSong(psych);
			var key = function(n:Dynamic) return Math.round(n.t) + ':' + n.lane + ':' + Math.round(n.len == null ? 0 : n.len);
			var a = [for (n in (orig.notes : Array<Dynamic>)) key(n)];
			var b = [for (n in (back.notes : Array<Dynamic>)) key(n)];
			a.sort(Reflect.compare); b.sort(Reflect.compare);
			checked++;
			if (a.join(',') != b.join(',')) { bad++; Sys.println('  ROUND TRIP DIFFERS: $song / $diff (${a.length} vs ${b.length} notes)'); }
		}
		Sys.println('chart round trip: $checked charts, $bad different');
	}

	static function main():Void
	{
		selfTest();
		var args = [Sys.getEnv('ECHO_IN'), Sys.getEnv('ECHO_OUT')];
		if (args[0] == null || args[1] == null) return;
		var files:Map<String, Bytes> = new Map();
		walk(args[0], '', files);
		var before = [for (k in files.keys()) k];
		var report = EchoModLoader.process(files);
		Sys.println('converted: ' + report.converted.length);
		for (c in report.converted) Sys.println('  ' + c);
		Sys.println('warnings: ' + report.warnings.length);
		for (w in report.warnings) Sys.println('  ! ' + w);
		roundTrip(files);
		for (k in files.keys())
		{
			if (before.indexOf(k) >= 0 && !StringTools.endsWith(k, '.json')) continue;
			var path = args[1] + '/' + k;
			FileSystem.createDirectory(haxe.io.Path.directory(path) == '' ? '.' : haxe.io.Path.directory(path));
			File.saveBytes(path, files.get(k));
		}
	}
}
