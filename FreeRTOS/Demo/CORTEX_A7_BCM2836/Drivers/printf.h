#ifndef PRINTF_H_INCLUDED
#define PRINTF_H_INCLUDED

#include <stdint.h>

typedef struct {
	uint32_t ev_id;
	void* this_fn;
	void* call_site;
	uint32_t lowtimestamp;
	uint32_t hightimestamp;
} cyg_event_t;

void printf(const char *fmt, ...);
void sprintf(char *buffer, const char *fmt, ...);

#endif
