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

# Patch setup.py: add a bdist_wheel subclass that injects .java/org/jnius/ into the wheel.
# Setuptools cannot address a dot-prefixed directory by package name, so we post-process
# the wheel zip from within the bdist_wheel command itself.
python3 - pyjnius/setup.py <<'PYPATCH'
import sys
content = open(sys.argv[1]).read()

content = content.replace(
    "from setuptools.command.build_ext import build_ext",
    "from setuptools.command.build_ext import build_ext\n"
    "import base64, glob, hashlib, os, zipfile\n"
    "try:\n"
    "    from wheel.bdist_wheel import bdist_wheel as _bdist_wheel\n"
    "    _have_wheel = True\n"
    "except ImportError:\n"
    "    _have_wheel = False"
)

_cls = """
if _have_wheel:
    class bdist_wheel(_bdist_wheel):
        def run(self):
            super().run()
            java_src = join(dirname(__file__), 'jnius', 'src', 'org', 'jnius',
                            'NativeInvocationHandler.java')
            with open(java_src, 'rb') as _f:
                _java = _f.read()
            _wp = '.java/org/jnius/NativeInvocationHandler.java'
            for _whl in glob.glob(join(self.dist_dir, '*.whl')):
                with zipfile.ZipFile(_whl) as _zf:
                    _e = {n: _zf.read(n) for n in _zf.namelist()}
                _e[_wp] = _java
                _rk = next(n for n in _e if n.endswith('.dist-info/RECORD'))
                _d = base64.urlsafe_b64encode(
                    hashlib.sha256(_java).digest()).rstrip(b'=').decode()
                _ls = _e[_rk].decode().splitlines(keepends=True)
                _ri = next(i for i, l in enumerate(_ls) if '.dist-info/RECORD,,' in l)
                _ls.insert(_ri, f'{_wp},sha256={_d},{len(_java)}\\n')
                _e[_rk] = ''.join(_ls).encode()
                _tmp = _whl + '.tmp'
                with zipfile.ZipFile(_tmp, 'w', zipfile.ZIP_DEFLATED) as _zf:
                    for n, d in _e.items():
                        _zf.writestr(n, d)
                os.replace(_tmp, _whl)

"""

content = content.replace(
    "# create the extension\nsetup(",
    _cls + "# create the extension\nsetup("
)

content = content.replace(
    "cmdclass={'build_ext': build_ext},",
    "cmdclass={**({'bdist_wheel': bdist_wheel} if _have_wheel else {}), 'build_ext': build_ext},"
)

open(sys.argv[1], 'w').write(content)
print("patched", sys.argv[1])
PYPATCH

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
      # CMAKE_TOOLCHAIN_FILE=.../cibw-run-<id>/cp313-android_<arch>/toolchain.cmake
      # Cross-Python lib dir is dirname(CMAKE_TOOLCHAIN_FILE)/python/prefix/lib —
      # exactly the -L path the NDK linker already has.
      export CIBW_BEFORE_BUILD_ANDROID="python -c \"import os, shutil; lib=os.path.join(os.path.dirname(os.environ['CMAKE_TOOLCHAIN_FILE']), 'python', 'prefix', 'lib'); shutil.copy('$SDL2_SO', os.path.join(lib, 'libSDL2.so'))\""

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
