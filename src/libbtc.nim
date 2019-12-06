# Copyright (c) 2019 zenywallet

import os, byteutils, marshal, sequtils, logs

const libbtcPath = splitPath(currentSourcePath()).head & "/../deps/libbtc"
{.passL: libbtcPath & "/.libs/libbtc.a".}
{.passL: libbtcPath & "/src/secp256k1/.libs/libsecp256k1.a".}

proc btc_random_bytes*(buf: var openarray[byte], len: uint32, update_seed: uint8): uint8 {.importc.}

type
  uint8_t* = uint8
  uint32_t* = uint32
  btc_bool* = bool

const
  BTC_ECKEY_UNCOMPRESSED_LENGTH* = 65
  BTC_ECKEY_COMPRESSED_LENGTH* = 33
  BTC_ECKEY_PKEY_LENGTH* = 32
  #BTC_ECKEY_PKEY_LENGTH* = 32
  BTC_HASH_LENGTH* = 32

template BTC_MIN*(a, b: untyped): untyped =
  (if ((a) < (b)): (a) else: (b))

template BTC_MAX*(a, b: untyped): untyped =
  (if ((a) > (b)): (a) else: (b))

type
  uint256* = array[32, uint8_t]
  uint160* = array[20, uint8_t]

type
  btc_dns_seed* {.bycopy.} = object
    domain*: array[256, char]

  btc_chainparams* {.bycopy.} = object
    chainname*: array[32, char]
    b58prefix_pubkey_address*: uint8_t
    b58prefix_script_address*: uint8_t
    bech32_hrp*: array[5, char]
    b58prefix_secret_address*: uint8_t ## !private key
    b58prefix_bip32_privkey*: uint32_t
    b58prefix_bip32_pubkey*: uint32_t
    netmagic*: array[4, cuchar]
    genesisblockhash*: uint256
    default_port*: cint
    dnsseeds*: array[8, btc_dns_seed]

  btc_checkpoint* {.bycopy.} = object
    height*: uint32_t
    hash*: cstring
    timestamp*: uint32_t
    target*: uint32_t

#var btc_chainparams_main*: btc_chainparams

#var btc_chainparams_test*: btc_chainparams

#var btc_chainparams_regtest*: btc_chainparams

##  the mainnet checkpoins, needs a fix size

#var btc_mainnet_checkpoint_array*: array[21, btc_checkpoint]

#type
#  btc_chainparams* {.importc: "btc_chainparams", bycopy.} = object

var btc_chainparams_main* {.importc.}: btc_chainparams

var btc_chainparams_test* {.importc.}: btc_chainparams

var btc_chainparams_regtest* {.importc.}: btc_chainparams

var btc_mainnet_checkpoint_array* {.importc.}: ptr btc_checkpoint


#echo btc_chainparams_main.default_port

proc hd_gen_master*(chain: ptr btc_chainparams; masterkeyhex: cstring; strsize: csize): btc_bool {.importc.}

proc hd_derive*(chain: ptr btc_chainparams; masterkey: cstring; keypath: cstring;
               extkeyout: cstring; extkeyout_size: csize): btc_bool {.importc.}

#proc hd_print_node*(chain: ptr btc_chainparams; nodeser: cstring): btc_bool {.importc.}

proc btc_ecc_start*() {.importc.}

proc btc_ecc_stop*() {.importc.}

const
  BTC_BIP32_CHAINCODE_SIZE* = 32

type
  btc_hdnode* {.bycopy.} = object
    depth*: uint32_t
    fingerprint*: uint32_t
    child_num*: uint32_t
    chain_code*: array[BTC_BIP32_CHAINCODE_SIZE, uint8_t]
    private_key*: array[BTC_ECKEY_PKEY_LENGTH, uint8_t]
    public_key*: array[BTC_ECKEY_COMPRESSED_LENGTH, uint8_t]

proc btc_hdnode_deserialize*(str: cstring; chain: ptr btc_chainparams;
                            node: ptr btc_hdnode): btc_bool {.importc.}

proc btc_hdnode_get_p2pkh_address*(node: ptr btc_hdnode; chain: ptr btc_chainparams;
                                  str: cstring; strsize: cint) {.importc.}

proc btc_hdnode_has_privkey*(node: ptr btc_hdnode): btc_bool {.importc.}

