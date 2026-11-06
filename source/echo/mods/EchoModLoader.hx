package echo.mods;

import haxe.Json;
import haxe.io.Bytes;

typedef EchoReport =
{
	/** What was read and translated (one line each, for the import message / the validator). */
	var converted:Array<String>;
	/** Problems that do not stop the mod (a missing image, an unknown event...). */
	var warnings:Array<String>;
	/** Songs of the mod, by folder name. */
	var songs:Array<String>;
}

/**
 * Echo Mods, phase 1: reads a mod written in the Echo structure (see ECHO_MODS.md) and adds the files that the game engine
 * already understands next to it. It works on a plain map of "relative path -> bytes", so the same code runs when a .zip is
 * imported, in the validator and in the tests.
 *
 *   mod.js | mod.json            ->  pack.json
 *   characters/<id>.js|json      ->  characters/<id>.json (+ images/characters/...)
 *   charts/<song>/<diff>.js|json ->  data/<song>/<song>-<diff>.json   (camera events become the sections' camera)
 *   songs/<song>/...             ->  songs/<song>/...                 (audio as it is)
 *   stages/<id>.js|json          ->  stages/<id>.json (+ the layers, drawn by EchoStage)
 *   weeks/weeks.js|json (+songs) ->  weeks/<id>.json
 *   images/, fonts/, sounds/, music/ stay where they are (same names as the engine).
 *
 * The original Echo files stay in the mod. Events that exist in the engine run natively (no scripts).
 */
class EchoModLoader
{
	public static function isEchoMod(files:Map<String, Bytes>):Bool
		return files.exists('mod.js') || files.exists('mod.json');

	// ------------------------------------------------------------------------------------------------------------------
	// Entry point
	// ------------------------------------------------------------------------------------------------------------------

	public static function process(files:Map<String, Bytes>):EchoReport
	{
		var report:EchoReport = {converted: [], warnings: [], songs: []};
		var warn = function(m:String) report.warnings.push(m);

		var ctx = new Ctx(files, report);

		var meta:Dynamic = ctx.data('mod');
		if (meta == null) { warn('mod.js / mod.json is missing or unreadable'); meta = {}; }
		writePack(ctx, meta);

		convertCharacters(ctx);
		convertIcons(ctx);
		convertStages(ctx);
		convertSongs(ctx);
		convertCharts(ctx);
		convertWeeks(ctx);

		checkReferences(ctx);
		return report;
	}

	// ------------------------------------------------------------------------------------------------------------------
	// mod.js
	// ------------------------------------------------------------------------------------------------------------------

	static function writePack(ctx:Ctx, meta:Dynamic):Void
	{
		var color:Array<Int> = rgb(Reflect.field(meta, 'color'), [170, 0, 255]);
		var pack:Dynamic = {
			name: str(Reflect.field(meta, 'name'), 'Echo mod'),
			description: str(Reflect.field(meta, 'description'), ''),
			color: color,
			restart: false,
			runsGlobally: Reflect.field(meta, 'runsGlobally') == true
		};
		ctx.writeJson('pack.json', pack);
		ctx.report.converted.push('mod: ' + pack.name);
	}

	// ------------------------------------------------------------------------------------------------------------------
	// Characters
	// ------------------------------------------------------------------------------------------------------------------

