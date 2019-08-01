# Copyright (c) 2019 zenywallet
# nim c -d:release -d:emscripten -o:serpent.js serpent.nim

{.compile: "../deps/serpent/serpent.c".}

type
  u4byte* = uint32

proc cipher_name*(): cstringArray {.importc: "serpent_cipher_name".}
proc set_key*(in_key: ptr u4byte; key_len: u4byte): ptr u4byte {.importc: "serpent_set_key".}
proc encrypt*(in_blk: ptr array[4, u4byte]; out_blk: ptr array[4, u4byte]) {.importc: "serpent_encrypt".}
proc decrypt*(in_blk: ptr array[4, u4byte]; out_blk: ptr array[4, u4byte]) {.importc: "serpent_decrypt".}
