# Copyright (c) 2019 zenywallet

import os

const libbtcPath = splitPath(currentSourcePath()).head & "/deps/libbtc"
{.passL: libbtcPath & "/.libs/libbtc.a".}
{.passL: libbtcPath & "/src/secp256k1/.libs/libsecp256k1.a".}

proc btc_random_bytes*(buf: var openarray[byte], len: uint32, update_seed: uint8): uint8 {.importc.}