	static function convertCharacters(ctx:Ctx):Void
	{
		for (id in ctx.dataIds('characters'))
		{
			var c:Dynamic = ctx.data('characters/$id');
			if (c == null) continue;

			var images:Array<String> = [for (x in list(Reflect.field(c, 'image'), [id])) Std.string(x)];
			var anims:Array<Dynamic> = [];
			for (a in (cast list(Reflect.field(c, 'anims'), []) : Array<Dynamic>))
			{
				var name = str(Reflect.field(a, 'name'), '');
				if (name == '') { ctx.warn('characters/$id: an animation has no name'); continue; }
				anims.push({
					anim: name,
					name: str(Reflect.field(a, 'prefix'), name),
					fps: num(Reflect.field(a, 'fps'), 24),
					loop: Reflect.field(a, 'loop') == true,
					indices: list(Reflect.field(a, 'indices'), []),
					offsets: pair(Reflect.field(a, 'offset'), [0, 0])
				});
			}
			if (anims.length == 0) ctx.warn('characters/$id: it has no animations');

			var psychImages:Array<String> = [];
			for (image in images)
			{
				var base = ctx.copyAtlas('characters/' + image, 'images/characters/' + image) || ctx.files.exists('images/characters/' + image + '.png') || ctx.files.exists('images/characters/' + image + '/Animation.json');
				if (!base) ctx.warn('characters/$id: the image "$image" is not in the mod (characters/$image.png or .webp + .xml); the game\'s own copy is used if it has one');
				psychImages.push('characters/' + image);
			}

			ctx.writeJson('characters/$id.json', {
				animations: anims,
				vocals_file: str(Reflect.field(c, 'vocals'), ''),
				no_antialiasing: Reflect.field(c, 'antialiasing') == false,
				image: psychImages.join(', '),
				position: pair(Reflect.field(c, 'position'), [0, 0]),
				healthicon: str(Reflect.field(c, 'icon'), id),
				flip_x: Reflect.field(c, 'flipX') == true,
				healthbar_colors: rgb(Reflect.field(c, 'barColor'), [161, 161, 161]),
				camera_position: pair(Reflect.field(c, 'camera'), [0, 0]),
				sing_duration: num(Reflect.field(c, 'singDuration'), 4),
				scale: num(Reflect.field(c, 'scale'), 1)
			});
			ctx.report.converted.push('character: $id');
		}
	}

	/** images/health-icons/<name>.png -> images/icons/icon-<name>.png (the name the engine looks for). */
	static function convertIcons(ctx:Ctx):Void
	{
		var n = 0;
		for (path in ctx.pathsIn('images/health-icons'))
		{
			var low = path.toLowerCase();
			var ext = StringTools.endsWith(low, '.webp') ? '.webp' : (StringTools.endsWith(low, '.png') ? '.png' : null);
			if (ext == null) continue;
			var name = path.substr('images/health-icons/'.length);
			name = name.substr(0, name.length - ext.length);
			if (name.indexOf('/') >= 0) continue;
			if (!StringTools.startsWith(name, 'icon-')) name = 'icon-' + name;
			ctx.files.set('images/icons/' + name + '.png', ctx.files.get(path));
			n++;
		}
		if (n > 0) ctx.report.converted.push('health icons: $n');
	}

	// ------------------------------------------------------------------------------------------------------------------
	// Stages
	// ------------------------------------------------------------------------------------------------------------------

	static function convertStages(ctx:Ctx):Void
	{
		for (id in ctx.dataIds('stages'))
		{
			// a stage that already is in the engine's format (it has its own script, or Psych fields) stays exactly as it is
			if (ctx.files.exists('stages/$id.lua') || ctx.files.exists('stages/$id.hx')) { ctx.report.converted.push('stage: $id (kept with its script)'); continue; }
			var s:Dynamic = ctx.data('stages/$id');
			if (s == null) continue;
			if (Reflect.hasField(s, 'defaultZoom') || Reflect.hasField(s, 'boyfriend')) { ctx.report.converted.push('stage: $id (already in the engine format)'); continue; }

			var layers:Array<Dynamic> = [];
			for (l in (cast list(Reflect.field(s, 'layers'), []) : Array<Dynamic>))
			{
				var image = str(Reflect.field(l, 'image'), '');
				if (image == '') { ctx.warn('stages/$id: a layer has no image'); continue; }
				if (!ctx.copyAtlas('stages/images/' + image, 'images/echo-stages/' + image))
					ctx.warn('stages/$id: the image "$image" was not found (stages/images/$image.png or .webp)');
				var anim:Dynamic = Reflect.field(l, 'anim');
				layers.push({
					image: 'echo-stages/' + image,
					x: num(Reflect.field(l, 'x'), 0),
					y: num(Reflect.field(l, 'y'), 0),
					scale: num(Reflect.field(l, 'scale'), 1),
					scroll: pair(Reflect.field(l, 'scroll'), [1, 1]),
					alpha: num(Reflect.field(l, 'alpha'), 1),
					flipX: Reflect.field(l, 'flipX') == true,
					antialiasing: Reflect.field(l, 'antialiasing') != false,
					front: Reflect.field(l, 'front') == true,
					anim: anim
				});
			}

			var bf = pair(Reflect.field(s, 'bf'), [770, 100]);
			var dad = pair(Reflect.field(s, 'dad'), [100, 100]);
			var gf = pair(Reflect.field(s, 'gf'), [400, 130]);
			ctx.writeJson('stages/$id.json', {
				directory: '',
				defaultZoom: num(Reflect.field(s, 'zoom'), 0.9),
				isPixelStage: Reflect.field(s, 'pixel') == true,
				stageUI: Reflect.field(s, 'pixel') == true ? 'pixel' : 'normal',
				boyfriend: bf,
				girlfriend: gf,
				opponent: dad,
				hide_girlfriend: Reflect.field(s, 'hideGf') == true,
				camera_boyfriend: pair(Reflect.field(s, 'bfCamera'), [0, 0]),
				camera_opponent: pair(Reflect.field(s, 'dadCamera'), [0, 0]),
				camera_girlfriend: pair(Reflect.field(s, 'gfCamera'), [0, 0]),
				camera_speed: num(Reflect.field(s, 'cameraSpeed'), 1),
				echoLayers: layers
			});
			ctx.report.converted.push('stage: $id (${layers.length} layers)');
		}
	}

