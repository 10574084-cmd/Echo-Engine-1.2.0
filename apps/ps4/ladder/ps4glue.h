// Small C glue for the Haxe test on the PS4: a toast notification on screen, the same text in the console log (klog) and in
// a text file (/data/echo_log.txt, and /mnt/usb0/echo_log.txt when a USB drive is plugged in).
#pragma once
#include <stdio.h>
#include <string.h>

extern "C" {
	typedef struct echo_notify_request { char useless1[45]; char message[3075]; } echo_notify_request;
	int sceKernelSendNotificationRequest(int device, echo_notify_request *req, unsigned long size, int blocking);
}

static inline void echo_log_file(const char *path, const char *text)
{
	FILE *f = fopen(path, "a");
	if (!f) return;
	fputs(text, f);
	fputc('\n', f);
	fflush(f);
	fclose(f);
}

static inline void echo_notify(const char *text)
{
	printf("[Echo Engine] %s\n", text);
	echo_log_file("/data/echo_log.txt", text);
	echo_log_file("/mnt/usb0/echo_log.txt", text);
	echo_notify_request req;
	memset(&req, 0, sizeof(req));
	strncpy(req.message, text, sizeof(req.message) - 1);
	sceKernelSendNotificationRequest(0, &req, sizeof(req), 0);
}
