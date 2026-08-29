#!/bin/bash
set -e -x

if [ -z "$ANDROID_HOME" ]; then
      echo "Error: ANDROID_HOME must be set to the Android SDK root"
      exit 1
fi

ROOT="${PWD}"
OUTPUT_DIR="$ROOT/wheels"

git clone --depth 1 https://github.com/kivy/pyjnius pyjnius

# Patch: pyjnius setup.py converts .pyx -> .c for android (old pre-Cython workaround).
# cibuildwheel runs Cython itself, so the .c files don't exist. Comment out both lines.
sed -i '' \
    -e "s/^if PLATFORM == 'android':$/# if PLATFORM == 'android':/" \
    -e "s/^    PYX_FILES = \[fn\[:-3\] + 'c' for fn in PYX_FILES\]$/    # PYX_FILES = [fn[:-3] + 'c' for fn in PYX_FILES]/" \
    pyjnius/setup.py

cibuildwheel pyjnius \
      --platform android \
      --archs all \
      --output-dir "$OUTPUT_DIR"
