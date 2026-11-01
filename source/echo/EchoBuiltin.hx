package echo;

#if html5
import haxe.Json;
import haxe.io.Bytes;
import js.Browser;
import webfs.ModImporter;
import webfs.VirtualFS;

typedef BuiltinFile = {var p:String; var s:Int;}
typedef BuiltinMod = {var name:String; var files:Array<BuiltinFile>;}
#end

/**
 * Mods that come with the game (they are published next to it, in the "builtin" folder of the site) and that the player installs
 * with one button instead of downloading a .zip. Today: Pico Mix (the Pico mixes of the base game).
 * The files are downloaded one by one (a few at the same time), kept in memory until all of them arrived and then installed
 * like an imported mod, so a failed download never leaves a half installed mod.
 */
class EchoBuiltin
{
	public static inline var PICO = 'Pico Mix';

	/** A song of the Pico mixes has this in its name, e.g. "Bopeebo (Pico Mix)". */
	public static function isPicoSong(name:String):Bool
		return name != null && name.toLowerCase().indexOf('(pico mix)') >= 0;

	#if html5
	public static var busy(default, null):Bool = false;
	/** What the install is doing right now (for the menu). */
	public static var status(default, null):String = '';

	static var index:Array<BuiltinMod> = null;

	public static function installed(mod:String):Bool
		return VirtualFS.exists('mods/$mod/pack.json');

	static function url(path:String):String
		return js.Syntax.code("encodeURI({0})", path);

	/** Downloads and installs a built-in mod. done(ok, message). */
	public static function install(mod:String, done:Bool->String->Void):Void
	{
		if (busy) return;
		busy = true;
		status = 'Looking for $mod...';
		var fail = function(why:String)
		{
			busy = false;
			status = why;
			done(false, why);
		};

		var win:Dynamic = Browser.window;
		var fetchJson:Dynamic = win.fetch('builtin/index.json', {cache: 'no-cache'});
		fetchJson.then(function(r:Dynamic)
		{
			if (!r.ok) { fail('This copy of the game does not include $mod.'); return null; }
			return r.text();
		}).then(function(text:String)
		{
			if (text == null) return;
			var list:Array<BuiltinMod> = null;
			try list = Json.parse(text) catch (e:Dynamic) {}
			var info:BuiltinMod = null;
			if (list != null) for (m in list) if (m.name == mod) info = m;
			if (info == null || info.files == null || info.files.length == 0) { fail('This copy of the game does not include $mod.'); return; }
			download(info, done, fail);
		}, function(_) fail('Could not reach the game files (are you online?).'));
	}

	static function download(info:BuiltinMod, done:Bool->String->Void, fail:String->Void):Void
	{
		var total = info.files.length;
		var totalBytes = 0;
		for (f in info.files) totalBytes += f.s;
		var files:Map<String, Bytes> = new Map();
		var next = 0;
		var finished = 0;
		var bytes = 0;
		var failed = false;

		var startOne:Void->Void = null;
		startOne = function()
		{
			if (failed) return;
			if (next >= total)
			{
				if (finished >= total && files != null)
				{
					status = 'Installing ${info.name}... (the game may freeze a few seconds)';
					Browser.window.setTimeout(function()
					{
						ModImporter.installFiles(info.name, files, function(r)
						{
							files = null;
							busy = false;
							status = '${info.name} installed.';
							done(true, status);
						});
					}, 80);
				}
				return;
			}
			var file = info.files[next++];
			var win:Dynamic = Browser.window;
			var request:Dynamic = win.fetch(url('builtin/' + info.name + '/' + file.p));
			request.then(function(r:Dynamic)
			{
				if (!r.ok) throw 'HTTP ' + r.status;
				return r.arrayBuffer();
			}).then(function(buffer:Dynamic)
			{
				files.set(file.p, Bytes.ofData(buffer));
				finished++;
				bytes += file.s;
				status = 'Downloading ${info.name}: ' + Std.int(bytes / 1048576) + ' / ' + Std.int(totalBytes / 1048576) + ' MB';
				startOne();
			}, function(e:Dynamic)
			{
				if (failed) return;
				failed = true;
				fail('Download failed (' + file.p + '). Check your connection and try again.');
			});
		};
		for (_ in 0...6) startOne();
	}
	#else
	public static var busy(default, null):Bool = false;
	public static var status(default, null):String = '';

	public static function installed(mod:String):Bool
		return sys.FileSystem.exists('mods/$mod');

	public static function install(mod:String, done:Bool->String->Void):Void
		done(false, 'Put the "$mod" folder inside the game\'s mods folder.');
	#end
}
