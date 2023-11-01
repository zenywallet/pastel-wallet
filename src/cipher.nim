# Copyright (c) 2019 zenywallet
# nim c -d:release -d:emscripten -o:cipher.js cipher.nim

import ctrmode, algorithm, orlp_ed25519, yespower, murmurhash, zbar

var ctr: CTR

proc cipher_init*(key, enc_iv, dec_iv: array[32, byte]) {.exportc: "cipher_init".} =
  ctr.init(key, enc_iv, dec_iv)

proc cipher_enc*(in_blk, out_blk: ptr UncheckedArray[byte]) {.exportc: "cipher_enc".} =
  ctr.encrypt(in_blk, out_blk)

proc cipher_dec*(in_blk, out_blk: ptr UncheckedArray[byte]) {.exportc: "cipher_dec".} =
  ctr.decrypt(in_blk, out_blk)

when isMainModule:
  var k: array[32, byte]
  var rs: array[32, byte]
  var rc: array[32, byte]
  var a, b, c: array[16, byte]
  for i in 0..<32:
    k[i] = cast[byte](i)
    rs[i] = cast[byte](0)
    rc[i] = cast[byte](0)
  for i in 0..<16:
    a[i] = cast[byte](0)
  cipher_init(k, rc, rs)
  cipher_enc(cast[ptr UncheckedArray[byte]](addr a[0]), cast[ptr UncheckedArray[byte]](addr b[0]))
  echo b
  cipher_dec(cast[ptr UncheckedArray[byte]](addr b[0]), cast[ptr UncheckedArray[byte]](addr c[0]))
  echo c
