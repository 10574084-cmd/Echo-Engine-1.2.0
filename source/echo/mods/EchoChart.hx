package echo.mods;

/**
 * The chart in Echo format, written by the chart editor (and the way back of EchoModLoader.chartToPsych):
 *
 *   { "bpm", "speed", "stage", "player", "opponent", "girlfriend", "needsVoices", "offset",
 *     "notes":  [ { "t": ms, "lane": 0-7, "len": ms, "type": "" } ],        lanes 0-3 are the player's, 4-7 the opponent's
 *     "events": [ { "t": ms, "name": "camera.target", "args": { ... } } ] }
 *
 * It is plain JSON, so any editor can open it. The camera of each section is an event ("camera.target"), a change of tempo is
 * an event ("gameplay.bpm"), and the events the engine knows get their Echo names (camera.zoom, char.anim...); every other event
 * keeps its own name and its two values as "v1" / "v2".
 */
class EchoChart
{
	static inline function r(v:Float):Float
		return Math.round(v * 1000) / 1000;

	/** `song` is the chart of the editor / the game (SwagSong shaped: notes in sections, events as [time, [[name, v1, v2]]]). */
	public static function fromSong(song:Dynamic):Dynamic
	{
		var bpm:Float = song.bpm;
		var sections:Array<Dynamic> = song.notes;
		var notes:Array<Dynamic> = [];
		var events:Array<Dynamic> = [];

		var t:Float = 0;
		var curBpm = bpm;
		var lastWho = '';
		for (sec in sections)
		{
			var beats:Float = sec.sectionBeats != null ? sec.sectionBeats : 4;
			if (sec.changeBPM == true && sec.bpm != null && sec.bpm != curBpm)
			{
				curBpm = sec.bpm;
				events.push({t: r(t), name: 'gameplay.bpm', args: {bpm: curBpm}});
			}
			var who = sec.gfSection == true ? 'gf' : (sec.mustHitSection == true ? 'bf' : 'dad');
			if (who != lastWho) { events.push({t: r(t), name: 'camera.target', args: {who: who}}); lastWho = who; }

			var mustHit:Bool = sec.mustHitSection == true;
			for (n in (sec.sectionNotes : Array<Dynamic>))
			{
				var data = Std.int(n[1]);
				var isPlayer = (data < 4) == mustHit;
				var note:Dynamic = {t: r(n[0]), lane: (data % 4) + (isPlayer ? 0 : 4), len: r(n[2] == null ? 0 : n[2])};
				if (n.length > 3 && n[3] != null && Std.string(n[3]) != '' && !Std.isOfType(n[3], Int)) note.type = Std.string(n[3]);
				notes.push(note);
			}
			t += beats * 60000 / curBpm;
		}
		notes.sort(function(a, b) return Reflect.compare(a.t, b.t));

		var psychEvents:Array<Dynamic> = song.events == null ? [] : song.events;
		for (e in psychEvents)
		{
			var inner:Array<Dynamic> = e[1];
			for (ev in inner)
				events.push({t: r(e[0]), name: eventName(ev[0]), args: eventArgs(ev[0], Std.string(ev[1]), Std.string(ev[2]))});
		}
		events.sort(function(a, b) return Reflect.compare(a.t, b.t));

		return {
			bpm: bpm,
			speed: song.speed,
			stage: song.stage,
			player: song.player1,
			opponent: song.player2,
			girlfriend: song.gfVersion,
			needsVoices: song.needsVoices,
			offset: song.offset == null ? 0 : song.offset,
			notes: notes,
			events: events
		};
	}

	static function eventName(psych:String):String
	{
		return switch (psych)
		{
			case 'Camera Follow Pos': 'camera.target';
			case 'Add Camera Zoom': 'camera.zoom';
			case 'Screen Shake': 'camera.shake';
			case 'Play Animation': 'char.anim';
			case 'Hey!': 'char.hey';
			case 'Change Character': 'char.change';
			case 'Change Scroll Speed': 'gameplay.speed';
			case 'Set GF Speed': 'gameplay.gfspeed';
			case 'Play Sound': 'sound.play';
			default: psych;
		}
	}

	static function who(v:String):String
		return switch (v.toLowerCase())
		{
			case '0' | 'bf' | 'boyfriend': 'bf';
			case '1' | 'dad' | 'opponent': 'dad';
			case '2' | 'gf' | 'girlfriend': 'gf';
			default: v;
		}

	static function eventArgs(psych:String, v1:String, v2:String):Dynamic
	{
		if (v1 == 'null') v1 = '';
		if (v2 == 'null') v2 = '';
		return switch (psych)
		{
			case 'Camera Follow Pos':
				var x = Std.parseFloat(v1), y = Std.parseFloat(v2);
				{x: Math.isNaN(x) ? 0 : x, y: Math.isNaN(y) ? 0 : y};
			case 'Add Camera Zoom':
				{mode: 'add', zoom: v1 == '' ? 0.015 : Std.parseFloat(v1), hud: v2 == '' ? 0.03 : Std.parseFloat(v2)};
			case 'Screen Shake':
				var a = v1.split(','), b = a.length > 1 ? Std.parseFloat(a[1]) : 0.02;
				{duration: Std.parseFloat(a[0]), intensity: b};
			case 'Play Animation': {anim: v1, who: who(v2)};
			case 'Hey!': {who: v1.toLowerCase() == 'both' ? 'dad' : who(v1), duration: v2 == '' ? 0.6 : Std.parseFloat(v2)};
			case 'Change Character': {who: who(v1), to: v2};
			case 'Change Scroll Speed': {speed: Std.parseFloat(v1), duration: v2 == '' ? 0 : Std.parseFloat(v2)};
			case 'Set GF Speed': {speed: Std.parseFloat(v1)};
			case 'Play Sound': {id: v1, volume: v2 == '' ? 1 : Std.parseFloat(v2)};
			default: {v1: v1, v2: v2};
		}
	}

	/** The text of the file: readable (one note or event per line) and valid JSON. */
	public static function toText(chart:Dynamic):String
	{
		var b = new StringBuf();
		b.add('{\n');
		for (k in ['bpm', 'speed', 'stage', 'player', 'opponent', 'girlfriend', 'needsVoices', 'offset'])
			b.add('\t' + haxe.Json.stringify(k) + ': ' + haxe.Json.stringify(Reflect.field(chart, k)) + ',\n');
		b.add('\t"notes": [\n');
		var notes:Array<Dynamic> = chart.notes;
		b.add([for (n in notes) '\t\t' + haxe.Json.stringify(n)].join(',\n'));
		b.add('\n\t],\n\t"events": [\n');
		var events:Array<Dynamic> = chart.events;
		b.add([for (e in events) '\t\t' + haxe.Json.stringify(e)].join(',\n'));
		b.add('\n\t]\n}\n');
		return b.toString();
	}
}
