#include <errno.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char **argv) {
    long window = 200;
    if (argc > 1) {
        char *end = NULL;
        const long parsed = strtol(argv[1], &end, 10);
        if (end != argv[1] && *end == '\0' && parsed >= 16 && parsed <= 65536)
            window = parsed;
    }

    int16_t buffer[1024];
    long count = 0;
    double square_sum = 0.0;

    while (!feof(stdin)) {
        const size_t received = fread(buffer, sizeof(buffer[0]),
                                      sizeof(buffer) / sizeof(buffer[0]), stdin);
        if (received == 0) {
            if (ferror(stdin) && errno == EINTR) {
                clearerr(stdin);
                continue;
            }
            break;
        }

        for (size_t i = 0; i < received; ++i) {
            const double sample = buffer[i];
            square_sum += sample * sample;
            ++count;
            if (count >= window) {
                const double rms = sqrt(square_sum / (double)count) / 32768.0;
                printf("%.6f\n", rms);
                fflush(stdout);
                count = 0;
                square_sum = 0.0;
            }
        }
    }

    return ferror(stdin) ? 1 : 0;
}
