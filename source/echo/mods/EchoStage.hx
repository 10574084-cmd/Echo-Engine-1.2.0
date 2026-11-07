package echo.mods;

import backend.BaseStage;
import backend.StageData;
import flixel.FlxSprite;
import flixel.util.FlxColor;
import objects.BGSprite;
import openfl.display.BlendMode;

/**
 * A stage of an Echo mod, drawn natively (no script). Everything comes from the stage file (stages/<id>.js):
 *
 *   layers:    [{ id, image | color+size, x, y, scale, scroll, alpha, flipX, antialiasing, front, visible, blend, tint,
 *                 anim | anims, frames, atlas, beat, quality, flashing }]
 *   filters:   [{ target: "bf" | "dad" | "gf" | <layer id>, shader, ...values }]   (see EchoFx)
 *   behaviors: [{ type: "lightning" | "spotlight" | "philly" | "boppers" | "sniper", ... }]  (see EchoBehaviors)
 *   gameOver:  { character, deathSound, loopSound, endSound }
 *
 * EchoModLoader leaves them in the stage file as "echoLayers", "echoFilters", "echoBehaviors" and "echoGameOver".
 * A layer goes behind the characters unless "front" is true. "quality": "high" hides it in low quality, "flashing": true hides it
 * when flashing lights are off. "beat": { anim, every } plays an animation on the beat.
 */
class EchoStage extends BaseStage
{
	var layers:Array<Dynamic>;
	var filters:Array<Dynamic>;
	var behaviorSpecs:Array<Dynamic>;
	public var byId:Map<String, FlxSprite> = new Map();
	var beaters:Array<{sprite:FlxSprite, anim:String, every:Int, offset:Int}> = [];
	var behaviors:Array<EchoBehavior> = [];
	var timeFilters:Array<{shader:flixel.addons.display.FlxRuntimeShader, uniform:String}> = [];
	var elapsedTime:Float = 0;

	public static function fileOf(stage:String, field:String):Dynamic
	{
		var file:Dynamic = StageData.getStageFile(stage);
		if (file == null) return null;
		return Reflect.field(file, field);
	}

	public static function layersOf(stage:String):Array<Dynamic>
	{
		var l:Dynamic = fileOf(stage, 'echoLayers');
		return (l != null && Std.isOfType(l, Array) && (l : Array<Dynamic>).length > 0) ? l : null;
	}

	public static function has(stage:String):Bool
		return layersOf(stage) != null || fileOf(stage, 'echoBehaviors') != null;

	public function new(stage:String)
	{
		var l:Array<Dynamic> = layersOf(stage);
		layers = l != null ? l : [];
		var f:Dynamic = fileOf(stage, 'echoFilters');
		filters = f != null ? f : [];
		var b:Dynamic = fileOf(stage, 'echoBehaviors');
		behaviorSpecs = b != null ? b : [];
		var go:Dynamic = fileOf(stage, 'echoGameOver');
		if (go != null)
		{
			if (Reflect.field(go, 'character') != null) substates.GameOverSubstate.characterName = Reflect.field(go, 'character');
			if (Reflect.field(go, 'deathSound') != null) substates.GameOverSubstate.deathSoundName = Reflect.field(go, 'deathSound');
			if (Reflect.field(go, 'loopSound') != null) substates.GameOverSubstate.loopSoundName = Reflect.field(go, 'loopSound');
			if (Reflect.field(go, 'endSound') != null) substates.GameOverSubstate.endSoundName = Reflect.field(go, 'endSound');
		}
		super();
	}

	// ------------------------------------------------------------------------------------------------------------------

	static function skipped(l:Dynamic):Bool
	{
		if (Reflect.field(l, 'quality') == 'high' && ClientPrefs.data.lowQuality) return true;
		if (Reflect.field(l, 'flashing') == true && !ClientPrefs.data.flashing) return true;
		return false;
	}

	override function create()
	{
		for (spec in behaviorSpecs)
		{
			var b = EchoBehavior.make(Reflect.field(spec, 'type'), this, spec);
			if (b != null) behaviors.push(b);
		}
		for (l in layers) if (Reflect.field(l, 'front') != true) place(l);
		for (b in behaviors) b.create();
	}

	override function createPost()
	{
		for (l in layers) if (Reflect.field(l, 'front') == true) place(l);
		applyFilters();
		for (b in behaviors) b.createPost();
	}

	function target(id:String):FlxSprite
	{
		return switch (id)
		{
			case 'bf' | 'boyfriend': boyfriend;
			case 'dad' | 'opponent': dad;
			case 'gf' | 'girlfriend': gf;
			default: byId.get(id);
		}
	}

