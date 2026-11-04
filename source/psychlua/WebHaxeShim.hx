package psychlua;

#if (html5 && !HSCRIPT_ALLOWED && LUA_ALLOWED)
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.display.FlxRuntimeShader;
import flixel.math.FlxAngle;
import states.PlayState;

/**
 * The web build has no HScript (SScript needs native code), but many Lua scripts call runHaxeCode / runHaxeFunction for a handful of
 * small jobs. Those jobs are written here in Haxe instead, by the name of the function the script defines. Anything not listed is
 * ignored (returns null) so the script keeps running. Written for the Pico Mix scripts: camera events and the drop-shadow shader.
 */
class WebHaxeShim
{
	public static function call(name:String, args:Array<Dynamic>):Dynamic
	{
		var game:PlayState = PlayState.instance;
		if (game == null) return null;
		var first:Dynamic = (args != null && args.length > 0) ? args[0] : null;

		switch (name)
		{
			// custom_events/Set Camera Target.lua
			case 'enableFollowPoint': FlxG.camera.target = game.camFollow;
			case 'disableFollowPoint': FlxG.camera.target = null;
			case 'snapCameraToTarget': FlxG.camera.snapToTarget();

			// stages/*Erect.lua: the shader needs to know the bounds of the current frame of the character
			case 'setShaderFrameInfo':
				var object:FlxSprite = byName(game, Std.string(first));
				if (object != null)
				{
					var sprite:FlxSprite = object;
					sprite.animation.callback = function(_, _, _)
					{
						var shader:FlxRuntimeShader = Std.isOfType(sprite.shader, FlxRuntimeShader) ? cast sprite.shader : null;
						if (shader == null || sprite.frame == null) return;
						shader.setFloatArray('uFrameBounds', [sprite.frame.uv.x, sprite.frame.uv.y, sprite.frame.uv.width, sprite.frame.uv.height]);
						shader.setFloat('angOffset', sprite.frame.angle * FlxAngle.TO_RAD);
					};
				}
			// data/*/dialogueBox.lua: where the "|" pauses are in a dialogue line (every pause also shifts the next ones one letter back)
			case 'detectPause':
				var result:Array<Int> = [];
				var line:String = Std.string(first);
				var at:Int = line.indexOf('|');
				while (at != -1)
				{
					result.push(at);
					at = line.indexOf('|', at + 1);
				}
				for (i in 0...result.length) result[i] -= i;
				return result;

			// the same scripts: a tap or click goes to the next line (phones and mouse), BACK does not exist on the web
			case 'detectTouch':
				for (touch in FlxG.touches.list) if (touch.justPressed) return true;
				return FlxG.mouse.justPressed;
			case 'backButton': return false;

			default:
		}
		return null;
	}

	static function byName(game:PlayState, name:String):FlxSprite
	{
		return switch (name)
		{
			case 'boyfriend': game.boyfriend;
			case 'dad': game.dad;
			case 'gf': game.gf;
			default: game.getLuaObject(name);
		}
	}
}
#end
