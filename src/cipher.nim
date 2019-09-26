# Copyright (c) 2019 zenywallet
# nim c -d:release -d:emscripten -o:cipher.js cipher.nim

import ctrmode, byteutils, algorithm, orlp_ed25519, yespower

var ctr: CTR

proc cipher_init*(key, enc_iv, dec_iv: array[32, byte]) {.exportc: "cipher_init".} =
  ctr.init(key, enc_iv, dec_iv)

proc cipher_enc*(in_blk, out_blk: ptr UncheckedArray[byte]) {.exportc: "cipher_enc".} =
  ctr.encrypt(in_blk, out_blk)

proc cipher_dec*(in_blk, out_blk: ptr UncheckedArray[byte]) {.exportc: "cipher_dec".} =
  ctr.decrypt(in_blk, out_blk)
