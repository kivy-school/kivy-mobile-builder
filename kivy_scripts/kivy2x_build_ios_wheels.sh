#!/bin/bash
set -e -x

ROOT="${PWD}"
OUTPUT_DIR="$ROOT/wheels"

# Clone kivy2x (master branch) — it builds SDL2/ANGLE itself via tools/build_ios_dependencies.sh
git clone --depth 1 --branch master https://github.com/kivy-school/kivy2x kivy2x

cd kivy2x

cibuildwheel --platform ios \
      --archs all \
      --output-dir "$OUTPUT_DIR"
