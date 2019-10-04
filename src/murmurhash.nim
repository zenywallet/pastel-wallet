# Copyright (c) 2019 zenywallet
# nim c -d:release -d:emscripten -o:murmurhash.js murmurhash.nim

import byteutils, endians

{.compile: "../deps/murmurhash/PMurHash128x64.cpp".}

proc PMurHash128x64*(key: pointer; len: cint; seed: cuint; `out`: pointer) {.importc.}

proc murmurhash*(key: ptr UncheckedArray[byte], key_size: cint, hash: ptr array[16, byte]) {.exportc: "murmurhash".} =
  PMurHash128x64(key, key_size, cast[cuint](0), hash)
  swapEndian64(addr hash[0], addr hash[0])
  swapEndian64(addr hash[8], addr hash[8])

when isMainModule:
  var s: cstring = "1"
  var a: array[16, byte]
  murmurhash(cast[ptr UncheckedArray[byte]](addr s[0]), cast[cint](s.len), cast[ptr array[16, byte]](addr a[0]))
  echo a.toHex
  # 71fbbbfe8a7b7c71942aeb9bf9f0f637
