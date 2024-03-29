# Copyright (c) 2020 zenywallet

import zenyjs
import zenyjs/core
import zenyjs/address

networks:
  BitZeny_mainnet:
    pubKeyPrefix: 81'u8
    scriptPrefix: 5'u8
    wif: 128'u8
    bech32: "sz"
    bech32Extra: @["bz"]
    testnet: false

  BitZeny_testnet:
    pubKeyPrefix: 111'u8
    scriptPrefix: 196'u8
    wif: 239'u8
    bech32: "tz"
    testnet: true

var network* = BitZeny_mainnet

const blockstor_apikey* = "sample-969a6d71-a259-447c-a486-90bac964992b"
const gaplimit*: uint32 = 20
