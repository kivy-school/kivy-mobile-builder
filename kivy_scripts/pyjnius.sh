#!/bin/bash
set -e -x

if [ -z "$ANDROID_HOME" ]; then
      echo "Error: ANDROID_HOME must be set to the Android SDK root"
      exit 1
fi

ROOT="${PWD}"
OUTPUT_DIR="$ROOT/wheels"

git clone --depth 1 https://github.com/kivy/pyjnius pyjnius

# Patch: pyjnius setup.py converts .pyx -> .c for android (old pre-Cython
# workaround). cibuildwheel runs Cython itself, so the .c files don't exist.
# Comment out the whole block.
#
# setup.py has a second, unrelated "if PLATFORM == 'android':" (the package_data
# prune that keeps org.jnius out of the android wheel), so match the two lines
# as a unit rather than by line pattern — commenting out that other guard while
# leaving its indented body behind is an IndentationError.
python3 - <<'PY'
from pathlib import Path

path = Path("pyjnius/setup.py")
src = path.read_text()
old = "if PLATFORM == 'android':\n    PYX_FILES = [fn[:-3] + 'c' for fn in PYX_FILES]\n"
new = "# if PLATFORM == 'android':\n#     PYX_FILES = [fn[:-3] + 'c' for fn in PYX_FILES]\n"
if old not in src:
    raise SystemExit("pyjnius setup.py: pyx->c block not found; upstream changed")
path.write_text(src.replace(old, new, 1))
print("patched pyjnius/setup.py")
PY

# pyjnius' pyproject.toml defines an on-device smoke test that cibuildwheel runs
# in an Android emulator. Its comments assume an x86_64 build host, where x86_64
# is the testable ABI; on GitHub's arm64 macOS runners arm64_v8a becomes the
# host arch instead, and the managed emulator (dev32_aosp_atd_arm64-v8a) aborts
# with exit 134 before it can boot. Skip that one target; x86_64 is already
# skipped automatically since the testbed only runs the build-host arch.
export CIBW_TEST_SKIP="*-android_arm64_v8a"

cibuildwheel pyjnius \
      --platform android \
      --archs all \
      --output-dir "$OUTPUT_DIR"
