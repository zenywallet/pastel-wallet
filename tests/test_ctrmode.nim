# Copyright (c) 2019 zenywallet

import ../src/ctrmode, algorithm, byteutils

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
