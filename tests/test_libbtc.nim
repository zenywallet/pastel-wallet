# Copyright (c) 2019 zenywallet

import unittest, byteutils, marshal, sequtils
import ../libbtc

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
