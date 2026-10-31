// Small gaps between hxcpp / libc++ and the OpenOrbis C library.
#include "ps4glue.h"

extern "C" {
	// libc++abi asks for this to run destructors of thread_local objects when a thread ends. Not needed here.
	int __cxa_thread_atexit_impl(void (*dtor)(void *), void *obj, void *dso_symbol)
	{
		(void)dtor; (void)obj; (void)dso_symbol;
		return 0;
	}
}

#ifdef ECHO_LINKONLY
// test C: everything of hxcpp is linked in, but nothing of it is started
extern "C" void __hxcpp_main() {}
extern "C" void __hxcpp_lib_main() {}
int main(void)
{
	echo_notify("C ok: the program with all of hxcpp inside loaded (hxcpp not started)");
	echo_hang();
	return 0;
}
#endif
