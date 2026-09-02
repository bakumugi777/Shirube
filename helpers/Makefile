CC ?= cc
CFLAGS ?= -O2 -pipe
CFLAGS += -std=c11 -Wall -Wextra -Wpedantic
LDLIBS += -lm

.PHONY: all clean

all: shirube-audio-rms

shirube-audio-rms: shirube-audio-rms.c
	$(CC) $(CFLAGS) $< -o $@ $(LDFLAGS) $(LDLIBS)

clean:
	rm -f shirube-audio-rms
