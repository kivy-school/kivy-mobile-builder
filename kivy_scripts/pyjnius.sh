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

      # pyjnius setup.py switches to android mode when NDKPLATFORM + LIBLINK are set.
      # AndroidJavaLocation.get_libraries() returns ['SDL2', 'log'] so we need -L<sdl2 dir>.
      # PIP_EXTRA_INDEX_URL is injected so cibuildwheel's pip can resolve kivy 2.3.1
      # android wheels from anaconda.org/kivyschool inside the build sandbox.
      export CIBW_ENVIRONMENT_ANDROID="NDKPLATFORM=android LIBLINK=1 LDFLAGS=\"-L$SDL2_LIB_DIR\" PIP_EXTRA_INDEX_URL=\"$KIVY_INDEX\""

      cibuildwheel pyjnius \
            --platform android \
            --archs "$ARCH" \
            --output-dir "$OUTPUT_DIR"
}

build_for arm64_v8a android_24_arm64_v8a
build_for x86_64    android_24_x86_64
