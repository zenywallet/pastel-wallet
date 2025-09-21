# Package

version       = "0.1.0"
author        = "zenywallet"
description   = "Pastel Wallet - A sample wallet using Blockstor API"
license       = "MIT"
srcDir        = "src"
binDir        = "bin"
bin           = @["pastel"]



# Dependencies

requires "nim >= 0.20.0"
requires "caprese"
requires "libcurl"
requires "karax"
requires "regex"
requires "zenyjs"

# Tasks

task rocksdb, "Build RocksDB":
  withDir "deps/rocksdb":
    exec "make clean"
    exec "DEBUG_LEVEL=0 make -j$(nproc) liblz4.a"
    exec "CPLUS_INCLUDE_PATH=./$(basename lz4-*/)/lib ROCKSDB_DISABLE_SNAPPY=1 ROCKSDB_DISABLE_ZLIB=1 ROCKSDB_DISABLE_BZIP=1 ROCKSDB_DISABLE_ZSTD=1 make -j$(nproc) static_lib"

task rocksdbDefault, "Build RocksDB (Default)":
  withDir "deps/rocksdb":
    exec "make clean"
    exec "DEBUG_LEVEL=0 make -j$(nproc) libsnappy.a"
    exec "ROCKSDB_DISABLE_LZ4=1 ROCKSDB_DISABLE_ZLIB=1 ROCKSDB_DISABLE_BZIP=1 ROCKSDB_DISABLE_ZSTD=1 make -j$(nproc) static_lib"

task zbar, "Build zbar":
  withDir "deps/zbar":
    exec "make clean"
    exec "sed -i \"s/ -Werror//\" $(pwd)/configure.ac"
    exec "autoreconf -i"
    exec """
emconfigure ./configure CPPFLAGS=-DNDEBUG=1 --without-x \
--without-jpeg --without-imagemagick --without-npapi \
--without-gtk --without-python --without-qt --without-xshm \
--disable-video --disable-pthread --enable-codes=all
"""
    exec "emmake make"

task depsAll, "Build deps":
  rocksdbTask()
  zbarTask()

task cipher, "Build cipher":
  exec "nim c -d:release -d:emscripten --noMain:on -o:public/js/cipher.js src/cipher.nim"
  exec "nim c -r src/cipher_patch.nim"

task minify, "Minifies the JS using Google's closure compiler":
  exec "nim c -r src/config.nim"
  exec "nim js -d:release -o:public/js/main.js src/js/main.nim"
  exec """
java -jar bin/closure-compiler.jar --compilation_level SIMPLE \
--js_output_file=public/js/app.js \
public/js/cipher.js \
public/js/uint64.min.js \
public/js/coinlibs.js \
public/js/rawdeflate.min.js \
public/js/rawinflate.min.js \
public/js/jquery-3.4.1.min.js \
public/semantic/compact.js \
public/js/jquery-qrcode.js \
public/js/matter.js \
public/js/dotmatrix.js \
public/js/balls.js \
public/js/encoding.js \
public/js/tradelogs.js \
public/js/ui.js \
public/js/config.js \
public/js/pastel.js \
public/js/main.js 2>&1 | cut -c 1-240
"""
