// FIRST object of the program (linked before everything else): its static constructor runs before hxcpp's own ones.
// It installs the crash reporter and shows [F]. The last object (zzz_last.cpp) shows [L] when all other static constructors survived.
#include "ps4glue.h"
#include <signal.h>
#include <unistd.h>

#ifndef SA_SIGINFO
#define SA_SIGINFO 0x0040 // the FreeBSD value
#endif

extern "C" {
	// a known place in the program: the crash report prints addresses relative to it, so they can be looked up in the build
	__attribute__((noinline)) void echo_anchor(void) { __asm__ volatile(""); }
}

// If the program crashes, say why on the screen: the signal, the address it touched and the callers (relative to echo_anchor).
static void echoCrash(int sig, siginfo_t *info, void *ctx)
{
	(void)ctx;
	char buf[900];
	long anchor = (long)&echo_anchor;
	int n = snprintf(buf, sizeof(buf), "CRASH sig=%d addr=%p anchor=%lx calls:", sig, info ? info->si_addr : (void *)0, anchor);
	void **fp = (void **)__builtin_frame_address(0);
	for (int i = 0; i < 12 && fp && (((long)fp) & 7) == 0 && (long)fp > 0x10000 && n < (int)sizeof(buf) - 24; i++)
	{
		n += snprintf(buf + n, sizeof(buf) - n, " %ld", (long)fp[1] - anchor);
		fp = (void **)fp[0];
	}
	echo_notify(buf);
	sleep(8);
	_exit(1);
}

struct EchoFirst
{
	EchoFirst()
	{
		struct sigaction sa;
		memset(&sa, 0, sizeof(sa));
		sa.__sa_handler.__sa_sigaction = echoCrash; // (the toolchain's sa_sigaction macro points at a member that does not exist)
		sa.sa_flags = SA_SIGINFO;
		sigaction(SIGSEGV, &sa, 0);
		sigaction(SIGBUS, &sa, 0);
		sigaction(SIGILL, &sa, 0);
		sigaction(SIGFPE, &sa, 0);
		sigaction(SIGABRT, &sa, 0);
		echo_notify("[F] first object loaded, crash reporter installed");
	}
};
static EchoFirst echoFirst;
