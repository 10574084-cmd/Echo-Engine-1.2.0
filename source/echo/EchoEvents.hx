package echo;

import backend.BaseStage;
import backend.Conductor;
import flixel.FlxG;
import flixel.math.FlxMath;
import flixel.tweens.FlxTween;
import psychlua.LuaUtils;

/**
 * The native event library of Echo mods: the events that most mods need, done in the engine instead of in scripts.
 *
 *   Set Camera Zoom    value1 "zoom[,stage]"        value2 "steps[,ease]"
 *   Set Camera Bop     value1 "rate[,offset]"       value2 "intensity"
 *   Set Camera Target  value1 "who[,x[,y]]"         value2 "steps[,ease]"   (empty value1 gives the camera back to the sections)
 *   Set Scroll Speed   value1 "speed[,absolute]"    value2 "steps[,ease]"
 *
 * They behave exactly like the Lua events of Pico Mix (same numbers, same camera feel). The library is switched on for the mods
 * that carry the "echo" mark in their pack.json (the Echo mod loader writes it), so a Psych mod with its own script for an event
 * of the same name keeps its script.
 */
class EchoEvents extends BaseStage
{
	public static final NAMES:Array<String> = ['Set Camera Zoom', 'Set Camera Bop', 'Set Camera Target', 'Set Scroll Speed'];

	static var echoMod:Null<Bool> = null;

	public static function enabled():Bool
	{
		try
		{
			var pack:Dynamic = Mods.getPack(Mods.currentModDirectory);
			return pack != null && Reflect.field(pack, 'echo') == true;
		}
		catch (e:Dynamic) {}
		return false;
	}

	/** true when the engine does this event itself (its script must not be started) */
	public static function native(name:String):Bool
		return NAMES.indexOf(name) >= 0 && enabled();

	// camera zoom / bop
	var zoomMult:Float = 1;
	var rate:Float = 4;
	var rateOffset:Float = 0;
	var intensity:Float = 1;
	var decay:Float = 1;
	var defaultZoom:Float = 1;
	var customZoom:Bool = false;
	public var cutsceneMode:Bool = false;

	var zoomTween:FlxTween;
	var camTween:FlxTween;
	var scrollTween:FlxTween;
	var scrollMultiplier:Float = 1;

	public function new(withZoom:Bool)
	{
		customZoom = withZoom;
		super();
	}

	override function create()
	{
		if (customZoom)
		{
			// the default zoom-on-beat of the engine is switched off: this library does the zooming and the bop
			defaultZoom = game.defaultCamZoom;
			decay = game.camZoomingDecay;
			game.camZoomingMult = 0;
			game.camZoomingDecay = 0;
		}
		var m:Dynamic = ClientPrefs.getGameplaySetting('scrollspeed');
		scrollMultiplier = m == null ? 1 : m;
	}

	static function parts(text:String):Array<String>
		return [for (p in (text == null ? '' : text).split(',')) StringTools.trim(p)];

	static function steps(n:Float):Float
		return Conductor.stepCrochet * n / 1000;

	override function stepHit()
	{
		if (!customZoom) return;
		if (rate > 0 && ClientPrefs.data.camZooms && FlxG.camera.zoom < 1.35 && (curStep + (rateOffset * 4)) % (rate * 4) == 0)
		{
			zoomMult += 0.015 * intensity;
			game.camHUD.zoom += 0.03 * intensity;
		}
	}

	override function update(elapsed:Float)
	{
		if (!customZoom) return;
		if (((game.startedCountdown == true && game.endingSong == false) || cutsceneMode) && rate > 0)
		{
			var k = Math.exp(-elapsed * 3.125 * decay * game.playbackRate);
			zoomMult = FlxMath.lerp(1, zoomMult, k);
			FlxG.camera.zoom = game.defaultCamZoom * zoomMult;
			game.camHUD.zoom = FlxMath.lerp(1, game.camHUD.zoom, k);
		}
	}

	override function eventCalled(eventName:String, value1:String, value2:String, flValue1:Null<Float>, flValue2:Null<Float>, strumTime:Float)
	{
		switch (eventName)
		{
			case 'Set Camera Zoom': setZoom(value1, value2);
			case 'Set Camera Bop': setBop(value1, value2);
			case 'Set Camera Target': setTarget(value1, value2);
			case 'Set Scroll Speed': setScroll(value1, value2);
			case 'Add Camera Zoom':
				// the zoom the event adds goes through the same smoothing as the bops
				if (customZoom && ClientPrefs.data.camZooms && FlxG.camera.zoom < 1.35)
					zoomMult += flValue1 == null ? 0.015 : flValue1;
		}
	}

