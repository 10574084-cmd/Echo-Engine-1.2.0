package echo.mods;

import flixel.FlxSprite;
import flixel.addons.display.FlxRuntimeShader;
import flixel.math.FlxAngle;
import haxe.Json;
#if sys
import sys.io.File;
import sys.FileSystem;
#end

/**
 * Native visual filters for the sprites of a stage (what the Pico Mix stage scripts do with initLuaShader / setSpriteShader /
 * setShaderFloat). They read the shader from the mod ("shaders/<name>.frag") and set its values from plain data, so a stage file only
 * says  { "target": "bf", "shader": "adjustColor", "hue": 12, "contrast": 7 }  and no script is needed.
 */
class EchoFx
{
	static var sources:Map<String, Array<String>> = [];

	/** The frag/vert text of a shader of the mods (null if it is not there or the player turned shaders off). */
	public static function source(name:String):Array<String>
	{
		if (!ClientPrefs.data.shaders) return null;
		if (sources.exists(name)) return sources.get(name);
		var found:Array<String> = null;
		#if (MODS_ALLOWED && !flash && (sys || html5))
		var folders:Array<String> = [Paths.mods('shaders/')];
		if (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
			folders.insert(0, Paths.mods(Mods.currentModDirectory + '/shaders/'));
		for (mod in Mods.getGlobalMods()) folders.insert(0, Paths.mods(mod + '/shaders/'));
		for (folder in folders)
		{
			var frag = folder + name + '.frag';
			var vert = folder + name + '.vert';
			var f:String = FileSystem.exists(frag) ? File.getContent(frag) : null;
			var v:String = FileSystem.exists(vert) ? File.getContent(vert) : null;
			if (f != null || v != null) { found = [f, v]; break; }
		}
		#end
		sources.set(name, found);
		return found;
	}

	public static function clearCache():Void
		sources = [];

	/** Applies a filter to a sprite. `spec` has "shader" and any number of values (numbers, bools, [r,g,b] lists, in 0-255 for colors). */
	public static function apply(sprite:FlxSprite, spec:Dynamic):Bool
	{
		#if (!flash && (sys || html5))
		if (sprite == null || spec == null) return false;
		var name:String = Reflect.field(spec, 'shader');
		var src = source(name);
		if (src == null) return false;
		var shader:FlxRuntimeShader = null;
		try shader = new FlxRuntimeShader(src[0], src[1]) catch (e:Dynamic) { trace('Echo filter "$name" could not be built: $e'); return false; }

		for (key in Reflect.fields(spec))
		{
			if (key == 'shader' || key == 'target' || key == 'mask') continue;
			var v:Dynamic = Reflect.field(spec, key);
			try
			{
				if (key == 'ang' && Reflect.field(spec, 'angDeg') != null) continue;
				if (Std.isOfType(v, Bool)) shader.setBool(key, v);
				else if (Std.isOfType(v, Float) || Std.isOfType(v, Int)) shader.setFloat(key, v);
				else if (Std.isOfType(v, Array))
				{
					var a:Array<Float> = [for (x in (v : Array<Dynamic>)) cast x];
					// colors are written 0-255 in the stage file
					if (key.toLowerCase().indexOf('color') >= 0) a = [for (x in a) x > 1 ? x / 255 : x];
					shader.setFloatArray(key, a);
				}
			}
			catch (e:Dynamic) trace('Echo filter "$name": value "$key" was refused ($e)');
		}
		if (Reflect.field(spec, 'angDeg') != null) shader.setFloat('ang', Reflect.field(spec, 'angDeg') * FlxAngle.TO_RAD);

		sprite.shader = shader;
		if (Reflect.field(spec, 'frameInfo') != false && src[0] != null && src[0].indexOf('uFrameBounds') >= 0)
		{
			// shaders that need to know which part of the atlas is on screen
			var update = function()
			{
				if (sprite.shader != shader || sprite.frame == null) return;
				shader.setFloatArray('uFrameBounds', [sprite.frame.uv.x, sprite.frame.uv.y, sprite.frame.uv.width, sprite.frame.uv.height]);
				if (src[0].indexOf('angOffset') >= 0) shader.setFloat('angOffset', sprite.frame.angle * FlxAngle.TO_RAD);
			};
			sprite.animation.callback = function(_, _, _) update();
			update();
		}

		if (Reflect.field(spec, 'mask') == true)
		{
			// the picture "masks/<image>_mask" next to the character's atlas lights the edge (drop shadow)
			var image:String = Std.isOfType(sprite, objects.Character) ? cast(sprite, objects.Character).imageFile : null;
			var base:String = image == null ? '' : image.split('/').pop();
			var maskPath = 'characters/masks/' + base + '_mask';
			var has = base != '' && Paths.fileExists('images/' + maskPath + '.png', IMAGE);
			try
			{
				if (has)
				{
					var g = Paths.image(maskPath);
					if (g != null && g.bitmap != null) { shader.setSampler2D('altMask', g.bitmap); shader.setFloat('thr2', 1); }
					else has = false;
				}
				shader.setBool('useMask', has);
				if (Reflect.field(spec, 'thr2') != null) shader.setFloat('thr2', Reflect.field(spec, 'thr2'));
			}
			catch (e:Dynamic) {}
		}
		return true;
		#else
		return false;
		#end
	}
}
