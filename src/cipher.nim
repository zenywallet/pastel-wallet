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

when defined(emscripten):
  import macros

  const CIPHER_MODULE_NAME = "Cipher"
  {.passL: "-s EXPORT_NAME=" & CIPHER_MODULE_NAME.}

  const DEFAULT_EXPORTED_FUNCTIONS = ["_malloc", "_free"]
  const DEFAULT_EXPORTED_RUNTIME_METHODS = [
    "ccall", "cwrap", "UTF8ToString", "stackSave",
    "stackAlloc", "stackRestore",
    "HEAPU8", "HEAP8", "HEAPU32", "HEAP32", "HEAPU64", "HEAP64"]

  const EXPORTED_FUNCTIONS = [
    "_cipher_init", "_cipher_enc", "_cipher_dec", "_serpent_set_key",
    "_serpent_encrypt", "_serpent_decrypt", "_ed25519_create_keypair",
    "_ed25519_sign", "_ed25519_verify", "_ed25519_key_exchange",
    "_ed25519_get_publickey", "_ed25519_add_scalar", "_yespower_hash",
    "_yespower_n2r8", "_yespower_n4r16", "_yespower_n4r32",
    "_murmurhash", "_zbar_init", "_zbar_destroy", "_zbar_scan"]

  macro collectExportedFunctions*(): untyped =
    result = nnkBracket.newTree()
    for functionName in DEFAULT_EXPORTED_FUNCTIONS:
      result.add(newLit(functionName))
    when declared(cipher.EXPORTED_FUNCTIONS):
      for functionName in cipher.EXPORTED_FUNCTIONS:
        result.add(newLit(functionName))

  const exportedFunctions = collectExportedFunctions()

  {.passL: "-s EXPORTED_FUNCTIONS='" & $exportedFunctions & "'".}
  {.passL: "-s EXPORTED_RUNTIME_METHODS='" & $DEFAULT_EXPORTED_RUNTIME_METHODS & "'".}


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
