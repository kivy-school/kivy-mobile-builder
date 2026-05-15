#!/bin/bash
set -e -x

if [ -z "$ANDROID_NDK_HOME" ]; then
    echo "Error: ANDROID_NDK_HOME must be set"
    exit 1
fi

ROOT="${PWD}"
OUTPUT_DIR="$ROOT/wheels"

git clone --depth 1 https://github.com/kivy-school/android android-pkg

# All build logic (config.pxi generation, SDL lib harvesting, Cython compile)
# lives in android-pkg/setup.py — no CIBW_* overrides needed.
cibuildwheel android-pkg \
    --platform android \
    --output-dir "$OUTPUT_DIR"
