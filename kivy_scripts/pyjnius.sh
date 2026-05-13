#!/bin/bash
set -e -x

if [ -z "$ANDROID_NDK_HOME" ]; then
      echo "Error: ANDROID_NDK_HOME must be set"
      exit 1
fi

ROOT="${PWD}"
OUTPUT_DIR="$ROOT/wheels"
KIVY_INDEX="https://pypi.anaconda.org/kivyschool/simple"
KIVY_VERSION="${KIVY_VERSION:-2.3.1}"

git clone --depth 1 https://github.com/kivy/pyjnius pyjnius

# Patch: pyjnius setup.py converts .pyx -> .c for android (old pre-Cython workaround).
# cibuildwheel runs Cython itself, so the .c files don't exist. Comment out both lines.
sed -i '' \
    -e "s/^if PLATFORM == 'android':$/# if PLATFORM == 'android':/" \
    -e "s/^    PYX_FILES = \[fn\[:-3\] + 'c' for fn in PYX_FILES\]$/    # PYX_FILES = [fn[:-3] + 'c' for fn in PYX_FILES]/" \
    pyjnius/setup.py

build_for() {
      ARCH=$1            # cibuildwheel android arch token: arm64_v8a | x86_64
      PLAT_TAG=$2        # pip platform tag: android_24_arm64_v8a | android_24_x86_64

      KIVY_DIR="$ROOT/kivy-$ARCH"
      rm -rf "$KIVY_DIR"
      mkdir -p "$KIVY_DIR/extracted"

      # Pull the prebuilt kivy android wheel just to harvest libSDL2.so for linking
      pip download "kivy==$KIVY_VERSION" \
            --index-url "$KIVY_INDEX" \
            --platform "$PLAT_TAG" \
            --python-version 313 \
            --only-binary=:all: \
            --no-deps \
            -d "$KIVY_DIR"

      unzip -q "$KIVY_DIR"/*.whl -d "$KIVY_DIR/extracted"

      SDL2_SO="$(find "$KIVY_DIR/extracted" -name 'libSDL2.so' | head -1)"
      if [ -z "$SDL2_SO" ]; then
            echo "Error: libSDL2.so not found in kivy wheel for $ARCH"
            exit 1
      fi
      SDL2_LIB_DIR="$(dirname "$SDL2_SO")"

      # Copy libSDL2.so into the cibuildwheel Python prefix/lib so the NDK linker finds -lSDL2.
      # LDFLAGS in CIBW_ENVIRONMENT_ANDROID is ignored by the NDK cross-compile toolchain;
      # copying into sys.prefix/lib works because that -L path is always in the link command.
      # $SDL2_SO is expanded to the real host path at export time.
      export CIBW_BEFORE_BUILD_ANDROID="python -c \"import sys, shutil; shutil.copy('$SDL2_SO', sys.prefix + '/lib/libSDL2.so')\""

      # pyjnius setup.py switches to android mode when NDKPLATFORM + LIBLINK are set.
      # PIP_EXTRA_INDEX_URL lets cibuildwheel's pip resolve kivy 2.3.1 from anaconda.org/kivyschool.
      export CIBW_ENVIRONMENT_ANDROID="NDKPLATFORM=android LIBLINK=1 PIP_EXTRA_INDEX_URL=\"$KIVY_INDEX\""

      cibuildwheel pyjnius \
            --platform android \
            --archs "$ARCH" \
            --output-dir "$OUTPUT_DIR"
}

build_for arm64_v8a android_24_arm64_v8a
build_for x86_64    android_24_x86_64