	// ------------------------------------------------------------------------------------------------------------------
	// Songs and charts
	// ------------------------------------------------------------------------------------------------------------------

	static function convertSongs(ctx:Ctx):Void
	{
		for (folder in ctx.folders('songs'))
		{
			ctx.report.songs.push(folder);
			var audio = 0;
			for (path in ctx.pathsIn('songs/$folder'))
			{
				var low = path.toLowerCase();
				if (StringTools.endsWith(low, '.ogg') || StringTools.endsWith(low, '.mp3') || StringTools.endsWith(low, '.m4a') || StringTools.endsWith(low, '.wav'))
					audio++;
			}
			if (audio == 0) ctx.warn('songs/$folder: it has no audio (Inst.ogg / .m4a / .mp3)');
			ctx.report.converted.push('song: $folder ($audio audio files)');
		}
	}

	static function convertCharts(ctx:Ctx):Void
	{
		for (song in ctx.folders('charts'))
		{
			var songMeta:Dynamic = ctx.data('songs/$song/song');
			for (diff in ctx.dataIds('charts/$song'))
			{
				var chart:Dynamic = ctx.data('charts/$song/$diff');
				if (chart == null) continue;

				var out = chartToPsych(ctx, song, diff, chart, songMeta);
				var file = diff.toLowerCase() == 'normal' ? 'data/$song/$song.json' : 'data/$song/$song-' + diff.toLowerCase() + '.json';
				ctx.writeJson(file, out);
				ctx.report.converted.push('chart: $song / $diff (${(cast out.notes : Array<Dynamic>).length} sections)');
			}
		}
	}

