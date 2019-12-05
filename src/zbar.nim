# cd deps/zbar
# sed -i "s/ -Werror//" $(pwd)/configure.ac
# autoreconf -i
# emconfigure ./configure CPPFLAGS=-DNDEBUG=1 --without-x --without-jpeg --without-imagemagick --without-npapi --without-gtk --without-python --without-qt --without-xshm --disable-video --disable-pthread --enable-codes=all
# emmake make
# see https://github.com/Naahuel/zbar-wasm-barcode-reader
# nim c -d:release -d:emscripten -o:zbar.js zbar.nim
import os

const zbarPath = splitPath(currentSourcePath()).head & "/../deps/zbar"
{.passL: zbarPath & "/zbar/.libs/libzbar.a".}

{.emit: """
#include <stdint.h>
#include "../deps/zbar/include/zbar.h"
#include <emscripten.h>

zbar_image_scanner_t *scanner;

void zbar_init() {
  scanner = zbar_image_scanner_create();
  zbar_image_scanner_set_config(scanner, 0, ZBAR_CFG_X_DENSITY, 1);
  zbar_image_scanner_set_config(scanner, 0, ZBAR_CFG_Y_DENSITY, 1);
}

void zbar_destroy() {
  zbar_image_scanner_destroy(scanner);
}

void zbar_scan(uint8_t *raw, int width, int height)
{
  zbar_image_t *image = zbar_image_create();
  zbar_image_set_format(image, zbar_fourcc('Y', '8', '0', '0'));
  zbar_image_set_size(image, width, height);
  zbar_image_set_data(image, raw, width * height, zbar_image_free_data);

  int n = zbar_scan_image(scanner, image);

  const zbar_symbol_t *symbol = zbar_image_first_symbol(image);
  for(; symbol; symbol = zbar_symbol_next(symbol)) {
    zbar_symbol_type_t typ = zbar_symbol_get_type(symbol);
    const char *data = zbar_symbol_get_data(symbol);

    unsigned poly_size = zbar_symbol_get_loc_size(symbol);

    int poly[poly_size * 2];
    unsigned u = 0;
    for(unsigned p = 0; p < poly_size; p++) {
      poly[u] = zbar_symbol_get_loc_x(symbol, p);
      poly[u + 1] = zbar_symbol_get_loc_y(symbol, p);
      u += 2;
    }

    EM_ASM({
      zbar_stream($0, $1, $2, $3);
    }, zbar_get_symbol_name(typ), data, poly, poly_size);
  }

  zbar_image_destroy(image);
}
""".}
