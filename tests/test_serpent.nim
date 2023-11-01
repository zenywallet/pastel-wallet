# Copyright (c) 2019 zenywallet
# nim c -d:release -d:emscripten -o:test_serpent.js test_serpent.nim

import os, algorithm
import zenyjs
import zenyjs/core

const libbtcPath = splitPath(currentSourcePath()).head & "/../deps/serpent"
{.compile: libbtcPath & "/serpent.c".}

type
  u4byte* = uint32

proc cipher_name*(): cstringArray {.importc: "serpent_cipher_name".}
proc set_key*(in_key: ptr u4byte; key_len: u4byte): ptr u4byte {.importc: "serpent_set_key".}
proc encrypt*(in_blk: ptr array[4, u4byte]; out_blk: ptr array[4, u4byte]) {.importc: "serpent_encrypt".}
proc decrypt*(in_blk: ptr array[4, u4byte]; out_blk: ptr array[4, u4byte]) {.importc: "serpent_decrypt".}

when isMainModule:
  var key: array[32, byte]
  var data: array[16, byte]
  var enc: array[16, byte]
  var dec: array[16, byte]
  key.fill(0)
  data.fill(0)
  enc.fill(0)
  dec.fill(0)
  var ret_key = set_key(cast[ptr u4byte](addr key[0]), 256)
  var ret_key_byte: array[32, byte]
  copyMem(addr ret_key_byte[0], ret_key, 32)
  encrypt(cast[ptr array[4, u4byte]](addr data[0]), cast[ptr array[4, u4byte]](addr enc[0]))
  decrypt(cast[ptr array[4, u4byte]](addr enc[0]), cast[ptr array[4, u4byte]](addr dec[0]))

  echo cipher_name()[0]
  echo "key=", key.toHex
  echo "ret_key=", ret_key_byte.toHex
  echo "data=", data.toHex
  echo "encrypt=", enc.toHex
  echo "decrypt=", dec.toHex
  assert dec.toHex == data.toHex
  #assert enc.toHex == "8910494504181950f98dd998a82b6749"