	/** Echo chart -> the chart format of the engine. Lanes 0-3 are the player's, 4-7 the opponent's; the camera comes from "camera.target" events. */
	public static function chartToPsych(ctx:Ctx, song:String, diff:String, chart:Dynamic, songMeta:Dynamic):Dynamic
	{
		var bpm:Float = num(Reflect.field(chart, 'bpm'), num(songMeta == null ? null : Reflect.field(songMeta, 'bpm'), 100));
		var beatsPerSection = 4;

		var notes:Array<Dynamic> = list(Reflect.field(chart, 'notes'), []);
		var events:Array<Dynamic> = list(Reflect.field(chart, 'events'), []);
		notes.sort(function(a, b) return Reflect.compare(num(Reflect.field(a, 't'), 0), num(Reflect.field(b, 't'), 0)));
		events.sort(function(a, b) return Reflect.compare(num(Reflect.field(a, 't'), 0), num(Reflect.field(b, 't'), 0)));

		// camera targets and bpm changes, by time
		var cameraAt:Array<{t:Float, who:String}> = [];
		var bpmAt:Array<{t:Float, bpm:Float}> = [];
		var psychEvents:Array<Dynamic> = [];
		for (e in events)
		{
			var t = num(Reflect.field(e, 't'), 0);
			var name = str(Reflect.field(e, 'name'), '');
			var args:Dynamic = Reflect.field(e, 'args');
			if (args == null) args = {};
			switch (name)
			{
				case 'camera.target':
					var who = str(Reflect.field(args, 'who'), 'dad').toLowerCase();
					var raw:String = Reflect.field(args, 'event');
					if (raw != null)
					{
						// the event keeps its own values: a script of the mod handles it (and the chart still learns which side the section is)
						psychEvents.push([t, [[raw, str(Reflect.field(args, 'v1'), ''), str(Reflect.field(args, 'v2'), '')]]]);
						cameraAt.push({t: t, who: who == 'boyfriend' ? 'bf' : (who == 'opponent' ? 'dad' : (who == 'girlfriend' ? 'gf' : who))});
					}
					else if (Reflect.field(args, 'x') != null || Reflect.field(args, 'y') != null)
						psychEvents.push([t, [['Camera Follow Pos', Std.string(num(Reflect.field(args, 'x'), 0)), Std.string(num(Reflect.field(args, 'y'), 0))]]]);
					else
						cameraAt.push({t: t, who: who == 'boyfriend' ? 'bf' : (who == 'opponent' ? 'dad' : (who == 'girlfriend' ? 'gf' : who))});
				case 'gameplay.bpm':
					bpmAt.push({t: t, bpm: num(Reflect.field(args, 'bpm'), bpm)});
				default:
					var mapped = mapEvent(ctx, name, args);
					if (mapped != null) psychEvents.push([t, [mapped]]);
			}
		}

		// sections
		var lastNote:Float = 0;
		for (n in notes) lastNote = Math.max(lastNote, num(Reflect.field(n, 't'), 0) + num(Reflect.field(n, 'len'), 0));
		var sections:Array<Dynamic> = [];
		var starts:Array<Float> = [];
		var curBpm = bpm;
		var t:Float = 0;
		var bi = 0;
		while (t <= lastNote + 1 || sections.length == 0)
		{
			var changeBPM = false;
			while (bi < bpmAt.length && bpmAt[bi].t <= t + 1)
			{
				if (bpmAt[bi].bpm != curBpm) { curBpm = bpmAt[bi].bpm; changeBPM = true; }
				bi++;
			}
			var who = 'dad';
			for (c in cameraAt) if (c.t <= t + 1) who = c.who;
			sections.push({
				sectionNotes: [],
				sectionBeats: beatsPerSection,
				mustHitSection: who == 'bf',
				gfSection: who == 'gf',
				changeBPM: changeBPM,
				bpm: curBpm,
				altAnim: false
			});
			starts.push(t);
			t += beatsPerSection * 60000 / curBpm;
		}

		for (n in notes)
		{
			var nt = num(Reflect.field(n, 't'), 0);
			var lane = Std.int(num(Reflect.field(n, 'lane'), 0));
			var index = 0;
			for (k in 0...starts.length) if (starts[k] <= nt + 1) index = k;
			var sec = sections[index];
			var isPlayer = lane < 4;
			var data = (lane % 4) + ((isPlayer == sec.mustHitSection) ? 0 : 4);
			var type = str(Reflect.field(n, 'type'), '');
			var item:Array<Dynamic> = [nt, data, num(Reflect.field(n, 'len'), 0)];
			if (type != '') item.push(type);
			sec.sectionNotes.push(item);
		}

		// the engine finds the audio and the chart by this name ("Bopeebo Pico Mix" -> bopeebo-pico-mix), so it comes from the folder, not from the title
		var title = songName(song);
		var needsVoices:Bool = Reflect.field(chart, 'needsVoices') != null ? Reflect.field(chart, 'needsVoices') == true : (songMeta == null || Reflect.field(songMeta, 'needsVoices') != false);
		return {
			song: title,
			notes: sections,
			events: psychEvents,
			bpm: bpm,
			needsVoices: needsVoices,
			speed: num(Reflect.field(chart, 'speed'), 1),
			player1: str(Reflect.field(chart, 'player'), 'bf'),
			player2: str(Reflect.field(chart, 'opponent'), 'dad'),
			gfVersion: str(Reflect.field(chart, 'girlfriend'), 'gf'),
			stage: str(Reflect.field(chart, 'stage'), 'stage'),
			offset: num(Reflect.field(chart, 'offset'), 0)
		};
	}

