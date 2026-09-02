#!/bin/sh
set -eu

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
compiler=${CC:-cc}

exec "$compiler" -O2 -pipe -std=c11 -Wall -Wextra -Wpedantic \
    "$script_dir/shirube-audio-rms.c" -o "$script_dir/shirube-audio-rms" -lm
