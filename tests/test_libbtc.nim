import unittest, byteutils, marshal, sequtils
{.passL: "../deps/libbtc/.libs/libbtc.a ../deps/libbtc/src/secp256k1/.libs/libsecp256k1.a".}

proc btc_random_bytes(buf: var openarray[byte], len: uint32, update_seed: uint8): uint8 {.importc.}

test "btc_random_bytes array":
  var buf: array[32, byte]
  var ret = btc_random_bytes(buf, 32, 0)
  echo "ret=", ret, " ", buf.toHex
  check(ret == 1)

test "btc_random_bytes seq":
  var buf = newSeq[byte](32)
  var ret = btc_random_bytes(buf, 32, 0)
  echo "ret=", ret, " ", buf.toHex
  check(ret == 1)