proc btc_hdnode_get_pub_hex*(node: ptr btc_hdnode; str: cstring; strsize: ptr csize): btc_bool {.importc.}

proc btc_hdnode_serialize_public*(node: ptr btc_hdnode; chain: ptr btc_chainparams;
                                 str: cstring; strsize: cint) {.importc.}

proc btc_hdnode_serialize_private*(node: ptr btc_hdnode; chain: ptr btc_chainparams;
                                  str: cstring; strsize: cint) {.importc.}

proc btc_base58_encode_check*(data: ptr UncheckedArray[uint8_t]; datalen: cint; str: cstring;
                             strsize: cint): cint {.importc.}

#proc printf(formatstr: cstring) {.header: "<stdio.h>", importc: "printf", varargs.}
#proc strncpy(s1: ptr UncheckedArray[char]; s2: cstring; n: csize): cstring {.importc.}

proc hd_print_node*(chain: ptr btc_chainparams; nodeser: cstring): btc_bool =
  var node: btc_hdnode
  if not btc_hdnode_deserialize(nodeser, chain, addr(node)):
    return false
  var strsize: csize = 128
  var str: cstring = newString(strsize) #array[strsize, char]
  btc_hdnode_get_p2pkh_address(addr(node), chain, str, cast[cint](strsize))
  debug "ext key: ", nodeser
  const privkey_wif_size_bin: csize = 34
  var pkeybase58c: array[privkey_wif_size_bin, uint8_t]
  pkeybase58c[0] = chain.b58prefix_secret_address
  pkeybase58c[33] = 1
  ##  always use compressed keys
  const privkey_wif_size: csize = 128
  var privkey_wif: cstring = newString(privkey_wif_size) #array[privkey_wif_size, char]
  #memcpy(addr(pkeybase58c[1]), node.private_key, BTC_ECKEY_PKEY_LENGTH)
  debug $$node.private_key
  debug node.private_key.toHex()
  copyMem(addr pkeybase58c[1], unsafeAddr node.private_key, BTC_ECKEY_PKEY_LENGTH)
  assert(btc_base58_encode_check(cast[ptr UncheckedArray[uint8_t]](addr pkeybase58c),
                                 cast[cint](privkey_wif_size_bin), privkey_wif,
                                 cast[cint](privkey_wif_size)) != 0)

  if btc_hdnode_has_privkey(addr(node)):
    debug "privatekey WIF: ", $privkey_wif
  debug "depth: ", $node.depth
  debug "child index: ", $node.child_num
  debug "p2pkh address: ", $str
  #debug "p2wpkh address: " & $str
  if not btc_hdnode_get_pub_hex(addr(node), str, addr(strsize)):
    return false
  debug "pubkey hex: ", str
  strsize = 128
  btc_hdnode_serialize_public(addr(node), chain, str, cast[cint](strsize))
  debug "extended pubkey: ", str
  return true

proc btc_hd_generate_key*(node: ptr btc_hdnode; keypath: cstring;
                         keymaster: ptr uint8_t; chaincode: ptr uint8_t;
                         usepubckd: btc_bool): btc_bool {.importc.}
type
  chainparams* = object
    chainname*: string
    b58prefix_pubkey_address*: uint8
    b58prefix_script_address*: uint8
    bech32_hrp*: string
    b58prefix_secret_address*: uint8
    b58prefix_bip32_privkey*: uint32
    b58prefix_bip32_pubkey*: uint32
    netmagic*: array[4, byte]
    genesisblockhash*: array[32, byte]
    default_port*: int32
    dnsseeds*: seq[string]


