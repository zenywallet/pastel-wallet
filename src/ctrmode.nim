# Copyright (c) 2019 zenywallet

import serpent

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
