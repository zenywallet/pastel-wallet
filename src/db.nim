# Copyright (c) 2019 zenywallet

import sequtils, endians, algorithm
import rocksdblib
export rocksdblib.RocksDbError

type Prefix {.pure.} = enum
  params = 0  # param_id = value
              # 1 - last_wallet_id'u64 = value
              # 2 - last_hashcash_id'u64 = value
  wallets     # xpubkey, wallet_id = sequence, last_0_index, last_1_index
  addresses   # address, change, index, wallet_id = sequence
  addrvals    # wallet_id, change, index, address = value, utxo_count
  addrlogs    # wallet_id, sequence, type (0 - out | 1 - in),
              #   change, index, address = value, txid, height, time
  unspents    # wallet_id, sequence, txid, n = address, value
  rawtxs      # txid = rawtx, transmission_time
  hashcash    # hashcash_id = header_block(80bytes)
              #               version(4), previous_block(32), merkle_root(32),
              #               time(4), bits(4), nonce(4)
  submits     # hashcash_id = header_block_submit, wallet_id
  unconfs     # hashcash_id = confirm_count, fail_count
  confirms    # wallet_id, hashcash_id = header_block_submit,
              #                          confirm_count, fail_count
  rewards     # wallet_id = hashcash_point, hashcash_total


type DbStatus* {.pure.} = enum
  Success = 0
  Error
  NotFound

var db: RocksDb

proc toByte(val: Prefix): seq[byte] = @[cast[byte](val)]

proc toByte(val: var uint8): seq[byte] = @[cast[byte](val)]

proc toByte(val: uint8): seq[byte] = @[cast[byte](val)]

proc toByte(s: string): seq[byte] = cast[seq[byte]](toSeq(s))

proc toByte(val: var uint16): seq[byte] =
  result = newSeq[byte](2)
  bigEndian16(addr result[0], addr val)

proc toByte(val: uint16): seq[byte] =
  result = newSeq[byte](2)
  var v: uint16 = val
  bigEndian16(addr result[0], addr v)

proc toByte(val: var uint32): seq[byte] =
  result = newSeq[byte](4)
  bigEndian32(addr result[0], addr val)

proc toByte(val: uint32): seq[byte] =
  result = newSeq[byte](4)
  var v: uint32 = val
  bigEndian32(addr result[0], addr v)

proc toByte(val: var uint64): seq[byte] =
  result = newSeq[byte](8)
  bigEndian64(addr result[0], addr val)

proc toByte(val: uint64): seq[byte] =
  result = newSeq[byte](8)
  var v: uint64 = val
  bigEndian64(addr result[0], addr v)

proc toString(s: seq[byte]): string =
  result = newStringOfCap(len(s))
  for c in s:
    result.add(cast[char](c))


proc setParam*(param_id: uint32, value: uint32) =
  let key = concat(Prefix.params.toByte, param_id.toByte)
  let value = value.toByte
  db.put(key, value)

proc setParam*(param_id: uint32, value: uint64) =
  let key = concat(Prefix.params.toByte, param_id.toByte)
  let value = value.toByte
  db.put(key, value)

proc setParam*(param_id: uint32, value: string) =
  let key = concat(Prefix.params.toByte, param_id.toByte)
  let value = value.toByte
  db.put(key, value)

proc getParamUint32*(param_id: uint32): tuple[err: DbStatus, res: uint32] =
  let key = concat(Prefix.params.toByte, param_id.toByte)
  var d = db.get(key)
  if d.len == 4:
    var b = newSeq[byte](4)
    bigEndian32(addr b[0], cast[ptr uint32](addr d[0]))
    (DbStatus.Success, cast[ptr uint32](addr b[0])[])
  else:
    (DbStatus.NotFound, cast[uint32](nil))

proc getParamUint64*(param_id: uint32): tuple[err: DbStatus, res: uint64] =
  let key = concat(Prefix.params.toByte, param_id.toByte)
  var d = db.get(key)
  if d.len == 8:
    var b = newSeq[byte](8)
    bigEndian64(addr b[0], cast[ptr uint64](addr d[0]))
    (DbStatus.Success, cast[ptr uint64](addr b[0])[])
  else:
    (DbStatus.NotFound, cast[uint64](nil))
  
proc getParamString*(param_id: uint32): tuple[err: DbStatus, res: string] =
  let key = concat(Prefix.params.toByte, param_id.toByte)
  var d = db.get(key)
  if d.len > 0:
    (DbStatus.Success, d.toString)
  else:
    (DbStatus.NotFound, cast[string](nil))


block start:
  echo "db open"
  db.open(".pasteldb")

  proc quit() {.noconv.} =
    db.close()
    echo "db close"

  addQuitProc(quit)
