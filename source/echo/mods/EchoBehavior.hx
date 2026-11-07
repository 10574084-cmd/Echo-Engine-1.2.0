package echo.mods;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import backend.Conductor;
import objects.BGSprite;
import objects.Character;
import openfl.display.BlendMode;

/**
 * The library of native behaviors of Echo stages: things that a stage does by itself (lightning, a train that passes, a spotlight...).
 * A stage file asks for them by name:  "behaviors": [{ "type": "lightning", ... }]  and no script is needed. Each one keeps the
 * timings and numbers of the original stage so a ported stage plays the same.
 */
class EchoBehavior
{
	/** sprites that must not be told to dance on the beat right now (a "hey!" is playing) */
	static var busyUntil:Map<FlxSprite, Float> = [];

	public static function busy(s:FlxSprite):Bool
		return busyUntil.exists(s) && busyUntil.get(s) > haxe.Timer.stamp();

	public static function markBusy(s:FlxSprite, seconds:Float):Void
		busyUntil.set(s, haxe.Timer.stamp() + seconds);

	public static function make(type:String, stage:EchoStage, cfg:Dynamic):EchoBehavior
	{
		return switch (type)
		{
			case 'lightning': new Lightning(stage, cfg);
			case 'spotlight': new Spotlight(stage, cfg);
			case 'boppers': new Boppers(stage, cfg);
			case 'sniper': new Sniper(stage, cfg);
			case 'philly': new Philly(stage, cfg);
			default:
				trace('Echo stage: unknown behavior "$type"');
				null;
		}
	}

	var stage:EchoStage;
	var cfg:Dynamic;
	var game(get, never):states.PlayState;

	function get_game()
		return states.PlayState.instance;

	public function new(stage:EchoStage, cfg:Dynamic)
	{
		this.stage = stage;
		this.cfg = cfg;
	}

	function str(field:String, fallback:String = null):String
		return Reflect.field(cfg, field) != null ? Std.string(Reflect.field(cfg, field)) : fallback;

	public function create():Void {}
	public function createPost():Void {}
	public function update(elapsed:Float):Void {}
	public function countdownTick(num:Int):Void {}
	public function beatHit(beat:Int):Void {}
	public function stepHit(step:Int):Void {}
	public function eventPushed(name:String):Void {}
	public function eventCalled(name:String, v1:String, v2:String, f1:Null<Float>, f2:Null<Float>):Void {}

	function chars():Array<Character>
		return [game.boyfriend, game.dad, game.gf];

	function isDark(c:Character):Bool
		return c != null && c.curCharacter != null && StringTools.endsWith(c.curCharacter, '-dark');

	public static function rgb(v:Int):FlxColor
		return FlxColor.fromInt(0xFF000000 | v);
}

// ----------------------------------------------------------------------------------------------------------------------
/** Spooky Mansion: random lightning that lights the rooms, flashes the screen and scares the characters. */
class Lightning extends EchoBehavior
{
	var lastStrike:Int = 0;
	var interval:Int = 8;
	var lit:Array<String>;
	var flash:String;

	public function new(stage:EchoStage, cfg:Dynamic)
	{
		super(stage, cfg);
		lit = Reflect.field(cfg, 'lit') != null ? Reflect.field(cfg, 'lit') : [];
		flash = str('flash');
	}

	override function createPost()
	{
		if (Reflect.field(cfg, 'tintOthers') == null) return;
		var base = Std.parseInt(str('tintOthers'));
		for (c in chars()) if (c != null && !isDark(c)) c.color = EchoBehavior.rgb(base);
	}

	override function beatHit(beat:Int)
	{
		if (FlxG.random.bool(10) && beat > lastStrike + interval) strike(beat);
	}

	function litLayers():Array<FlxSprite>
		return [for (id in lit) if (stage.byId.exists(id)) stage.byId.get(id)];

