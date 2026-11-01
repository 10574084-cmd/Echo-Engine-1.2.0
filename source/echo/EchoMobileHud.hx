package echo;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxStringUtil;
import objects.Note;
import states.PlayState;

/**
 * Mobile HUD: a phone-friendly layout for the song screen (an option of Echo Engine, off by default).
 * Based on the "FNF Mobile HUD" mod by SoyKaity778 (credit to the author): the opponent's strums are hidden, yours move to
 * where thumbs reach (with downscroll the four strums are split in two pairs, one for each thumb), the score is a short
 * line, the time bar is hidden, the health bar is red/green and a pause button sits in the corner.
 * The original is a Lua script, which this web build cannot run, so this is a native re-creation of its main features.
 */
class EchoMobileHud
{
	public static inline var CREDIT:String = 'SoyKaity778';

	// positions of the original mod (1280x720)
	static final PAIRS_X:Array<Float> = [182, 402, 770, 977]; // downscroll: two strums per thumb
	static final CENTER_X:Array<Float> = [415, 527, 642, 755]; // the other cases: the four strums together in the middle

	var game:PlayState;
	var score:FlxText;
	var pauseButton:FlxSprite;
	var circle:FlxSprite;

	public static inline function enabled():Bool
		return ClientPrefs.data.mobileHud;

	public function new(game:PlayState)
	{
		this.game = game;
	}

	/** When the HUD of the song screen has been built. */
	public function create():Void
	{
		game.timeBar.visible = false;
		game.timeTxt.visible = false;
		game.scoreTxt.visible = false;

		score = new FlxText(780, ClientPrefs.data.downScroll ? 100 : 675.8, 0, 'Score: 0', 16);
		score.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
		score.borderSize = 1.25;
		score.scrollFactor.set();
		score.cameras = [game.camHUD];
		score.visible = !ClientPrefs.data.hideHud;
		game.add(score);

		circle = new FlxSprite(FlxG.width - 178, -10, Paths.image('mobilehud/pauseCircle'));
		circle.scale.set(1.1, 1.1);
		circle.updateHitbox();
		circle.alpha = 0.1;
		circle.scrollFactor.set();
		circle.cameras = [game.camOther];
		game.add(circle);

		pauseButton = new FlxSprite(FlxG.width - 131, 40);
		var atlas = Paths.getSparrowAtlas('mobilehud/pauseButton');
		if (atlas != null)
		{
			pauseButton.frames = atlas;
			pauseButton.animation.addByPrefix('press', 'pause', 24, false);
			pauseButton.animation.play('press', true);
			pauseButton.animation.pause(); // resting frame
		}
		else
			pauseButton.makeGraphic(100, 90, 0x66FFFFFF); // picture missing: a plain square still works as a button
		pauseButton.scale.set(0.8, 0.8);
		pauseButton.updateHitbox();
		pauseButton.scrollFactor.set();
		pauseButton.cameras = [game.camOther];
		game.add(pauseButton);

		updateScore();
	}

	/** Right after the strums were created. */
	public function arrows():Void
	{
		for (strum in game.opponentStrums) strum.visible = false;

		if (ClientPrefs.data.middleScroll) return;
		var down:Bool = ClientPrefs.data.downScroll;
		for (i in 0...game.playerStrums.length)
		{
			var strum = game.playerStrums.members[i];
			strum.x = (down ? PAIRS_X : CENTER_X)[i];
			strum.y = down ? 540 : 50;
		}
	}

	public function spawn(note:Note):Void
	{
		if (!note.mustPress) note.visible = false;
	}

	public function updateScore():Void
	{
		if (score == null) return;
		score.text = game.cpuControlled ? 'Enabled Botplay' : 'Score: ' + FlxStringUtil.formatMoney(game.songScore, false);
	}

	public function update(elapsed:Float):Void
	{
		if (pauseButton == null) return;

		var pressed:Bool = FlxG.mouse.justPressed && pauseButton.overlapsPoint(FlxG.mouse.getScreenPosition(game.camOther));
		for (touch in FlxG.touches.list)
			if (touch.justPressed && pauseButton.overlapsPoint(touch.getScreenPosition(game.camOther))) pressed = true;

		if (pressed && game.startedCountdown && game.canPause && !game.paused && !game.inCutscene)
		{
			if (pauseButton.animation.getByName('press') != null) pauseButton.animation.play('press', true);
			game.openPauseMenu();
		}
	}
}
