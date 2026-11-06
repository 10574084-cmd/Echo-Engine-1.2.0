package echo;

#if html5
import js.Syntax;

/**
 * Sound levels for the bars of the speaker (Abot) of Nene: 7 bars, each one 0..1. It listens to everything that goes out of the game
 * with a Web Audio analyser (the original uses a native FFT that does not exist in the browser). Works the same as FunkinVis'
 * SpectralAnalyzer: bars are spaced by frequency on a log scale, the level is read in decibels and falls slowly.
 */
class EchoVisualizer
{
	static var analyser:Dynamic = null;
	static var data:Dynamic = null;
	static var levels:Array<Float> = [0, 0, 0, 0, 0, 0, 0];
	static var ranges:Array<Array<Int>> = [];
	static var failed:Bool = false;

	static inline var BARS:Int = 7;
	static inline var MIN_DB:Float = -65;
	static inline var MAX_DB:Float = -25;
	static inline var MAX_DELTA:Float = 0.1; // how much a bar may fall in one frame

	public static var active(default, null):Bool = false;

	public static function start():Void
	{
		active = true;
		if (analyser != null || failed) return;
		try
		{
			var ctx:Dynamic = Syntax.code("(window.Howler && window.Howler.ctx) ? window.Howler.ctx : null");
			var master:Dynamic = Syntax.code("(window.Howler && window.Howler.masterGain) ? window.Howler.masterGain : null");
			if (ctx == null || master == null) { failed = true; return; }
			analyser = ctx.createAnalyser();
			analyser.fftSize = 2048;
			analyser.smoothingTimeConstant = 0.5;
			master.connect(analyser); // only listens: the analyser has no output
			data = Syntax.code("new Float32Array({0}.frequencyBinCount)", analyser);

			// frequency of every bar: 50 Hz .. 16 kHz, log spaced
			var rate:Float = ctx.sampleRate;
			var binHz:Float = rate / 2048;
			var lo:Float = 50, hi:Float = 16000;
			ranges = [];
			for (i in 0...BARS)
			{
				var a:Float = lo * Math.pow(hi / lo, i / BARS);
				var b:Float = lo * Math.pow(hi / lo, (i + 1) / BARS);
				var from:Int = Std.int(Math.max(1, Math.floor(a / binHz)));
				var to:Int = Std.int(Math.max(from, Math.ceil(b / binHz) - 1));
				ranges.push([from, to]);
			}
		}
		catch (e:Dynamic)
		{
			trace('Echo visualizer: no analyser ($e)');
			failed = true;
			analyser = null;
		}
	}

	public static function stop():Void
	{
		active = false;
		for (i in 0...BARS) levels[i] = 0;
	}

	/** Reads the sound and returns the 7 levels. */
	public static function read():Array<Float>
	{
		if (!active || analyser == null) return levels;
		analyser.getFloatFrequencyData(data);
		for (i in 0...BARS)
		{
			var peak:Float = -200;
			var r = ranges[i];
			for (k in r[0]...r[1] + 1)
			{
				var v:Float = Syntax.code("{0}[{1}]", data, k);
				if (v > peak) peak = v;
			}
			var value:Float = (peak - MIN_DB) / (MAX_DB - MIN_DB);
			value = value < 0 ? 0 : (value > 1 ? 1 : value);
			levels[i] = value > levels[i] ? value : Math.max(value, levels[i] - MAX_DELTA);
		}
		return levels;
	}
}
#end
