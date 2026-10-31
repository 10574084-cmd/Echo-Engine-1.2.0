/**
 * Native port, step 2b: does Haxe code (compiled to C++ by hxcpp) run on the PS4?
 * It uses the parts of the Haxe standard library the game relies on: arrays, maps, strings, JSON, math, classes, closures.
 * Every step shows a notification on the console screen, so if the program stops, the last number says where.
 */
@:cppInclude("ps4glue.h")
class Main
{
	static function notify(text:String):Void
		untyped __cpp__("echo_notify({0}.utf8_str())", text);

	static function main()
	{
		notify("[1] Haxe main() started");

		var steps = new Array<String>();

		var a = [5, 3, 9, 1];
		a.sort(function(x, y) return x - y);
		steps.push("sort=" + a.join(","));
		notify("[2] array + sort ok");

		var m = new Map<String, Int>();
		for (i in 0...100) m.set("k" + i, i * i);
		steps.push("map=" + m.get("k12"));
		notify("[3] map ok");

		var j:Dynamic = haxe.Json.parse('{"name":"echo","list":[1,2,3]}');
		steps.push("json=" + j.name + j.list.length);
		notify("[4] json ok");

		var sb = new StringBuf();
		for (i in 0...5) sb.add(Std.string(i * 1.5) + ";");
		steps.push("str=" + sb.toString());
		notify("[5] strings ok");

		var objs = [for (i in 0...20000) {id: i, text: "n" + i}];
		steps.push("alloc=" + objs.length);
		objs = null;
		notify("[6] allocation ok");

		steps.push("math=" + Math.round(Math.sqrt(2) * 1000));
		cpp.vm.Gc.run(true);
		steps.push("gc=ok");
		notify("[7] garbage collector ok");

		notify("Haxe OK: " + steps.join(" | "));
		notify("Waiting here. Close with the PS button");
		untyped __cpp__("echo_hang()");
	}
}
