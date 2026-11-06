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
				if (object != null) frameInfo(object);
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

			// scripts/characterChangeShaderFix.lua: a character that is swapped (Change Character) keeps its shader
			case 'saveShader': savedShaders.set(Std.string(first), byName(game, Std.string(first)).shader);
			// custom_notetypes/Censor.lua
			case 'applyCensorShader':
				var censor:FlxSprite = game.getLuaObject(first == true ? 'dadCensor' : 'boyfriendCensor');
				var source:FlxSprite = first == true ? game.dad : game.boyfriend;
				if (censor != null) censor.shader = source.shader;
			// scripts/gameOvers.lua
			case 'getScreenPosition':
				var point = byName(game, Std.string(first)).getScreenPosition();
				return [point.x, point.y];

			// data/stress-*/cutsceneEnding.lua: a camera of its own with the drop shadow shader, for the cutscene tankman
			case 'activateDropShadowShader': activateDropShadow(game);
			case 'updateDropShadowShader': updateDropShadow(game);

			// characters/abot-speaker*.lua: the sound bars of the speaker of Nene
			case 'startVisualizer': echo.EchoVisualizer.start();
			case 'stopVisualizer':
				echo.EchoVisualizer.stop();
				for (look in looks)
					for (i in 1...8)
					{
						var bar:FlxSprite = game.getLuaObject('AbotSpeakerVisualizer' + look + i);
						if (bar != null && bar.animation.curAnim != null) bar.animation.curAnim.finish();
					}
			case 'updateVisualizer': updateVisualizer(game);

			// the same scripts: the parts of the speaker use the shader of the character it is attached to
			case 'shaderCheck': return byName(game, Std.string(first)).shader == attached(game, Std.string(args[1])).shader;
			case 'applyShader':
				if (args.length >= 2) byName(game, Std.string(first)).shader = attached(game, Std.string(args[1])).shader;
				else restoreShader(game, Std.string(first)); // scripts/characterChangeShaderFix.lua
			case 'shaderAtlasCheck': return atlas(game, Std.string(first)).shader == attached(game, Std.string(args[1])).shader;
			case 'applyAtlasShader': atlas(game, Std.string(first)).shader = attached(game, Std.string(args[1])).shader;

			default:
		}
		return null;
	}

	// the speaker of Nene comes in four looks; every one has its own names for the parts
	static var looks:Array<String> = ['', 'Dark', 'Tank', 'Pixel'];
	static var savedShaders:Map<String, flixel.system.FlxAssets.FlxShader> = new Map();

	static function restoreShader(game:PlayState, character:String):Void
	{
		var saved = savedShaders.get(character);
		if (saved != null) byName(game, character).shader = saved;
	}

	static var dropShadowCamera:flixel.FlxCamera = null;

	static function activateDropShadow(game:PlayState):Void
	{
		var cutscene:FlxSprite = game.getLuaObject('tankmanCutscene');
		var filter:FlxSprite = game.getLuaObject('dropShadowFilter');
		if (cutscene == null || filter == null || filter.shader == null) return;
		dropShadowCamera = new flixel.FlxCamera();
		dropShadowCamera.bgColor = 0x00FFFFFF;
		for (cam in [game.camHUD, game.camOther]) FlxG.cameras.remove(cam, false);
		FlxG.cameras.add(dropShadowCamera, false);
		for (cam in [game.camHUD, game.camOther]) FlxG.cameras.add(cam, false);
		cutscene.cameras = [dropShadowCamera];
		dropShadowCamera.filters = [new openfl.filters.ShaderFilter(filter.shader)];
		dropShadowCamera.follow(game.camFollow, flixel.FlxCameraFollowStyle.LOCKON, 0);
	}

	static function updateDropShadow(game:PlayState):Void
	{
		if (dropShadowCamera == null) return;
		dropShadowCamera.scroll.x = game.camGame.scroll.x;
		dropShadowCamera.scroll.y = game.camGame.scroll.y;
		dropShadowCamera.zoom = game.camGame.zoom;
		var filter:FlxSprite = game.getLuaObject('dropShadowFilter');
		if (filter != null && Std.isOfType(filter.shader, FlxRuntimeShader))
		{
			var shader:FlxRuntimeShader = cast filter.shader;
			shader.setFloat('zoom', dropShadowCamera.zoom);
		}
	}

	/** runHaxeCode(code, {vars}): the pieces of code that the Pico Mix scripts send, recognised by what they do. */
	public static function runCode(code:String, vars:Dynamic):Dynamic
	{
		var game:PlayState = PlayState.instance;
		if (game == null || code == null) return null;

		// typing sound of the dialogue box
		if (code.indexOf("getLuaObject('dialogueText').sounds") >= 0)
		{
			var text:Dynamic = game.variables.get('dialogueText');
			if (text != null) text.sounds = [FlxG.sound.load(backend.Paths.sound('pixelText'), 0.6)];
			return null;
		}

		// "<sprite>.animation.callback = ...uFrameBounds..." : the shader of the sprite needs the bounds of the frame that is showing
		if (code.indexOf('.animation.callback') >= 0 && code.indexOf('uFrameBounds') >= 0 && code.indexOf('function setShaderFrameInfo') < 0)
		{
			var target = ~/(game\.)?(\w+)\.animation\.callback\s*=/;
			if (target.match(code))
			{
				var name:String = target.matched(2);
				var object:FlxSprite = null;
				if (target.matched(1) != null) object = byName(game, name);
				else
				{
					var declared = new EReg('var\\s+' + name + '\\s*=\\s*(?:game\\.)?getLuaObject\\((?:\'([^\']+)\'|(\\w+))\\)', '');
					if (declared.match(code))
					{
						var tag:String = declared.matched(1);
						if (tag == null) tag = Std.string(Reflect.field(vars, declared.matched(2)));
						object = byName(game, tag);
					}
				}
				if (object != null) frameInfo(object);
			}
		}
		return null;
	}

	static function frameInfo(sprite:FlxSprite):Void
	{
		sprite.animation.callback = function(_, _, _)
		{
			var shader:FlxRuntimeShader = Std.isOfType(sprite.shader, FlxRuntimeShader) ? cast sprite.shader : null;
			if (shader == null || sprite.frame == null) return;
			shader.setFloatArray('uFrameBounds', [sprite.frame.uv.x, sprite.frame.uv.y, sprite.frame.uv.width, sprite.frame.uv.height]);
			shader.setFloat('angOffset', sprite.frame.angle * FlxAngle.TO_RAD);
		};
	}

	static var levelMax:Map<String, Int> = new Map();

	static function updateVisualizer(game:PlayState):Void
	{
		for (look in looks)
		{
			var barName:String = 'AbotSpeakerVisualizer' + look;
			if (game.getLuaObject(barName + '1') == null) continue;

			if (!echo.EchoVisualizer.active)
			{
				for (i in 1...8)
				{
					var bar:FlxSprite = game.getLuaObject(barName + i);
					if (bar != null) bar.visible = false;
				}
				continue;
			}

			var levels = echo.EchoVisualizer.read();
			var oldLevelMax:Int = levelMax.exists(look) ? levelMax.get(look) : 0;
			var newMax:Int = 0;
			for (i in 0...7)
			{
				var bar:FlxSprite = game.getLuaObject(barName + (i + 1));
				if (bar == null || bar.animation.curAnim == null) continue;
				var animLength:Int = bar.animation.curAnim.numFrames - 1;
				var animFrame:Int = Math.round(levels[i] * (animLength + 1));
				bar.visible = animFrame > 0;
				animFrame = Std.int(Math.abs(flixel.math.FlxMath.bound(animFrame - 1, 0, animLength) - animLength));
				bar.animation.curAnim.curFrame = animFrame;
				newMax = Std.int(Math.max(newMax, animLength - animFrame));
			}
			levelMax.set(look, newMax);

			if (newMax >= 4 && oldLevelMax <= newMax)
			{
				if (look == 'Pixel')
				{
					var pixel:FlxSprite = game.getLuaObject('AbotPixelSpeakers');
					if (pixel != null && (newMax >= 5 || (pixel.animation.curAnim != null && pixel.animation.curAnim.curFrame >= 5)))
						pixel.animation.play('idle', true, false, 2);
				}
				else
				{
					var speaker:flxanimate.FlxAnimate = cast atlas(game, 'AbotSpeaker' + look);
					if (speaker != null && (newMax >= 5 || speaker.anim.curFrame >= 3)) speaker.anim.play('', true);
				}
			}
		}
	}

	static function atlas(game:PlayState, name:String):FlxSprite
	{
		var found:Dynamic = game.variables.get(name);
		return found != null ? found : game.getLuaObject(name);
	}

	static function attached(game:PlayState, character:String):FlxSprite
	{
		return switch (character)
		{
			case 'boyfriend': game.boyfriend;
			case 'dad': game.dad;
			case 'gf': game.gf;
			default:
				for (look in looks)
				{
					var part:FlxSprite = game.getLuaObject(look == 'Pixel' ? 'AbotSpeakerPixel' : 'AbotSpeaker' + look);
					if (part != null) return part;
				}
				null;
		}
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