	/** Echo event -> [name, value1, value2] of the engine (events that the engine does not have are passed on by name). */
	static function mapEvent(ctx:Ctx, name:String, args:Dynamic):Array<String>
	{
		function s(field:String, fallback:String = ''):String
		{
			var v:Dynamic = Reflect.field(args, field);
			return v == null ? fallback : Std.string(v);
		}
		function who(field:String = 'who'):String
		{
			return switch (s(field, 'dad').toLowerCase())
			{
				case 'bf' | 'boyfriend' | 'player': 'bf';
				case 'gf' | 'girlfriend': 'gf';
				default: 'dad';
			}
		}
		return switch (name)
		{
			case 'camera.zoom':
				if (s('mode') == 'add') ['Add Camera Zoom', s('zoom', '0.015'), s('hud', '0.03')];
				else ['Set Property', 'defaultCamZoom', s('zoom', '1')];
			case 'camera.shake': ['Screen Shake', s('duration', '0.5') + ', ' + s('intensity', '0.02'), s('duration', '0.5') + ', ' + s('intensity', '0.02')];
			case 'char.anim': ['Play Animation', s('anim'), who()];
			case 'char.hey':
				var w = who();
				['Hey!', w == 'bf' ? 'BF' : (w == 'gf' ? 'GF' : 'Both'), s('duration', '0.6')];
			case 'char.change': ['Change Character', who(), s('to')];
			case 'gameplay.speed': ['Change Scroll Speed', s('speed', '1'), s('duration', '0')];
			case 'gameplay.gfspeed': ['Set GF Speed', s('speed', '1'), ''];
			case 'stage.set': ['Set Property', s('prop'), s('value')];
			case 'sound.play': ['Play Sound', s('id'), s('volume', '1')];
			case 'dialogue.start': null; // phase 3
			default:
				if (name.indexOf('.') >= 0 && name.indexOf(' ') < 0 && StringTools.startsWith(name, 'echo.')) null;
				else [name, s('v1', s('value1')), s('v2', s('value2'))];
		}
	}

	// ------------------------------------------------------------------------------------------------------------------
	// Weeks
	// ------------------------------------------------------------------------------------------------------------------

	static function convertWeeks(ctx:Ctx):Void
	{
		var weeksData:Dynamic = ctx.data('weeks/weeks');
		if (weeksData == null)
		{
			// no weeks file: every song of the mod goes in a week of its own, so the songs still show up in Freeplay
			if (ctx.report.songs.length > 0) autoWeek(ctx);
			return;
		}

		var weeks:Array<Dynamic> = Std.isOfType(weeksData, Array) ? weeksData : list(Reflect.field(weeksData, 'weeks'), []);
		var extra:Dynamic = ctx.data('weeks/songs');
		var extraSongs:Array<Dynamic> = extra == null ? [] : (Std.isOfType(extra, Array) ? extra : list(Reflect.field(extra, 'songs'), []));

		for (w in weeks)
		{
			var id = str(Reflect.field(w, 'id'), '');
			if (id == '') { ctx.warn('weeks: a week has no id'); continue; }

			var songs:Array<Dynamic> = list(Reflect.field(w, 'songs'), []);
			for (e in extraSongs) if (str(Reflect.field(e, 'week'), '') == id) songs.push(e);

			var rows:Array<Dynamic> = [];
			for (sg in songs)
			{
				var sid = Std.isOfType(sg, String) ? (cast sg : String) : str(Reflect.field(sg, 'id'), '');
				if (sid == '') continue;
				var icon = Std.isOfType(sg, String) ? 'face' : str(Reflect.field(sg, 'icon'), 'face');
				var color = Std.isOfType(sg, String) ? [146, 113, 253] : rgb(Reflect.field(sg, 'color'), [146, 113, 253]);
				rows.push([songName(sid), icon, color]);
				if (ctx.report.songs.indexOf(sid) < 0) ctx.warn('weeks/$id: the song "$sid" has no folder in songs/');
			}

			ctx.writeJson('weeks/$id.json', {
				songs: rows,
				weekCharacters: list(Reflect.field(w, 'characters'), ['', 'bf', 'gf']),
				weekBackground: str(Reflect.field(w, 'background'), 'stage'),
				weekBefore: str(Reflect.field(w, 'before'), 'tutorial'),
				storyName: str(Reflect.field(w, 'title'), id),
				weekName: str(Reflect.field(w, 'name'), str(Reflect.field(w, 'title'), id)),
				freeplayColor: rgb(Reflect.field(w, 'color'), [146, 113, 253]),
				startUnlocked: Reflect.field(w, 'locked') != true,
				hideStoryMode: Reflect.field(w, 'hideStory') == true,
				hideFreeplay: Reflect.field(w, 'hideFreeplay') == true,
				difficulties: str(Reflect.field(w, 'difficulties'), '')
			});
			ctx.report.converted.push('week: $id (${rows.length} songs)');
		}
	}

