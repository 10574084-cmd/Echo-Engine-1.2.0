package echo;

/**
 * Classes that Lua mods create by name (createInstance / Type.resolveClass) but that nothing in the engine itself uses.
 * Referencing them here keeps them in the build; without it a mod asking for one gets "null" on the web.
 */
@:keep
class EchoKeep
{
	static var classes:Array<Class<Dynamic>> = [
		flixel.addons.display.FlxPieDial,
		flixel.addons.text.FlxTypeText,
		flixel.addons.display.FlxBackdrop,
		flixel.addons.display.FlxGridOverlay,
		flixel.addons.effects.FlxTrail,
		flixel.effects.FlxFlicker,
		flixel.text.FlxBitmapText,
		flixel.util.FlxGradient,
	];

	public static function touch():Int return classes.length;
}
