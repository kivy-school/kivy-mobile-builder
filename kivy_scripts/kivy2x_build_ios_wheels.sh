#!/bin/bash
set -e -x

ROOT="${PWD}"
OUTPUT_DIR="$ROOT/wheels"

# Clone kivy2x (angle branch) — it builds SDL2/ANGLE itself via tools/build_ios_dependencies.sh
git clone --depth 1 --branch angle https://github.com/kivy-school/kivy2x kivy2x

cd kivy2x

cibuildwheel --platform ios \
      --archs arm64_iphoneos,arm64_iphonesimulator,x86_64_iphonesimulator \
      --output-dir "$OUTPUT_DIR"
