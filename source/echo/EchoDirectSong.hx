package echo;

#if html5
import js.Browser;

/**
 * Developer shortcut for the web build: open the page with `?autosong=bopeebo-(pico-mix)` and the game goes straight into that song
 * (installing Pico Mix first when the song belongs to it), without walking through the menus.
 */
class EchoDirectSong
{
	/** window.echoDebug() in the browser console: a short report of the song screen (for finding why something does not show). */
	@:expose('echoDebug')
	public static function debug():String
	{
		var g = states.PlayState.instance;
		if (g == null) return 'no PlayState';
		var out:Array<String> = [];
		out.push('countdown=${g.startedCountdown} paused=${g.paused} songPos=${backend.Conductor.songPosition}');
		out.push('health=${g.health} isDead=${g.isDead} subState=${g.subState == null ? "none" : Type.getClassName(Type.getClass(g.subState))} persistentDraw=${g.persistentDraw} persistentUpdate=${g.persistentUpdate}');
		for (c in flixel.FlxG.cameras.list)
			out.push('cam alpha=${c.alpha} visible=${c.visible} zoom=${c.zoom} scroll=${c.scroll.x},${c.scroll.y} filters=${c.filters == null ? 0 : c.filters.length} members=${c.bgColor}');
		out.push('boyfriend visible=${g.boyfriend.visible} alpha=${g.boyfriend.alpha} x=${g.boyfriend.x} y=${g.boyfriend.y} shader=${g.boyfriend.shader != null} cams=${g.boyfriend.cameras.length}');
		out.push('healthBar visible=${g.healthBar.visible} alpha=${g.healthBar.alpha} cams=${g.healthBar.cameras.length}');
		out.push('uiGroup visible=${g.uiGroup.visible} alpha=${g.uiGroup.alpha} members=${g.uiGroup.length}');
		out.push('strums=${g.strumLineNotes.length} notes=${g.notes.length} luaScripts=${g.luaArray.length}');
		if (g.playerStrums.members.length > 0) out.push('playerStrum0 visible=${g.playerStrums.members[0].visible} alpha=${g.playerStrums.members[0].alpha} x=${g.playerStrums.members[0].x} y=${g.playerStrums.members[0].y}');
		for (c in [g.boyfriend, g.dad, g.gf])
			if (c != null)
				out.push('anim ${c.curCharacter}: ${c.animation.curAnim == null ? "none" : c.animation.curAnim.name + "#" + c.animation.curAnim.curFrame + (c.animation.curAnim.finished ? " finished" : "") + (c.animation.paused ? " PAUSED" : "")} frames=${c.frames == null ? "null" : Std.string(c.frames.numFrames)} specialAnim=${c.specialAnim} skipDance=${c.skipDance} update=${c.active} timeScale=${flixel.FlxG.animationTimeScale}');
		out.push('members=${g.members.length}');
		for (m in g.members)
		{
			var sp:flixel.FlxSprite = Std.isOfType(m, flixel.FlxSprite) ? cast m : null;
			if (sp != null && Std.isOfType(sp, objects.BGSprite))
				out.push('stage ${sp.graphic == null ? "NO-GRAPHIC" : sp.graphic.key} pos=${sp.x},${sp.y} size=${sp.frameWidth}x${sp.frameHeight} scroll=${sp.scrollFactor.x} visible=${sp.visible}');
		}
		for (k in g.modchartSprites.keys())
		{
			var sp = g.modchartSprites.get(k);
			out.push('lua sprite $k visible=${sp.visible} alpha=${sp.alpha} pos=${sp.x},${sp.y} size=${sp.width}x${sp.height} frame=${sp.frameWidth}x${sp.frameHeight} shader=${sp.shader != null} gfx=${sp.graphic == null ? "null" : (sp.graphic.bitmap == null ? "nobitmap" : sp.graphic.bitmap.width + "x" + sp.graphic.bitmap.height)} cams=${sp.cameras.length} onScreen=${sp.isOnScreen(g.camGame)}');
		}
		return out.join('\n');
	}

	public static function check():Void
	{
		var query:String = Browser.location.search;
		var marker = 'autosong=';
		var at = query.indexOf(marker);
		if (at < 0) return;

		var song = StringTools.urlDecode(query.substr(at + marker.length).split('&')[0]);
		if (song == '') return;

		var mod:String = StringTools.endsWith(song, '(pico-mix)') ? EchoBuiltin.PICO : null;
		var modAt = query.indexOf('mod='); // &mod=<folder>: a mod that was imported by hand
		if (modAt >= 0) mod = StringTools.urlDecode(query.substr(modAt + 4).split('&')[0]);
		if (mod == EchoBuiltin.PICO && !EchoBuiltin.installed(mod))
			EchoBuiltin.install(mod, function(ok:Bool, message:String) if (ok) start(song, mod) else trace('autosong: $message'));
		else
			start(song, mod);
	}

	static function start(song:String, mod:String):Void
	{
		backend.Mods.updatedOnState = false;
		if (mod != null) backend.Mods.currentModDirectory = mod;
		backend.Mods.pushGlobalMods();
		if (flixel.FlxG.sound.music == null) flixel.FlxG.sound.playMusic(backend.Paths.music('freakyMenu'), 0); // the menus always have it; songs expect it
		backend.Difficulty.resetList();
		backend.WeekData.reloadWeekFiles(false);
		// extra switches for tests: &bot=1 (botplay), &mobilehud=1, &scripts=0
		var query:String = Browser.location.search;
		if (query.indexOf('bot=1') >= 0) ClientPrefs.data.gameplaySettings.set('botplay', true);
		if (query.indexOf('mobilehud=1') >= 0) ClientPrefs.data.mobileHud = true;
		if (query.indexOf('scripts=0') >= 0) ClientPrefs.data.modScripts = false;
		try
		{
			states.PlayState.SONG = backend.Song.loadFromJson(song, song);
			states.PlayState.isStoryMode = false;
			states.PlayState.storyDifficulty = 1;
			states.LoadingState.loadAndSwitchState(new states.PlayState());
		}
		catch (e:Dynamic)
		{
			trace('autosong: could not open "$song": $e');
		}
	}
}
#end
