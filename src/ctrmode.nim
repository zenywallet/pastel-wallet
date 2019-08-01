# Copyright (c) 2019 zenywallet

import serpent, algorithm, byteutils

type
  CTR* = object
    enc_iv: array[32, byte]
    dec_iv: array[32, byte]

proc countup(val: var array[32, byte]) =
  for i in val.low..val.high:
    val[i] = (val[i] + 1) and 0xff
    if val[i] != 0:
      break

proc init*(ctr: var CTR, key: array[32, byte], enc_iv: array[32, byte], dec_iv: array[32, byte]) =
  discard set_key(cast[ptr uint32](unsafeAddr key[0]), key.len * 8)
  copyMem(addr ctr.enc_iv[0], unsafeAddr enc_iv[0], sizeof(ctr.enc_iv))
  copyMem(addr ctr.dec_iv[0], unsafeAddr dec_iv[0], sizeof(ctr.dec_iv))

proc encrypt*(ctr: var CTR, in_blk: ptr byte, out_blk: ptr byte) =
  var enc: array[16, byte]
  encrypt(cast[ptr array[4, uint32]](addr ctr.enc_iv[0]), cast[ptr array[4, uint32]](addr enc[0]))
  var enc_u32p = cast[ptr array[4, uint32]](addr enc[0])
  var in_u32p = cast[ptr array[4, uint32]](in_blk)
  var out_u32p = cast[ptr array[4, uint32]](out_blk)
  for i in 0..3:
    out_u32p[i] = in_u32p[i] xor enc_u32p[i]
  countup(ctr.enc_iv)

proc decrypt*(ctr: var CTR, in_blk: ptr byte, out_blk: ptr byte) =
  var dec: array[16, byte]
  encrypt(cast[ptr array[4, uint32]](addr ctr.dec_iv[0]), cast[ptr array[4, uint32]](addr dec[0]))
  var dec_u32p = cast[ptr array[4, uint32]](addr dec[0])
  var in_u32p = cast[ptr array[4, uint32]](in_blk)
  var out_u32p = cast[ptr array[4, uint32]](out_blk)
  for i in 0..3:
    out_u32p[i] = in_u32p[i] xor dec_u32p[i]
  countup(ctr.dec_iv)

when isMainModule:
  var ctr: CTR
  var key: array[32, byte]
  var enc_iv: array[32, byte]
  var dec_iv: array[32, byte]
  var data: array[16, byte]

  key.fill(10)
  enc_iv.fill(0)
  dec_iv.fill(0)
  data.fill(0xa5)

  ctr.init(key, enc_iv, dec_iv)

  echo "data=", data.toHex
  for i in 0..3:
    var enc: array[16, byte]
    var dec: array[16, byte]

    echo "enc_iv=", ctr.enc_iv.toHex
    echo "dec_iv=", ctr.dec_iv.toHex
    ctr.encrypt(cast[ptr byte](addr data[0]), cast[ptr byte](addr enc[0]))
    ctr.decrypt(cast[ptr byte](addr enc[0]), cast[ptr byte](addr dec[0]))
    echo "enc=", enc.toHex
    echo "dec=", dec.toHex
