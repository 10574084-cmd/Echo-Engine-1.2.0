// Test B: the C++ runtime that hxcpp needs: static constructors, exceptions, std containers, thread_local.
#include "ps4glue.h"
#include <map>
#include <string>
#include <unistd.h>
#include <vector>

struct StaticThing
{
	StaticThing() { echo_notify("B1 ok: static constructor ran"); }
};
static StaticThing staticThing;
static thread_local int tls = 7;

extern "C" int __cxa_thread_atexit_impl(void (*)(void *), void *, void *) { return 0; }

int main(void)
{
	echo_notify("B2 ok: main() started");
	try
	{
		throw 42;
	}
	catch (int e)
	{
		echo_notify(("B3 ok: exception caught " + std::to_string(e)).c_str());
	}
	std::vector<std::string> v;
	std::map<std::string, int> m;
	for (int i = 0; i < 1000; i++) { v.push_back("n" + std::to_string(i)); m[v.back()] = i; }
	echo_notify(("B4 ok: containers " + std::to_string(m["n999"]) + " tls=" + std::to_string(tls)).c_str());
	echo_notify("B5 ok: waiting here. Close with the PS button");
	echo_hang();
	return 0;
}