proc set_chainparams*(params: chainparams): btc_chainparams =
  var chain: btc_chainparams = btc_chainparams(
    b58prefix_pubkey_address: params.b58prefix_pubkey_address,
    b58prefix_script_address: params.b58prefix_script_address,
    b58prefix_secret_address: params.b58prefix_secret_address,
    b58prefix_bip32_privkey: params.b58prefix_bip32_privkey,
    b58prefix_bip32_pubkey: params.b58prefix_bip32_pubkey,
    default_port: params.default_port)

  zeroMem(addr chain.chainname, chain.chainname.len)
  for i, c in params.chainname:
    if i > chain.chainname.high:
      debug "ERROR[set_chainparams]: chainname too long"
      break
    chain.chainname[i] = c

  zeroMem(addr chain.bech32_hrp, chain.bech32_hrp.len)
  for i, c in params.bech32_hrp:
    if i > chain.bech32_hrp.high:
      debug "ERROR[set_chainparams]: bech32_hrp too long"
      break
    chain.bech32_hrp[i] = c

  zeroMem(addr chain.netmagic, chain.netmagic.len)
  for i, c in params.netmagic:
    if i > chain.netmagic.high:
      debug "ERROR[set_chainparams]: netmagic too long"
      break
    chain.netmagic[i] = cast[cuchar](c)

  zeroMem(addr chain.genesisblockhash, chain.genesisblockhash.len)
  for i, c in params.genesisblockhash:
    if i > chain.genesisblockhash.high:
      debug "ERROR[set_chainparams]: genesisblockhash too long"
      break
    chain.genesisblockhash[i] = c

  zeroMem(addr chain.dnsseeds, btc_dns_seed.domain.len * chain.dnsseeds.len)
  for i, seed in params.dnsseeds:
    if i > chain.dnsseeds.high:
      debug "ERROR[set_chainparams]: dnsseeds too long"
      break
    for j, c in seed:
      if j > chain.dnsseeds[i].domain.high:
        debug "ERROR[set_chainparams]: domain too long"
        break
      chain.dnsseeds[i].domain[j] = c
  chain

proc btc_ecc_sign_compact_recoverable*(private_key: ptr cuchar; hash: uint256;
                                      sigrec: ptr cuchar; outlen: ptr csize;
                                      #sigrec: ptr cuchar;
                                      recid: ptr cint): btc_bool {.importc.}

const
  SHA256_DIGEST_LENGTH = 32

#type
#  sha2_byte = uint8_t

proc sha256_Raw*(data: ptr cuchar; len: csize;
                digest: array[SHA256_DIGEST_LENGTH, uint8_t]) {.importc.}

proc btc_hash*(datain: ptr cuchar; length: csize; hashout: uint256) =
  sha256_Raw(datain, length, hashout)
  sha256_Raw(cast[ptr cuchar](unsafeAddr hashout), SHA256_DIGEST_LENGTH, hashout)

func var_uint*(n: uint64): seq =
  if n < 0xfd: @[uint8(n)]
  elif n <= 0xffff: concat(@[uint8(0xfd)], toSeq(cast[array[2, byte]](uint16(n))))
  elif n <= 0xffffffff'u64: concat(@[uint8(0xfe)], toSeq(cast[array[4, byte]](uint32(n))))
  else: concat(@[uint8(0xff)], toSeq(cast[array[8, byte]](uint64(n))))

var bitzeny_chainparams = chainparams(
  chainname: "main",
  b58prefix_pubkey_address: 0x51,
  b58prefix_script_address: 0x05,
  bech32_hrp: "sz",
  b58prefix_secret_address: 0x80,
  b58prefix_bip32_privkey: 0x0488ade4,
  b58prefix_bip32_pubkey: 0x0488b21e,
  netmagic: [byte 0xda, 0xad, 0xbe, 0xf9],
  genesisblockhash: [byte 0xce, 0xf5, 0xb8, 0x9f, 0x4e, 0xbf, 0x38, 0xa7,
                    0x3c, 0xd4, 0x40, 0x43, 0x9e, 0xda, 0xca, 0x4a,
                    0xfa, 0x7c, 0x7a, 0xd8, 0x2b, 0xe2, 0x81, 0x47,
                    0x3b, 0x9e, 0x5e, 0xe5, 0xf7, 0x09, 0x00, 0x00],
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
  netmagic: [byte 0x59, 0x45, 0x4e, 0x59],
  genesisblockhash: [byte 0x5c, 0x22, 0xde, 0x9b, 0x02, 0xe7, 0x15, 0x02,
                    0xfd, 0x7e, 0xdd, 0xa7, 0xb6, 0x1a, 0x54, 0x3c,
                    0xd2, 0x3f, 0xb6, 0x2e, 0xa2, 0x37, 0x7f, 0xdb,
                    0xbd, 0x95, 0xf5, 0x79, 0x0c, 0x3a, 0x00, 0x00],
  default_port: 19253,
  dnsseeds: @["testnet-seed.bitzeny.jp"])

var bitzeny_chain*: btc_chainparams = set_chainparams(bitzeny_chainparams)
var testnet_bitzeny_chain*: btc_chainparams = set_chainparams(testnet_bitzeny_chainparams)