	function strike(beat:Int)
	{
		lastStrike = beat;
		interval = FlxG.random.int(8, 24);
		FlxG.sound.play(Paths.soundRandom('thunder_', 1, 2));

		var flashSprite = flash != null ? stage.byId.get(flash) : null;
		if (flashSprite != null && ClientPrefs.data.flashing)
		{
			flashSprite.alpha = 0.4;
			FlxTween.tween(flashSprite, {alpha: 0.5}, 0.075, {ease: FlxEase.linear});
			new FlxTimer().start(0.15, function(_) FlxTween.tween(flashSprite, {alpha: 0}, 0.25, {ease: FlxEase.linear}));
		}

		if (!ClientPrefs.data.lowQuality)
		{
			var dark = Std.parseInt(str('tintOthers', '0x070711'));
			for (l in litLayers()) l.alpha = 1;
			for (c in chars()) if (c != null) { if (isDark(c)) c.alpha = 0; else c.color = FlxColor.WHITE; }
			new FlxTimer().start(0.06, function(_)
			{
				for (l in litLayers()) l.alpha = 0;
				for (c in chars()) if (c != null) { if (isDark(c)) c.alpha = 1; else c.color = EchoBehavior.rgb(dark); }
			});
			new FlxTimer().start(0.12, function(_)
			{
				for (l in litLayers()) { l.alpha = 1; FlxTween.tween(l, {alpha: 0}, 1.5, {ease: FlxEase.linear}); }
				for (c in chars()) if (c != null)
				{
					if (isDark(c)) { c.alpha = 0; FlxTween.tween(c, {alpha: 1}, 1.5, {ease: FlxEase.linear}); }
					else { c.color = FlxColor.WHITE; FlxTween.color(c, 1.5, FlxColor.WHITE, EchoBehavior.rgb(dark), {ease: FlxEase.linear}); }
				}
			});
		}

		if (ClientPrefs.data.camZooms)
		{
			FlxG.camera.zoom += 0.015;
			game.camHUD.zoom += 0.03;
			if (!game.camZooming)
			{
				FlxTween.tween(FlxG.camera, {zoom: game.defaultCamZoom}, 0.5, {ease: FlxEase.linear});
				FlxTween.tween(game.camHUD, {zoom: 1}, 0.5, {ease: FlxEase.linear});
			}
		}

		if (game.boyfriend != null) game.boyfriend.playAnim('scared', true);
		if (game.gf != null) game.gf.playAnim('scared', true);
	}
}

// ----------------------------------------------------------------------------------------------------------------------
/** The "Dadbattle Spotlight" event: a dark veil, a spotlight on a character and smoke. */
class Spotlight extends EchoBehavior
{
	var black:FlxSprite;
	var light:FlxSprite;
	var smoke1:FlxSprite;
	var smoke2:FlxSprite;
	var hide:Array<String>;

	public function new(stage:EchoStage, cfg:Dynamic)
	{
		super(stage, cfg);
		hide = Reflect.field(cfg, 'hide') != null ? Reflect.field(cfg, 'hide') : [];
	}

	override function eventPushed(name:String)
	{
		if (name != 'Dadbattle Spotlight' || black != null) return;
		var lightImage = str('light', 'mainStage/spotlight');
		var smokeImage = str('smoke', 'mainStage/smoke');

		black = new FlxSprite(-800, -400).makeGraphic(Std.int(FlxG.width * 2), Std.int(FlxG.height * 2), FlxColor.BLACK);
		black.scrollFactor.set(0, 0);
		black.alpha = 0.25;
		black.visible = false;

		light = new FlxSprite(400, -400, Paths.image(lightImage));
		light.blend = BlendMode.ADD;
		light.alpha = 0;
		light.visible = false;

		smoke1 = smoke(smokeImage, -1350, FlxG.random.float(15, 22), false);
		smoke2 = smoke(smokeImage, 1750, FlxG.random.float(-22, -15), true);
		for (o in [black, light, smoke1, smoke2]) stage.put(o);
	}

	function smoke(image:String, x:Float, vx:Float, flip:Bool):FlxSprite
	{
		var s = new FlxSprite(x, 680 + FlxG.random.float(-15, 15), Paths.image(image));
		s.setGraphicSize(Std.int(s.width * FlxG.random.float(1.1, 1.22)));
		s.updateHitbox();
		s.scrollFactor.set(1.2, 1.05);
		s.alpha = 0;
		s.velocity.x = vx;
		s.flipX = flip;
		s.antialiasing = ClientPrefs.data.antialiasing;
		return s;
	}

	function setHidden(hidden:Bool)
		for (id in hide) { var s = stage.byId.get(id); if (s != null) s.visible = !hidden; }

