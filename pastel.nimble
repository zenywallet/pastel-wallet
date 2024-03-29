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
requires "jester >= 0.4.1"
requires "templates", "nimcrypto", "ed25519", "rocksdb", "libcurl"
requires "karax"
requires "https://github.com/zenywallet/zenyjs"

# Tasks

task depsAll, "Build deps":
  withDir "deps/zbar":
    exec "sed -i \"s/ -Werror//\" $(pwd)/configure.ac"
    exec "autoreconf -i"
    exec """
emconfigure ./configure CPPFLAGS=-DNDEBUG=1 --without-x \
--without-jpeg --without-imagemagick --without-npapi \
--without-gtk --without-python --without-qt --without-xshm \
--disable-video --disable-pthread --enable-codes=all
"""
    exec "emmake make"

task cipher, "Build cipher":
  exec "nim c -d:release -d:emscripten --noMain:on -o:public/js/cipher.js src/cipher.nim"

task minify, "Minifies the JS using Google's closure compiler":
  exec """
nim js -d:release -o:public/js/main.js public/js/main.nim
java -jar bin/closure-compiler.jar --compilation_level SIMPLE \
--js_output_file=public/js/app.js \
public/js/cipher.js \
public/js/base58.js \
public/js/uint64.min.js \
public/js/coinlibs.js \
public/js/rawdeflate.min.js \
public/js/rawinflate.min.js \
public/js/jquery-3.4.1.min.js \
public/semantic/compact.js \
public/js/jquery-qrcode.js \
public/js/stor.js \
public/js/matter.js \
public/js/dotmatrix.js \
public/js/balls.js \
public/js/encoding.js \
public/js/tradelogs.js \
public/js/wallet.js \
public/js/ui.js \
public/js/pastel.js \
public/js/main.js 2>&1 | cut -c 1-240
"""
