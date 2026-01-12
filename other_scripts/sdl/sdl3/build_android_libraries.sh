#!/bin/bash

SDL_VER="3.2.22"
SDL_IMAGE_VER="3.2.4"
SDL_MIXER_VER="78a2035cf4cf95066d7d9e6208e99507376409a7"
SDL_TTF_VER="3.2.2"

# Android build configurations
ANDROID_API_LEVEL=21
ANDROID_ABIS=("arm64-v8a" "x86_64")

# Check if NDK is available
if [ -z "$ANDROID_NDK_HOME" ] && [ -z "$NDK_ROOT" ]; then
    echo "Error: ANDROID_NDK_HOME or NDK_ROOT environment variable not set"
    echo "Please set one of these to your Android NDK path"
    exit 1
fi

NDK_PATH=${ANDROID_NDK_HOME:-$NDK_ROOT}

build_library() {
    LIB=$1
    SOURCE_DIR=$2
    BUILD_DIR=$3
    OUTPUT=$4
    SDL3_INSTALL_DIR=$5
    EXTRA_CMAKE_ARGS=$6

    echo "Building $LIB for Android..."

    for ABI in "${ANDROID_ABIS[@]}"; do
        echo "Building $LIB for $ABI..."
        
        BUILD_PATH="$BUILD_DIR/$ABI"
        mkdir -p "$BUILD_PATH"
        
        cd "$BUILD_PATH"
        
        # Set SDL3_DIR to find SDL3 CMake config if it was installed
        SDL3_CMAKE_ARGS=""
        if [ -n "$SDL3_INSTALL_DIR" ] && [ -d "$SDL3_INSTALL_DIR/$ABI" ]; then
            SDL3_CMAKE_ARGS="-DSDL3_DIR=$SDL3_INSTALL_DIR/$ABI/lib/cmake/SDL3"
        fi
        
        cmake "$SOURCE_DIR" \
            -DCMAKE_SYSTEM_NAME=Android \
            -DCMAKE_SYSTEM_VERSION=$ANDROID_API_LEVEL \
            -DCMAKE_ANDROID_ARCH_ABI=$ABI \
            -DCMAKE_ANDROID_NDK="$NDK_PATH" \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX="$OUTPUT/$ABI" \
            -DBUILD_SHARED_LIBS=ON \
            -DSDL_TEST_LIBRARY=OFF \
            -DSDL_TESTS=OFF \
            -DSDL_EXAMPLES=OFF \
            $SDL3_CMAKE_ARGS \
            $EXTRA_CMAKE_ARGS
        
        cmake --build . --config Release
        cmake --install .
        
        cd -
    done

    echo "Completed building $LIB for all architectures"
}

sdl_ttf_extra() {
    cd $1
    if [ -f "external/download.sh" ]; then
        external/download.sh
    fi
    cd -
}

sdl_mixer_extra() {
    cd $1
    if [ -f "external/download.sh" ]; then
        echo "Downloading SDL3_mixer external dependencies..."
        external/download.sh
    fi
    cd -
}

download_libs() {
    SDL_FILE="SDL3-$SDL_VER.tar.gz"
    if [ ! -f "$SDL_FILE" ]; then
        wget -O $SDL_FILE https://github.com/libsdl-org/SDL/releases/download/release-$SDL_VER/$SDL_FILE
    fi
    if [ ! -d "SDL3-$SDL_VER" ]; then
        tar -xzvf $SDL_FILE
    fi

    FILE="SDL3_image-$SDL_IMAGE_VER.tar.gz"
    if [ ! -f "$FILE" ]; then
        wget -O $FILE https://github.com/libsdl-org/SDL_image/releases/download/release-$SDL_IMAGE_VER/$FILE
    fi
    if [ ! -d "SDL3_image-$SDL_IMAGE_VER" ]; then
        tar -xzvf $FILE
    fi

    FILE="SDL3_mixer-$SDL_MIXER_VER.tar.gz"
    if [ ! -f "$FILE" ]; then
        wget -O $FILE https://github.com/libsdl-org/SDL_mixer/archive/$SDL_MIXER_VER/$FILE
    fi
    if [ ! -d "SDL_mixer-$SDL_MIXER_VER" ]; then
        tar -xzvf $FILE
    fi

    FILE="SDL3_ttf-$SDL_TTF_VER.tar.gz"
    if [ ! -f "$FILE" ]; then
        wget -O $FILE https://github.com/libsdl-org/SDL_ttf/releases/download/release-$SDL_TTF_VER/$FILE
    fi
    if [ ! -d "SDL3_ttf-$SDL_TTF_VER" ]; then
        tar -xzvf $FILE
    fi
}

# Main build process
OUTPUT_DIR=${1:-$(pwd)/android_output}
mkdir -p "$OUTPUT_DIR"

echo "Output directory: $OUTPUT_DIR"
echo "Building SDL3 libraries for Android..."
echo "Target API Level: $ANDROID_API_LEVEL"
echo "Target ABIs: ${ANDROID_ABIS[*]}"

download_libs

# Build SDL3
build_library "SDL3" \
    "$(pwd)/SDL3-$SDL_VER" \
    "$(pwd)/build/SDL3" \
    "$OUTPUT_DIR/SDL3" \
    "" \
    ""

# Build SDL3_image (depends on SDL3)
build_library "SDL3_image" \
    "$(pwd)/SDL3_image-$SDL_IMAGE_VER" \
    "$(pwd)/build/SDL3_image" \
    "$OUTPUT_DIR/SDL3_image" \
    "$OUTPUT_DIR/SDL3" \
    ""

# Build SDL3_mixer (depends on SDL3)
sdl_mixer_extra "SDL_mixer-$SDL_MIXER_VER"
build_library "SDL3_mixer" \
    "$(pwd)/SDL_mixer-$SDL_MIXER_VER" \
    "$(pwd)/build/SDL3_mixer" \
    "$OUTPUT_DIR/SDL3_mixer" \
    "$OUTPUT_DIR/SDL3" \
    ""

# Build SDL3_ttf (depends on SDL3)
sdl_ttf_extra "SDL3_ttf-$SDL_TTF_VER"
build_library "SDL3_ttf" \
    "$(pwd)/SDL3_ttf-$SDL_TTF_VER" \
    "$(pwd)/build/SDL3_ttf" \
    "$OUTPUT_DIR/SDL3_ttf" \
    "$OUTPUT_DIR/SDL3" \
    ""

echo "Build complete! Libraries are in: $OUTPUT_DIR"
