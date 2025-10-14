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
requires "zenycore"


# Tasks
import emsdkenv

task cipher, "Build cipher":
  emsdkEnv "nim c -d:release -d:emscripten --noMain:on -o:public/js/cipher.js src/cipher.nim"
  exec "nim c -r src/cipher_patch.nim"

task minify, "Minifies the JS using Google's closure compiler":
  exec "nim c -r --forceBuild src/config.nim"
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
