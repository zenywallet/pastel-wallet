# Copyright (c) 2020 zenywallet

import libbtc

var bitzeny_chainparams = chainparams(
  chainname: "main",
  b58prefix_pubkey_address: 0x51,
  b58prefix_script_address: 0x05,
  bech32_hrp: "sz",
  b58prefix_secret_address: 0x80,
  b58prefix_bip32_privkey: 0x0488ade4,
  b58prefix_bip32_pubkey: 0x0488b21e,
  netmagic: "daadbef9".toBytesFromHex,
  genesisblockhash: "0x000009f7e55e9e3b4781e22bd87a7cfa4acada9e4340d43ca738bf4e9fb8f5ce".toBytesFromHex,
  default_port: 9253,
  dnsseeds: @["seed.bitzeny.jp"])

var testnet_bitzeny_chainparams = chainparams(
  chainname: "test",
  b58prefix_pubkey_address: 0x6f,
  b58prefix_script_address: 0xc4,
  bech32_hrp: "tz",
  b58prefix_secret_address: 0xef,
  b58prefix_bip32_privkey: 0x04358394,
  b58prefix_bip32_pubkey: 0x043587cf,
  netmagic: "59454e59".toBytesFromHex,
  genesisblockhash: "0x00003a0c79f595bddb7f37a22eb63fd23c541ab6a7dd7efd0215e7029bde225c".toBytesFromHex,
  default_port: 19253,
  dnsseeds: @["testnet-seed.bitzeny.jp"])

var bitzeny_chain*: btc_chainparams = set_chainparams(bitzeny_chainparams)
var testnet_bitzeny_chain*: btc_chainparams = set_chainparams(testnet_bitzeny_chainparams)


const blockstor_apikey* = "sample-969a6d71-a259-447c-a486-90bac964992b"
const gaplimit*: uint32 = 20
var chain* = bitzeny_chain
