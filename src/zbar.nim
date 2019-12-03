# cd deps/zbar
# sed -i "s/ -Werror//" $(pwd)/configure.ac
# autoreconf -i
# emconfigure ./configure --without-x --without-jpeg --without-imagemagick --without-npapi --without-gtk --without-python --without-qt --without-xshm --disable-video --disable-pthread --enable-codes=all
# emmake make
# see https://github.com/Naahuel/zbar-wasm-barcode-reader
# nim c -d:release -d:emscripten -o:zbar.js zbar.nim
import os

const zbarPath = splitPath(currentSourcePath()).head & "/../deps/zbar"
{.passL: zbarPath & "/zbar/.libs/libzbar.a".}

{.emit: """
#include "../deps/zbar/include/zbar.h"

void zbar_test() {
  zbar_image_scanner_create();
}
""".}

proc zbar_test*() {.importc.}

zbar_test()
