package substates;

import echo.EchoBuiltin;
import echo.EchoLang;

/**
 * Freeplay > TAB: which mixes to show. BF mixes = the normal songs, Pico mixes = the "(Pico Mix)" songs of the Pico Mix mod.
 * If Pico Mix is not installed yet, choosing it downloads it (it comes with the game).
 */
class EchoMixSubState extends MusicBeatSubstate
{
	static final CHOICES:Array<String> = ['BF Mixes', 'Pico Mixes', 'Everything'];
	static final VALUES:Array<String> = ['BF', 'Pico', 'All'];

	var bg:FlxSprite;
	var items:Array<Alphabet> = [];
	var info:FlxText;
	var cur:Int = 0;
	var working:Bool = false;

	public function new()
	{
		super();

		bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.alpha = 0;
		bg.scrollFactor.set();
		add(bg);

		var title:Alphabet = new Alphabet(0, 90, EchoLang.t('Which mixes?'), true);
		title.screenCenter(X);
		add(title);

		cur = Std.int(Math.max(0, VALUES.indexOf(ClientPrefs.data.echoMix)));
		for (i in 0...CHOICES.length)
		{
			var item:Alphabet = new Alphabet(0, 230 + i * 100, EchoLang.t(CHOICES[i]), true);
			item.screenCenter(X);
			items.push(item);
			add(item);
		}

		info = new FlxText(40, FlxG.height - 120, FlxG.width - 80, '', 22);
		info.setFormat(Paths.font('vcr.ttf'), 22, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		info.scrollFactor.set();
		add(info);

		updateItems();
	}

	function updateItems():Void
	{
		for (i in 0...items.length) items[i].alpha = (i == cur) ? 1 : 0.5;

		var hint:String = EchoLang.t('UP / DOWN: choose    ENTER: accept    BACK: cancel');
		if (VALUES[cur] != 'BF' && !EchoBuiltin.installed(EchoBuiltin.PICO))
			hint = EchoLang.t('Pico Mix is not installed yet: choosing this downloads it (about 160 MB).') + '\n' + hint;
		if (!working) info.text = hint;
	}

	override function update(elapsed:Float)
	{
		bg.alpha = Math.min(0.7, bg.alpha + elapsed * 2);

		if (working)
		{
			info.text = EchoBuiltin.status;
			super.update(elapsed);
			return;
		}

		if (controls.UI_UP_P || controls.UI_DOWN_P)
		{
			cur = (cur + (controls.UI_UP_P ? CHOICES.length - 1 : 1)) % CHOICES.length;
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.7);
			updateItems();
		}
		else if (controls.BACK)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'), 1);
			close();
		}
		else if (controls.ACCEPT)
		{
			var wanted:String = VALUES[cur];
			if (wanted != 'BF' && !EchoBuiltin.installed(EchoBuiltin.PICO))
			{
				working = true;
				EchoBuiltin.install(EchoBuiltin.PICO, function(ok:Bool, message:String)
				{
					working = false;
					if (ok) apply(wanted);
					else
					{
						FlxG.sound.play(Paths.sound('cancelMenu'), 1);
						info.text = message;
					}
				});
			}
			else apply(wanted);
		}

		super.update(elapsed);
	}

	function apply(value:String):Void
	{
		FlxG.sound.play(Paths.sound('confirmMenu'), 0.8);
		ClientPrefs.data.echoMix = value;
		ClientPrefs.saveSettings();
		MusicBeatState.resetState(); // Freeplay builds its list again
	}
}
