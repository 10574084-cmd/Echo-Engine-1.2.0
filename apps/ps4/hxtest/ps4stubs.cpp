// Small gaps between hxcpp / libc++ and the OpenOrbis C library, and a first sign of life.
#include "ps4glue.h"

extern "C" {
	// libc++abi asks for this to run destructors of thread_local objects when a thread ends. Not needed here.
	int __cxa_thread_atexit_impl(void (*dtor)(void *), void *obj, void *dso_symbol)
	{
		(void)dtor; (void)obj; (void)dso_symbol;
		return 0;
	}
}

// runs before main(): proves that the program was loaded and that C++ static initialisation works
struct EchoSignOfLife
{
	EchoSignOfLife() { echo_notify("[0] C++ loaded (before main)"); }
};
static EchoSignOfLife echoSignOfLife;
