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

const blockstor_apiurl* = "http://localhost:8000/api/"
const blockstor_apikey* = "sample-969a6d71-a259-447c-a486-90bac964992b"
const blockstor_wshost* = "localhost"
const blockstor_wsport* = 8001

const gaplimit*: uint32 = 20

when defined(PASTEL_BITZENY_JP):
  const HttpsPort* = 443
  const HttpsHost* = "pastel.bitzeny.jp"
  const HttpPort* = 80
  const HttpHost* = "pastel.bitzeny.jp"
  const HttpRedirect* = "https://pastel.bitzeny.jp"
  const WebSocketUrl* = "wss://pastel.bitzeny.jp/ws"
else:
  const HttpsPort* = 5002
  const HttpsHost* = "localhost:5002"
  const HttpPort* = 5000
  const HttpHost* = "localhost:5000"
  const HttpRedirect* = "https://localhost:5002"
  const WebSocketUrl* = "wss://localhost:5002/ws"
