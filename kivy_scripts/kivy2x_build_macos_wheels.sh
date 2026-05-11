#!/bin/bash
set -e -x

ROOT="${PWD}"
OUTPUT_DIR="$ROOT/wheels"

# Clone kivy2x (angle branch) — it builds SDL2/ANGLE itself via tools/build_macos_dependencies.sh
git clone --depth 1 --branch angle https://github.com/kivy-school/kivy2x kivy2x

cd kivy2x

cibuildwheel --platform macos \
      --archs arm64,x86_64 \
      --output-dir "$OUTPUT_DIR"