	public function applyFilters():Void
	{
		for (f in filters)
		{
			var t = target(Reflect.field(f, 'target'));
			if (t == null || !matches(f, t)) continue;
			var ok = EchoFx.apply(t, f);
			var uniform:String = Reflect.field(f, 'time');
			if (ok && uniform != null) timeFilters.push({shader: cast t.shader, uniform: uniform});
		}
	}

	/** "if": "<character>" applies the filter only to that character, "unless" to every other one. */
	static function matches(f:Dynamic, t:FlxSprite):Bool
	{
		var name:String = Std.isOfType(t, objects.Character) ? cast(t, objects.Character).curCharacter : null;
		var only:String = Reflect.field(f, 'if');
		var except:String = Reflect.field(f, 'unless');
		if (only != null && name != only) return false;
		if (except != null && name == except) return false;
		return true;
	}

	public function reapplyFilters(ids:Array<String>):Void
	{
		for (f in filters)
		{
			var t = target(Reflect.field(f, 'target'));
			if (t != null && ids.indexOf(Reflect.field(f, 'target')) >= 0 && matches(f, t)) EchoFx.apply(t, f);
		}
	}

	static function tintOf(v:Dynamic, fallback:FlxColor):FlxColor
	{
		if (v == null) return fallback;
		if (Std.isOfType(v, Int)) return FlxColor.fromInt(0xFF000000 | cast(v, Int));
		var c = FlxColor.fromString(Std.string(v).indexOf('#') == 0 ? Std.string(v) : '#' + Std.string(v));
		return c == null ? fallback : c;
	}

	static function blendOf(name:String):BlendMode
	{
		return switch (name == null ? '' : name.toLowerCase())
		{
			case 'add' | 'additive': BlendMode.ADD;
			case 'multiply': BlendMode.MULTIPLY;
			case 'screen': BlendMode.SCREEN;
			case 'overlay': BlendMode.OVERLAY;
			case 'subtract': BlendMode.SUBTRACT;
			case 'lighten': BlendMode.LIGHTEN;
			case 'darken': BlendMode.DARKEN;
			case 'difference': BlendMode.DIFFERENCE;
			default: BlendMode.NORMAL;
		}
	}

