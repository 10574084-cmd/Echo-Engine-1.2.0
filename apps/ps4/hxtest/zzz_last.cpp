// LAST object of the program: if this shows, every static constructor of hxcpp ran without crashing.
#include "ps4glue.h"

struct EchoLast
{
	EchoLast() { echo_notify("[L] last object: all static constructors survived"); }
};
static EchoLast echoLast;
