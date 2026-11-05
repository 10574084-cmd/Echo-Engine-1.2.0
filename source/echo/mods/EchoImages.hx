package echo.mods;

#if html5
import haxe.io.Bytes;
import js.Browser;
import webfs.VirtualFS;

/**
 * Echo mods can ship their pictures as .webp (a lot smaller than .png). The game reads PNG files only, so right after an import the
 * browser converts every WebP picture of the mod into a real PNG (EchoModLoader stores them as ".png" files on purpose, so the
 * names the game looks for are already right). A file is a WebP when it starts with "RIFF....WEBP", whatever its name says.
 */
class EchoImages
{
	public static function isWebp(b:Bytes):Bool
		return b != null && b.length > 12 && b.getString(0, 4) == 'RIFF' && b.getString(8, 4) == 'WEBP';

	/** Converts the WebP pictures of these mods. done(converted, failed). */
	public static function convertMods(mods:Array<String>, done:Int->Int->Void):Void
	{
		var todo:Array<String> = [];
		for (mod in mods)
			for (path in VirtualFS.listFilesRecursive('mods/$mod'))
			{
				var low = path.toLowerCase();
				if (!StringTools.endsWith(low, '.png') && !StringTools.endsWith(low, '.webp')) continue;
				if (isWebp(VirtualFS.getBytes(path))) todo.push(path);
			}

		var converted = 0, failed = 0;
		var step:Void->Void = null;
		step = function()
		{
			if (todo.length == 0) { done(converted, failed); return; }
			var path = todo.shift();
			convert(path, function(ok:Bool)
			{
				if (ok) converted++; else failed++;
				step();
			});
		};
		step();
	}

	static function convert(path:String, done:Bool->Void):Void
	{
		var win:Dynamic = Browser.window;
		try
		{
			var bytes = VirtualFS.getBytes(path);
			var blob:Dynamic = js.Syntax.code("new Blob([{0}.b], {type: 'image/webp'})", bytes);
			win.createImageBitmap(blob).then(function(bitmap:Dynamic)
			{
				var canvas:Dynamic = Browser.document.createElement('canvas');
				canvas.width = bitmap.width;
				canvas.height = bitmap.height;
				var ctx:Dynamic = canvas.getContext('2d');
				ctx.drawImage(bitmap, 0, 0);
				if (bitmap.close != null) bitmap.close();
				canvas.toBlob(function(png:Dynamic)
				{
					if (png == null) { trace('Echo mods: "$path" could not be converted to PNG'); done(false); return; }
					png.arrayBuffer().then(function(buffer:Dynamic)
					{
						var out = Bytes.ofData(buffer);
						var target = StringTools.endsWith(path.toLowerCase(), '.webp') ? path.substr(0, path.length - 5) + '.png' : path;
						VirtualFS.saveBytes(target, out);
						if (target != path) VirtualFS.deleteFile(path);
						done(true);
					});
				}, 'image/png');
			}, function(error:Dynamic)
			{
				trace('Echo mods: "$path" is not a picture the browser can read ($error)');
				done(false);
			});
		}
		catch (e:Dynamic)
		{
			trace('Echo mods: "$path": $e');
			done(false);
		}
	}
}
#end