	static function autoWeek(ctx:Ctx):Void
	{
		var rows:Array<Dynamic> = [for (s in ctx.report.songs) [songName(s), 'face', [146, 113, 253]]];
		ctx.writeJson('weeks/echo-songs.json', {
			songs: rows,
			weekCharacters: ['', 'bf', 'gf'],
			weekBackground: 'stage',
			weekBefore: 'tutorial',
			storyName: 'Songs',
			weekName: 'Songs',
			freeplayColor: [146, 113, 253],
			startUnlocked: true,
			hideStoryMode: true,
			hideFreeplay: false,
			difficulties: ''
		});
		ctx.report.converted.push('week: echo-songs (${rows.length} songs, made automatically)');
	}

	/** The engine finds a song by its name ("Bopeebo (Pico Mix)" -> bopeebo-(pico-mix)), so the name shown is the folder name in words. */
	static function songName(id:String):String
	{
		var words = id.split('-');
		var out:Array<String> = [];
		for (w in words)
		{
			if (w.length == 0) { out.push(w); continue; }
			var at = (w.charAt(0) == '(') ? 1 : 0; // "(pico" -> "(Pico"
			out.push(w.substr(0, at) + w.charAt(at).toUpperCase() + w.substr(at + 1));
		}
		return out.join(' ');
	}

	// ------------------------------------------------------------------------------------------------------------------
	// Checks
	// ------------------------------------------------------------------------------------------------------------------

	static function checkReferences(ctx:Ctx):Void
	{
		for (song in ctx.folders('charts'))
			if (ctx.report.songs.indexOf(song) < 0)
				ctx.warn('charts/$song: there is no songs/$song folder with its audio');
	}

	// ------------------------------------------------------------------------------------------------------------------
	// Small value helpers
	// ------------------------------------------------------------------------------------------------------------------

	static function str(v:Dynamic, fallback:String):String
		return v == null ? fallback : Std.string(v);

	static function num(v:Dynamic, fallback:Float):Float
	{
		if (v == null) return fallback;
		if (Std.isOfType(v, Float) || Std.isOfType(v, Int)) return v;
		var f = Std.parseFloat(Std.string(v));
		return Math.isNaN(f) ? fallback : f;
	}

	static function list(v:Dynamic, fallback:Array<Dynamic>):Array<Dynamic>
	{
		if (v == null) return fallback;
		if (Std.isOfType(v, Array)) return v;
		return [v];
	}

	static function pair(v:Dynamic, fallback:Array<Float>):Array<Float>
	{
		if (v == null || !Std.isOfType(v, Array)) return fallback;
		var a:Array<Dynamic> = v;
		return [num(a[0], fallback[0]), num(a.length > 1 ? a[1] : null, fallback[1])];
	}

