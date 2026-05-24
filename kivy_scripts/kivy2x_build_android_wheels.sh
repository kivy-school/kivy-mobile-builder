#!/bin/bash
set -e -x

if [ -z "$ANDROID_NDK_HOME" ]; then
      echo "Error: ANDROID_NDK_HOME must be set"
      exit 1
fi

ROOT="${PWD}"
OUTPUT_DIR="$ROOT/wheels"

# Clone kivy2x (master branch) — it builds SDL2 itself via tools/build_android_dependencies.sh
git clone --depth 1 --branch master https://github.com/kivy-school/kivy2x kivy2x

cd kivy2x

cibuildwheel --platform android \
      --archs all \
      --output-dir "$OUTPUT_DIR"