	function setZoom(v1:String, v2:String)
	{
		if (zoomTween != null) zoomTween.cancel();
		var z = parts(v1);
		var target = Std.parseFloat(z[0]);
		if (Math.isNaN(target)) return;
		if (z.length > 1 && z[1] == 'stage') target *= defaultZoom;

		var t = parts(v2);
		var n = Std.parseFloat(t[0]);
		if (t[0] == '' || Math.isNaN(n) || n <= 0) { game.defaultCamZoom = target; return; }
		var duration = cutsceneMode ? n : steps(n);
		zoomTween = FlxTween.tween(game, {defaultCamZoom: target}, duration, {ease: LuaUtils.getTweenEaseByString(t.length > 1 ? t[1] : 'linear')});
	}

	function setBop(v1:String, v2:String)
	{
		var r = parts(v1);
		rate = r[0] == '' ? 4 : Std.parseFloat(r[0]);
		if (Math.isNaN(rate)) rate = 4;
		rateOffset = r.length > 1 ? Std.parseFloat(r[1]) : 0;
		if (Math.isNaN(rateOffset)) rateOffset = 0;
		intensity = StringTools.trim(v2 == null ? '' : v2) == '' ? 1 : Std.parseFloat(v2);
		if (Math.isNaN(intensity)) intensity = 1;
	}

	function setTarget(v1:String, v2:String)
	{
		if (camTween != null) { camTween.cancel(); camTween = null; }
		var sec = game.SONG.notes[game.curSection];
		if (StringTools.trim(v1 == null ? '' : v1) == '')
		{
			// back to the camera of the sections
			game.isCameraOnForcedPos = false;
			FlxG.camera.target = game.camFollow;
			var isDad = !(sec != null && (sec.gfSection == true || sec.mustHitSection == true));
			game.moveCamera(isDad);
			return;
		}
		game.isCameraOnForcedPos = true;

		var d = parts(v1);
		var who = d[0].toLowerCase();
		var x:Float = 0;
		var y:Float = 0;
		if (who == '0' || who == 'bf' || who == 'boyfriend')
		{
			var c = game.boyfriend;
			x = c.getMidpoint().x - c.cameraPosition[0] + game.boyfriendCameraOffset[0] - 100;
			y = c.getMidpoint().y + c.cameraPosition[1] + game.boyfriendCameraOffset[1] - 100;
		}
		else if (who == '1' || who == 'dad' || who == 'opponent')
		{
			var c = game.dad;
			x = c.getMidpoint().x + c.cameraPosition[0] + game.opponentCameraOffset[0] + 150;
			y = c.getMidpoint().y + c.cameraPosition[1] + game.opponentCameraOffset[1] - 100;
		}
		else if (who == '2' || who == 'gf' || who == 'girlfriend')
		{
			var c = game.gf;
			x = c.getMidpoint().x + c.cameraPosition[0] + game.girlfriendCameraOffset[0];
			y = c.getMidpoint().y + c.cameraPosition[1] + game.girlfriendCameraOffset[1];
		}
		if (d.length > 1) { var dx = Std.parseFloat(d[1]); if (!Math.isNaN(dx)) x += dx; }
		if (d.length > 2) { var dy = Std.parseFloat(d[2]); if (!Math.isNaN(dy)) y += dy; }

		var t = parts(v2);
		if (t[0] == '')
		{
			FlxG.camera.target = game.camFollow;
			game.camFollow.x = x;
			game.camFollow.y = y;
		}
		else if (t[0] == '0')
		{
			FlxG.camera.target = game.camFollow;
			game.camFollow.x = x;
			game.camFollow.y = y;
			FlxG.camera.snapToTarget();
		}
		else
		{
			FlxG.camera.target = null;
			game.camFollow.x = x - FlxG.width / 2;
			game.camFollow.y = y - FlxG.height / 2;
			var n = Std.parseFloat(t[0]);
			var duration = cutsceneMode ? n : steps(n);
			camTween = FlxTween.tween(FlxG.camera.scroll, {x: game.camFollow.x, y: game.camFollow.y}, duration, {ease: LuaUtils.getTweenEaseByString(t.length > 1 ? t[1] : 'linear')});
		}
	}

	function setScroll(v1:String, v2:String)
	{
		if (game.songSpeedType == 'constant') return;
		if (scrollTween != null) scrollTween.cancel();
		var s = parts(v1);
		var t = parts(v2);
		var value = (s[0] == '') ? 1 : Std.parseFloat(s[0]);
		var target = (s.length > 1 && s[1] == 'absolute') ? value * scrollMultiplier : value * game.SONG.speed * scrollMultiplier;
		var n = (t[0] == '') ? 0 : Std.parseFloat(t[0]);
		if (Math.isNaN(n) || n <= 0) { game.songSpeed = target; return; }
		scrollTween = FlxTween.tween(game, {songSpeed: target}, steps(n), {ease: LuaUtils.getTweenEaseByString(t.length > 1 ? t[1] : 'linear')});
	}
}
