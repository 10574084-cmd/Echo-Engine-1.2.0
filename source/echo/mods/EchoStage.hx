package echo.mods;

import backend.BaseStage;
import backend.StageData;
import objects.BGSprite;

/**
 * Draws the layers of a stage of an Echo mod (stages/<id>.js: "layers": [{ image, x, y, scale, scroll, front, anim }]).
 * EchoModLoader leaves them in the stage file as "echoLayers"; no script is needed. Layers go behind the characters unless
 * "front" is true. A layer with an "anim" plays it on every beat (like the crowd or the sniper of a stage).
 */
class EchoStage extends BaseStage
{
	var layers:Array<Dynamic>;
	var animated:Array<{sprite:BGSprite, name:String}> = [];

	public static function layersOf(stage:String):Array<Dynamic>
	{
		var file:Dynamic = StageData.getStageFile(stage);
		if (file == null) return null;
		var l:Dynamic = Reflect.field(file, 'echoLayers');
		return (l != null && Std.isOfType(l, Array) && (l : Array<Dynamic>).length > 0) ? l : null;
	}

	public static function has(stage:String):Bool
		return layersOf(stage) != null;

	public function new(stage:String)
	{
		layers = layersOf(stage);
		super();
	}

	override function create()
	{
		for (l in layers) if (Reflect.field(l, 'front') != true) place(l);
	}

	override function createPost()
	{
		for (l in layers) if (Reflect.field(l, 'front') == true) place(l);
	}

	function place(l:Dynamic):Void
	{
		var image:String = Reflect.field(l, 'image');
		var scroll:Array<Dynamic> = Reflect.field(l, 'scroll') != null ? Reflect.field(l, 'scroll') : [1, 1];
		var anim:Dynamic = Reflect.field(l, 'anim');

		var sprite:BGSprite = null;
		try
		{
			if (anim != null && Reflect.field(anim, 'prefix') != null)
			{
				sprite = new BGSprite(null, Reflect.field(l, 'x'), Reflect.field(l, 'y'), scroll[0], scroll[1]);
				sprite.frames = Paths.getSparrowAtlas(image);
				var name:String = Reflect.field(anim, 'name') != null ? Reflect.field(anim, 'name') : 'idle';
				var fps:Float = Reflect.field(anim, 'fps') != null ? Reflect.field(anim, 'fps') : 24;
				sprite.animation.addByPrefix(name, Reflect.field(anim, 'prefix'), Std.int(fps), Reflect.field(anim, 'loop') == true);
				sprite.animation.play(name);
				sprite.active = true;
				animated.push({sprite: sprite, name: name});
			}
			else
				sprite = new BGSprite(image, Reflect.field(l, 'x'), Reflect.field(l, 'y'), scroll[0], scroll[1]);
		}
		catch (e:Dynamic)
		{
			trace('Echo stage: the layer "$image" could not be made ($e)');
			return;
		}

		var scale:Float = Reflect.field(l, 'scale') != null ? Reflect.field(l, 'scale') : 1;
		if (scale != 1)
		{
			sprite.scale.set(scale, scale);
			sprite.updateHitbox();
			// the position is the top-left corner of the picture after scaling, like in the stage scripts
			sprite.x = Reflect.field(l, 'x');
			sprite.y = Reflect.field(l, 'y');
		}
		sprite.flipX = Reflect.field(l, 'flipX') == true;
		sprite.alpha = Reflect.field(l, 'alpha') != null ? Reflect.field(l, 'alpha') : 1;
		if (Reflect.field(l, 'antialiasing') == false) sprite.antialiasing = false;
		add(sprite);
	}

	override function beatHit()
	{
		for (a in animated) a.sprite.animation.play(a.name, true);
	}
}