	function place(l:Dynamic):Void
	{
		if (skipped(l)) return;
		var image:String = Reflect.field(l, 'image');
		var scroll:Array<Dynamic> = Reflect.field(l, 'scroll') != null ? Reflect.field(l, 'scroll') : [1, 1];
		var anims:Array<Dynamic> = Reflect.field(l, 'anims') != null ? Reflect.field(l, 'anims') : (Reflect.field(l, 'anim') != null ? [Reflect.field(l, 'anim')] : []);

		var sprite:FlxSprite = null;
		try
		{
			if (image == null)
			{
				// a plain rectangle (a dark veil, a flash...)
				var size:Array<Dynamic> = Reflect.field(l, 'size') != null ? Reflect.field(l, 'size') : [FlxG.width * 2, FlxG.height * 2];
				var bg = new BGSprite(null, Reflect.field(l, 'x'), Reflect.field(l, 'y'), scroll[0], scroll[1]);
				bg.makeGraphic(Std.int(size[0]), Std.int(size[1]), tintOf(Reflect.field(l, 'color'), FlxColor.WHITE));
				sprite = bg;
			}
			else if (anims.length > 0)
			{
				sprite = new BGSprite(null, Reflect.field(l, 'x'), Reflect.field(l, 'y'), scroll[0], scroll[1]);
				sprite.frames = Reflect.field(l, 'atlas') == 'packer' ? Paths.getPackerAtlas(image) : Paths.getSparrowAtlas(image);
				for (a in anims)
				{
					var name:String = Reflect.field(a, 'name') != null ? Reflect.field(a, 'name') : 'idle';
					var fps:Int = Std.int(Reflect.field(a, 'fps') != null ? Reflect.field(a, 'fps') : 24);
					var loop:Bool = Reflect.field(a, 'loop') == true;
					if (Reflect.field(a, 'frames') != null)
						sprite.animation.add(name, [for (n in (Reflect.field(a, 'frames') : Array<Dynamic>)) Std.int(n)], fps, loop);
					else
						sprite.animation.addByPrefix(name, Reflect.field(a, 'prefix'), fps, loop);
				}
				var first:String = Reflect.field(anims[0], 'name') != null ? Reflect.field(anims[0], 'name') : 'idle';
				sprite.animation.play(first);
				sprite.active = true;
			}
			else
				sprite = new BGSprite(image, Reflect.field(l, 'x'), Reflect.field(l, 'y'), scroll[0], scroll[1]);
		}
		catch (e:Dynamic)
		{
			trace('Echo stage: the layer "$image" could not be made ($e)');
			return;
		}

		var sc:Dynamic = Reflect.field(l, 'scale');
		if (sc != null)
		{
			var sx:Float = Std.isOfType(sc, Array) ? (sc : Array<Dynamic>)[0] : sc;
			var sy:Float = Std.isOfType(sc, Array) ? (sc : Array<Dynamic>)[1] : sc;
			if (sx != 1 || sy != 1)
			{
				sprite.scale.set(sx, sy);
				sprite.updateHitbox();
				// the position is the top-left corner of the picture after scaling, like in the stage scripts
				sprite.x = Reflect.field(l, 'x');
				sprite.y = Reflect.field(l, 'y');
			}
		}
		if (Reflect.field(l, 'size') != null && image != null)
		{
			var size:Array<Dynamic> = Reflect.field(l, 'size');
			sprite.setGraphicSize(Std.int(size[0]), Std.int(size[1]));
			sprite.updateHitbox();
		}
		sprite.flipX = Reflect.field(l, 'flipX') == true;
		sprite.alpha = Reflect.field(l, 'alpha') != null ? Reflect.field(l, 'alpha') : 1;
		sprite.visible = Reflect.field(l, 'visible') != false;
		if (Reflect.field(l, 'antialiasing') == false) sprite.antialiasing = false;
		if (Reflect.field(l, 'blend') != null) sprite.blend = blendOf(Reflect.field(l, 'blend'));
		if (Reflect.field(l, 'tint') != null) sprite.color = tintOf(Reflect.field(l, 'tint'), FlxColor.WHITE);
		if (Reflect.field(l, 'beat') != null)
		{
			var b = Reflect.field(l, 'beat');
			var anim:String = Std.isOfType(b, String) ? b : (Reflect.field(b, 'anim') != null ? Reflect.field(b, 'anim') : 'idle');
			var every:Int = Std.isOfType(b, String) || Reflect.field(b, 'every') == null ? 1 : Std.int(Reflect.field(b, 'every'));
			var offset:Int = Std.isOfType(b, String) || Reflect.field(b, 'offset') == null ? 0 : Std.int(Reflect.field(b, 'offset'));
			beaters.push({sprite: sprite, anim: anim, every: every < 1 ? 1 : every, offset: offset});
		}
		var id:String = Reflect.field(l, 'id');
		if (id != null) byId.set(id, sprite);
		add(sprite);
	}

	public function put(obj:flixel.FlxBasic):Void add(obj);
	public function take(obj:flixel.FlxBasic):Void remove(obj);

	/** Inserts an object behind or in front of a layer (used by behaviors that need a precise order). */
	public function addAt(obj:flixel.FlxBasic, ?belowLayer:String, ?aboveLayer:String):Void
	{
		var ref = belowLayer != null ? byId.get(belowLayer) : (aboveLayer != null ? byId.get(aboveLayer) : null);
		if (ref == null) { add(obj); return; }
		var i = members.indexOf(ref);
		if (i < 0) { add(obj); return; }
		insert(belowLayer != null ? i : i + 1, obj);
	}

	public function playOn(id:String, anim:String, force:Bool = true):Void
	{
		var s = byId.get(id);
		if (s != null && s.animation.exists(anim)) s.animation.play(anim, force);
	}

	// ------------------------------------------------------------------------------------------------------------------

	override function update(elapsed:Float)
	{
		if (timeFilters.length > 0)
		{
			elapsedTime += elapsed;
			for (t in timeFilters) t.shader.setFloat(t.uniform, elapsedTime);
		}
		for (b in behaviors) b.update(elapsed);
	}

	override function countdownTick(count:Countdown, num:Int)
	{
		for (b in beaters) if (num % b.every == b.offset % b.every) b.sprite.animation.play(b.anim, true);
		for (b in behaviors) b.countdownTick(num);
	}

	override function beatHit()
	{
		for (b in beaters) if ((curBeat - b.offset) % b.every == 0 && !EchoBehavior.busy(b.sprite)) b.sprite.animation.play(b.anim, true);
		for (b in behaviors) b.beatHit(curBeat);
	}

	override function stepHit()
		for (b in behaviors) b.stepHit(curStep);

	override function eventPushed(event:objects.Note.EventNote)
		for (b in behaviors) b.eventPushed(event.event);

	override function eventCalled(eventName:String, value1:String, value2:String, flValue1:Null<Float>, flValue2:Null<Float>, strumTime:Float)
		for (b in behaviors) b.eventCalled(eventName, value1, value2, flValue1, flValue2);
}
