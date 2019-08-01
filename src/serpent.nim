# Copyright (c) 2019 zenywallet
# nim c -d:release -d:emscripten -o:serpent.js serpent.nim

{.compile: "../deps/serpent/serpent.c".}

proc cipher_name*(): cstringArray {.importc: "serpent_cipher_name".}
proc set_key*(in_key: ptr uint32; key_len: uint32): ptr uint32 {.importc: "serpent_set_key".}
proc encrypt*(in_blk: ptr array[4, uint32]; out_blk: ptr array[4, uint32]) {.importc: "serpent_encrypt".}
proc decrypt*(in_blk: ptr array[4, uint32]; out_blk: ptr array[4, uint32]) {.importc: "serpent_decrypt".}