	override function eventCalled(name:String, v1:String, v2:String, f1:Null<Float>, f2:Null<Float>)
	{
		if (name != 'Dadbattle Spotlight' || black == null) return;
		var value = f1 == null ? 0 : Math.round(f1);
		if (value > 0)
		{
			if (value == 1)
			{
				game.defaultCamZoom += 0.12;
				setHidden(true);
				black.visible = light.visible = smoke1.visible = smoke2.visible = true;
			}
			var who:Character = value > 2 ? game.boyfriend : game.dad;
			new FlxTimer().start(0.12, function(_) light.alpha = 0.375);
			light.setPosition(who.getGraphicMidpoint().x - light.width / 2, who.y + who.height - light.height + 50);
			FlxTween.tween(smoke1, {alpha: 0.7}, 1.5, {ease: FlxEase.quadInOut});
			FlxTween.tween(smoke2, {alpha: 0.7}, 1.5, {ease: FlxEase.quadInOut});
		}
		else
		{
			game.defaultCamZoom -= 0.12;
			setHidden(false);
			black.visible = light.visible = false;
			FlxTween.tween(smoke1, {alpha: 0}, 0.7, {ease: FlxEase.linear});
			FlxTween.tween(smoke2, {alpha: 0}, 0.7, {ease: FlxEase.linear});
		}
	}
}

// ----------------------------------------------------------------------------------------------------------------------
/** Mall: the crowd at the bottom cheers on a "Hey!" event (and does not dance while it does). */
class Boppers extends EchoBehavior
{
	override function eventCalled(name:String, v1:String, v2:String, f1:Null<Float>, f2:Null<Float>)
	{
		if (name != 'Hey!') return;
		var s = stage.byId.get(str('layer', 'bottomBoppers'));
		if (s == null) return;
		var time = (v2 == null || v2 == '') ? 0.6 : Std.parseFloat(v2);
		if (Math.isNaN(time)) time = 0.6;
		var hey = str('hey', 'hey');
		if (s.animation.exists(hey)) s.animation.play(hey, true);
		EchoBehavior.markBusy(s, time);
		new FlxTimer().start(time, function(_)
		{
			if (s.animation.exists('idle')) s.animation.play('idle', true);
		});
	}
}

// ----------------------------------------------------------------------------------------------------------------------
/** Tank: the sniper sometimes drinks from his cup; he and his friend move on the beat. */
class Sniper extends EchoBehavior
{
	var sipping:Bool = false;

	function tick(on:Bool)
	{
		var sniper = stage.byId.get(str('sniper', 'sniper'));
		var guy = stage.byId.get(str('guy', 'tankguy'));
		if (sniper == null) return;
		if (FlxG.random.bool(2) && !sipping)
		{
			sniper.animation.play('sip', true);
			var frames = sniper.animation.curAnim != null ? sniper.animation.curAnim.numFrames : 24;
			new FlxTimer().start(frames / 24, function(_) sipping = false);
			sipping = true;
		}
		if (on)
		{
			if (!sipping) sniper.animation.play('idle', true);
			if (guy != null) guy.animation.play('idle', true);
		}
	}

	override function countdownTick(num:Int)
		tick(num % 2 == 0);

	override function beatHit(beat:Int)
		tick(beat % 2 == 0);
}

// ----------------------------------------------------------------------------------------------------------------------
/** Philly: the window that changes color, the train that passes by (blowing Girlfriend's hair) and the "Philly Glow" event. */
class Philly extends EchoBehavior
{
	static final WINDOWS:Array<Int> = [0x2663AC, 0x329A6D, 0x502D64, 0x932C28, 0xB66F43];
	static final EVENT_COLORS:Array<String> = ['31A2FD', '31FD8C', 'FB33F5', 'FD4531', 'FBA633'];
	static final STREET:Array<Int> = [0x025497, 0x029745, 0x960391, 0x971102, 0x965903];
	static final CHARS_FLASH:Array<Int> = [0x499EE4, 0x49E48F, 0xE24BDD, 0xE45949, 0xE2A34B];
	static final CHARS_SAFE:Array<Int> = [0x639CCA, 0x63CA91, 0xC964C5, 0xCA6D63, 0xC99F64];

	var selectedColor:Int = -1;
	var selectedEvent:Int = -1;
	var window:FlxSprite;
	var train:FlxSprite;
	var street:String;
	var moving:Bool = false;
	var started:Bool = false;
	var finished:Bool = false;
	var cars:Int = 8;
	var cooldown:Int = 0;
	var frameTiming:Float = 0;
	var trainSound:flixel.sound.FlxSound;

	// glow event
	var black:FlxSprite;
	var windowEvent:FlxSprite;
	var gradient:FlxSprite;
	var particles:Array<{sprite:FlxSprite, life:Float, decay:Float, scale:Float}> = [];
	var flashSprite:FlxSprite;
	var flashDuration:Float = 0;

