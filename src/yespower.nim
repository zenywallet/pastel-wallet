# Copyright (c) 2019 zenywallet
# nim c -d:release -d:emscripten -o:yespower.js yespower.nim

{.compile: "../deps/yespower-1.0.1/sha256.c".}
{.compile: "../deps/yespower-1.0.1/yespower-opt.c".}
{.compile: "yespower_hash.c".}

proc yespower_hash*(input: ptr UncheckedArray[byte], input_size: int, output: ptr UncheckedArray[byte]): int {.importc.}
proc yespower_n2r8*(input: ptr UncheckedArray[byte], input_size: int, output: ptr UncheckedArray[byte]): int {.importc.}
proc yespower_n4r16*(input: ptr UncheckedArray[byte], input_size: int, output: ptr UncheckedArray[byte]): int {.importc.}
proc yespower_n4r32*(input: ptr UncheckedArray[byte], input_size: int, output: ptr UncheckedArray[byte]): int {.importc.}

when isMainModule:
  var a: array[80, byte]
  var b: array[32, byte]
  for i in 0..<80:
    a[i] = cast[byte](i)

  for i in 0..<1000:
    discard yespower_hash(cast[ptr UncheckedArray[byte]](addr a[0]), 80, cast[ptr UncheckedArray[byte]](addr b[0]))
  echo a
  echo b
