#!/usr/bin/env bash

set -e

echo "Compiling Nuklear..."
gcc -c src/nuklear.c \
  -o build/nuklear.o \
  -Isrc \
  $(sdl2-config --cflags)

echo "Building benq-gw2790..."
c3c build -l SDL2 -l GL -l GLEW -z build/nuklear.o

echo
echo "Build complete!"
echo "Executable: build/benq"
