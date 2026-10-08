#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p tests/.classes
cc -O2 -Wall -Wextra -DPNG_ARM_NEON_OPT=0 \
  -I modules/long-image/ios/Vendor/libpng \
  tests/ios-pixel-core.c modules/long-image/ios/PixelCore.c \
  modules/long-image/ios/Vendor/libpng/*.c -lz -lm -o tests/.classes/ios-pixel-core
if [[ ! -f tests/large-roundtrip.png ]]; then java tests/CompileAndTest.java; fi
(ulimit -v 65536; tests/.classes/ios-pixel-core tests/large-roundtrip.png tests/ios-backing.rgba tests/ios-roundtrip.png)
python3 tests/verify_large.py tests/ios-roundtrip.png
rm -f tests/ios-backing.rgba tests/ios-roundtrip.png
