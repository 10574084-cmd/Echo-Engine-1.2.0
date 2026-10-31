// Test A: the smallest program there is (no C++ runtime). Shows one notification.
#include "ps4glue.h"
#include <unistd.h>

int main(void)
{
	echo_notify("A OK: the program started and can show notifications");
	sleep(5);
	return 0;
}