	/** "#RRGGBB", "RRGGBB" or [r, g, b]. */
	static function rgb(v:Dynamic, fallback:Array<Int>):Array<Int>
	{
		if (v == null) return fallback;
		if (Std.isOfType(v, Array))
		{
			var a:Array<Dynamic> = v;
			if (a.length < 3) return fallback;
			return [Std.int(num(a[0], 0)), Std.int(num(a[1], 0)), Std.int(num(a[2], 0))];
		}
		var text = StringTools.replace(Std.string(v), '#', '');
		if (text.length == 6)
		{
			var n = Std.parseInt('0x' + text);
			if (n != null) return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
		}
		return fallback;
	}
}

/** The files of one mod, with the lookups the converters need. */
class Ctx
{
	public var files:Map<String, Bytes>;
	public var report:EchoReport;

	public function new(files:Map<String, Bytes>, report:EchoReport)
	{
		this.files = files;
		this.report = report;
	}

	public function warn(message:String):Void
		report.warnings.push(message);

	/** Reads "<base>.json" or "<base>.js" (json first). null if there is none or it has a syntax error. */
	public function data(base:String):Dynamic
	{
		for (ext in ['.json', '.js'])
		{
			var bytes = files.get(base + ext);
			if (bytes == null) continue;
			return EchoData.tryParse(bytes.toString(), base + ext, warn);
		}
		return null;
	}

	/** Names (without extension) of the data files directly inside a folder. */
	public function dataIds(folder:String):Array<String>
	{
		var ids:Array<String> = [];
		var prefix = folder + '/';
		for (path in files.keys())
		{
			if (!StringTools.startsWith(path, prefix)) continue;
			var rest = path.substr(prefix.length);
			if (rest.indexOf('/') >= 0) continue;
			var low = rest.toLowerCase();
			var name:String = null;
			if (StringTools.endsWith(low, '.json')) name = rest.substr(0, rest.length - 5);
			else if (StringTools.endsWith(low, '.js')) name = rest.substr(0, rest.length - 3);
			if (name != null && ids.indexOf(name) < 0)
			{
				// an atlas ("frames") that sits next to the character is not a character
				if (StringTools.endsWith(low, '.json') && isAtlasJson(files.get(path))) continue;
				ids.push(name);
			}
		}
		ids.sort(Reflect.compare);
		return ids;
	}

	/** Sub-folders directly inside a folder. */
	public function folders(folder:String):Array<String>
	{
		var out:Array<String> = [];
		var prefix = folder + '/';
		for (path in files.keys())
		{
			if (!StringTools.startsWith(path, prefix)) continue;
			var rest = path.substr(prefix.length);
			var slash = rest.indexOf('/');
			if (slash < 0) continue;
			var name = rest.substr(0, slash);
			if (out.indexOf(name) < 0) out.push(name);
		}
		out.sort(Reflect.compare);
		return out;
	}

	public function pathsIn(folder:String):Array<String>
		return [for (path in files.keys()) if (StringTools.startsWith(path, folder + '/')) path];

	static function isAtlasJson(bytes:Bytes):Bool
	{
		if (bytes == null) return false;
		var text = bytes.length > 4000 ? bytes.getString(0, 4000) : bytes.toString();
		return text.indexOf('"frames"') >= 0 && text.indexOf('"meta"') >= 0;
	}

	public function writeJson(path:String, value:Dynamic):Void
		files.set(path, Bytes.ofString(Json.stringify(value, null, '\t')));

	/**
	 * Copies an image and its atlas ("<from>.png|.webp" + ".xml|.json|.txt") to "<to>...". A ".webp" is stored as ".png" (the browser
	 * converts it after the import, see EchoImages). Returns false when there is no image.
	 */
	public function copyAtlas(from:String, to:String):Bool
	{
		var found = false;
		for (ext in ['.png', '.webp'])
		{
			var bytes = files.get(from + ext);
			if (bytes == null) continue;
			files.set(to + '.png', bytes);
			found = true;
			break;
		}
		if (!found) return false;
		for (ext in ['.xml', '.txt', '.json'])
		{
			var extra = files.get(from + ext);
			if (extra == null) continue;
			if (ext == '.json' && !isAtlasJson(extra)) continue;
			files.set(to + ext, extra);
		}
		return true;
	}
}
