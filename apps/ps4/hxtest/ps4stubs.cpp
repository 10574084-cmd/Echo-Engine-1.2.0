// Small gaps between hxcpp / libc++ and the OpenOrbis C library.
extern "C" {
	// libc++abi asks for this to run destructors of thread_local objects when a thread ends. Not needed here.
	int __cxa_thread_atexit_impl(void (*dtor)(void *), void *obj, void *dso_symbol)
	{
		(void)dtor; (void)obj; (void)dso_symbol;
		return 0;
	}
}