	override function createPost()
	{
		window = stage.byId.get(str('window', 'window'));
		train = stage.byId.get(str('train', 'train'));
		street = str('street', 'street');
		if (train != null) Paths.sound('train_passes');
	}

	override function eventPushed(name:String)
	{
		if (name != 'Philly Glow' || black != null) return;
		black = new FlxSprite(FlxG.width * -0.5, FlxG.height * -0.5).makeGraphic(Std.int(FlxG.width * 2), Std.int(FlxG.height * 2), FlxColor.BLACK);
		black.visible = false;

		windowEvent = new FlxSprite(-10, 0, Paths.image('philly/window'));
		windowEvent.setGraphicSize(Std.int(windowEvent.width * 0.85));
		windowEvent.updateHitbox();
		windowEvent.scrollFactor.set(0.3, 0.3);
		windowEvent.visible = false;

		gradient = new FlxSprite(-400, 225, Paths.image('philly/gradient'));
		gradient.setGraphicSize(2000, 400);
		gradient.updateHitbox();
		gradient.scrollFactor.set(0, 0.75);
		gradient.visible = false;
		if (!ClientPrefs.data.flashing) gradient.alpha = 0.7;

		Paths.image('philly/particle');
		for (o in [black, windowEvent, gradient]) stage.addAt(o, street);
	}

	override function update(elapsed:Float)
	{
		if (moving)
		{
			frameTiming += elapsed;
			if (frameTiming >= 1 / 24) { updateTrain(); frameTiming = 0; }
		}
		if (window != null) window.alpha -= (Conductor.crochet / 1000) * elapsed * 1.5;

		updateFlash(elapsed);
		updateGradient(elapsed);
		updateParticles(elapsed);
	}

	override function beatHit(beat:Int)
	{
		if (!moving) cooldown++;
		if (beat % 4 == 0 && window != null)
		{
			selectedColor = FlxG.random.int(0, WINDOWS.length - 1, selectedColor >= 0 ? [selectedColor] : null);
			window.alpha = 1;
			window.color = EchoBehavior.rgb(WINDOWS[selectedColor]);
		}
		if (beat % 8 == 4 && FlxG.random.bool(30) && !moving && cooldown > 8 && train != null)
		{
			cooldown = FlxG.random.int(-4, 0);
			moving = true;
			trainSound = FlxG.sound.play(Paths.sound('train_passes'));
		}
	}

	function updateTrain()
	{
		var gf = game.gf;
		if (trainSound != null && trainSound.time >= 4700)
		{
			started = true;
			if (gf != null) { gf.playAnim('hairBlow'); gf.specialAnim = true; }
		}
		if (!started) return;
		train.x -= 400;
		if (train.x < -2000 && !finished)
		{
			train.x = -1150;
			cars--;
			if (cars <= 0) finished = true;
		}
		if (train.x - 400 < -4000 && finished) reset();
	}

	function reset()
	{
		moving = false;
		cars = 8;
		finished = false;
		started = false;
		train.x = FlxG.width + 200;
		var gf = game.gf;
		if (gf != null) { gf.danced = false; gf.playAnim('hairFall'); gf.specialAnim = true; }
	}

	// ----- Philly Glow ----------------------------------------------------------------------------------------------

	function eventColor():FlxColor
		return FlxColor.fromString('#' + EVENT_COLORS[selectedEvent]);

	override function eventCalled(name:String, v1:String, v2:String, f1:Null<Float>, f2:Null<Float>)
	{
		if (name != 'Philly Glow' || black == null) return;
		var streetSprite = stage.byId.get(street);
		var flashing = ClientPrefs.data.flashing;
		switch (v1)
		{
			case '0':
				selectedEvent = -1;
				if (gradient.visible)
				{
					doFlash(FlxColor.WHITE, 0.15, flashing ? 1 : 0.5);
					if (ClientPrefs.data.camZooms) { FlxG.camera.zoom += 0.5; game.camHUD.zoom += 0.1; }
					black.visible = windowEvent.visible = gradient.visible = false;
					for (p in particles) { stage.take(p.sprite); p.sprite.destroy(); }
					particles = [];
					if (streetSprite != null) streetSprite.color = FlxColor.WHITE;
					for (c in chars()) if (c != null) c.color = FlxColor.WHITE;
					stage.reapplyFilters(['bf', 'dad', 'gf']);
				}
			case '1':
				selectedEvent = FlxG.random.int(0, EVENT_COLORS.length - 1, selectedEvent >= 0 ? [selectedEvent] : null);
				if (!gradient.visible)
				{
					doFlash(FlxColor.WHITE, 0.15, flashing ? 1 : 0.5);
					if (ClientPrefs.data.camZooms) { FlxG.camera.zoom += 0.5; game.camHUD.zoom += 0.1; }
					black.visible = windowEvent.visible = gradient.visible = true;
					for (c in chars()) if (c != null) c.shader = null;
				}
				else if (flashing)
					doFlash(eventColor(), 0.25, 0.5);

				windowEvent.color = eventColor();
				gradient.color = eventColor();
				for (p in particles) p.sprite.color = eventColor();
				if (streetSprite != null) streetSprite.color = EchoBehavior.rgb(STREET[selectedEvent]);
				for (c in chars()) if (c != null) c.color = EchoBehavior.rgb((flashing ? CHARS_FLASH : CHARS_SAFE)[selectedEvent]);
			case '2':
				if (selectedEvent < 0) selectedEvent = 0;
				if (!ClientPrefs.data.lowQuality)
				{
					var num = FlxG.random.int(8, 12);
					var width = 2000 / num;
					for (y in 1...4)
						for (x in 1...num + 1)
							particle(-400 + width * x + FlxG.random.float(-width / 5, width / 5), 425 + (FlxG.random.float(0, 125) + y * 40));
				}
				gradient.setGraphicSize(2000, 400);
				gradient.updateHitbox();
				gradient.y = 225;
				gradient.alpha = flashing ? 1 : 0.7;
		}
	}

	function doFlash(color:FlxColor, duration:Float, startAlpha:Float)
	{
		if (flashSprite != null) { stage.take(flashSprite); flashSprite.destroy(); }
		flashSprite = new FlxSprite(FlxG.width * -0.5, FlxG.height * -0.5).makeGraphic(Std.int(FlxG.width * 2), Std.int(FlxG.height * 2), color);
		flashSprite.alpha = startAlpha;
		stage.put(flashSprite);
		flashDuration = duration / startAlpha;
	}

	function updateFlash(elapsed:Float)
	{
		if (flashSprite == null) return;
		if (flashSprite.alpha > 0) flashSprite.alpha -= elapsed / flashDuration;
		else { stage.take(flashSprite); flashSprite.destroy(); flashSprite = null; }
	}

	function updateGradient(elapsed:Float)
	{
		if (gradient == null) return;
		var h = Math.round(gradient.height - 1000 * elapsed);
		if (h > 0)
		{
			gradient.setGraphicSize(2000, h);
			gradient.updateHitbox();
			gradient.y = 225 + (400 - gradient.height);
			gradient.alpha = ClientPrefs.data.flashing ? 1 : 0.7;
		}
		else
		{
			gradient.alpha = 0;
			gradient.y = -5000;
		}
	}

	function particle(x:Float, y:Float)
	{
		var s = new FlxSprite(x, y, Paths.image('philly/particle'));
		var life = FlxG.random.float(0.6, 0.9);
		var decay = FlxG.random.float(0.8, 1);
		var scale = FlxG.random.float(0.75, 1);
		s.scale.set(scale, scale);
		s.updateHitbox();
		s.scrollFactor.set(FlxG.random.float(0.3, 0.75), FlxG.random.float(0.65, 0.75));
		s.color = eventColor();
		s.velocity.set(FlxG.random.float(-40, 40), FlxG.random.float(-175, -250));
		s.acceleration.set(FlxG.random.float(-10, 10), 25);
		if (!ClientPrefs.data.flashing) { s.alpha = 0.5; decay *= 0.5; }
		stage.addAt(s, street);
		particles.push({sprite: s, life: life, decay: decay, scale: scale});
	}

	function updateParticles(elapsed:Float)
	{
		var i = particles.length;
		while (i-- > 0)
		{
			var p = particles[i];
			p.life -= elapsed;
			if (p.life < 0)
			{
				p.life = 0;
				p.sprite.alpha -= p.decay * elapsed;
				if (p.sprite.alpha > 0)
				{
					p.sprite.scale.set(p.scale * p.sprite.alpha, p.scale * p.sprite.alpha);
					p.sprite.updateHitbox();
				}
				else { stage.take(p.sprite); p.sprite.destroy(); particles.splice(i, 1); }
			}
		}
	}
}
