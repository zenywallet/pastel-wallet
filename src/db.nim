# Copyright (c) 2019 zenywallet

import sequtils, endians, locks, logs
import rocksdblib
export rocksdblib.RocksDbErr
import std/exitprocs

type Prefix* {.pure.} = enum
  params = 0  # param_id = value
              # 1 - last_wallet_id'u64 = value
              # 2 - last_hashcash_id'u64 = value
  wallets     # xpubkey, wallet_id = sequence, next_0_index, next_1_index
  addresses   # address, change, index, wallet_id = sequence
  addrvals    # wallet_id, change, index, address = value, utxo_count
  addrlogs    # wallet_id, sequence, type (0 - out | 1 - in),
              #   change, index, address = value, txid, height, time
  unspents    # wallet_id, sequence, txid, n = address, value
  balances    # wallet_id = value, utxo_count, address_count
  txtimes     # txid = transmission_time
  xpubs       # wallet_id = xpubkey
  hdaddrs     # wallet_id, change, index, address = sequence
  rawtxs      # txid = rawtx, transmission_time
  hashcash    # hashcash_id = header_block(80bytes)
              #               version(4), previous_block(32), merkle_root(32),
              #               time(4), bits(4), nonce(4)
  submits     # hashcash_id = header_block_submit, wallet_id
  unconfs     # hashcash_id = confirm_count, fail_count
  confirms    # wallet_id, hashcash_id = header_block_submit,
              #                          confirm_count, fail_count
  rewards     # wallet_id = hashcash_point, hashcash_total


type
  DbStatus* {.pure.} = enum
    Success = 0
    Error
    NotFound

  DbResult*[T] = object
    case err*: DbStatus
    of DbStatus.Success:
      res*: T
    of DbStatus.Error:
      discard
    of DbStatus.NotFound:
      discard

var db: RocksDb

proc toBytes[T](x: var T): seq[byte] {.inline.} =
  when T is uint8:
    @[byte x]
  else:
    result = newSeq[byte](sizeof(T))
    when T is uint16:
      bigEndian16(addr result[0], addr x)
    elif T is uint32:
      bigEndian32(addr result[0], addr x)
    elif T is uint64:
      bigEndian64(addr result[0], addr x)
    else:
      raiseAssert("unsupported type")

proc toBytes[T](x: T): seq[byte] {.inline.} =
  when T is uint8:
    @[byte x]
  else:
    var v = x
    v.toBytes

proc toBytes(val: Prefix): seq[byte] {.inline.} = @[byte val]

proc toBytes(s: string): seq[byte] {.inline.} = cast[seq[byte]](s.toSeq)

proc toString(s: openarray[byte]): string =
  result = newStringOfCap(len(s))
  for c in s:
    result.add(cast[char](c))

proc toUint64(s: var seq[byte]): uint64 =
  var b = newSeq[byte](8)
  bigEndian64(addr b[0], cast[ptr uint64](addr s[0]))
  cast[ptr uint64](addr b[0])[]

proc toUint32(s: var seq[byte]): uint32 =
  var b = newSeq[byte](4)
  bigEndian32(addr b[0], cast[ptr uint32](addr s[0]))
  cast[ptr uint32](addr b[0])[]

proc toUint16(s: var seq[byte]): uint16 =
  var b = newSeq[byte](2)
  bigEndian16(addr b[0], cast[ptr uint16](addr s[0]))
  cast[ptr uint16](addr b[0])[]

proc toUint8(s: var seq[byte]): uint8 =
  cast[uint8](s[0])

proc toUint64(a: openarray[byte]): uint64 =
  var s = a.toSeq
  var b = newSeq[byte](8)
  bigEndian64(addr b[0], cast[ptr uint64](addr s[0]))
  cast[ptr uint64](addr b[0])[]

proc toUint32(a: openarray[byte]): uint32 =
  var s = a.toSeq
  var b = newSeq[byte](4)
  bigEndian32(addr b[0], cast[ptr uint32](addr s[0]))
  cast[ptr uint32](addr b[0])[]

proc toUint16(a: openarray[byte]): uint16 =
  var s = a.toSeq
  var b = newSeq[byte](2)
  bigEndian16(addr b[0], cast[ptr uint16](addr s[0]))
  cast[ptr uint16](addr b[0])[]

proc toUint8(a: openarray[byte]): uint8 = cast[uint8](a[0])

proc toUint8(b: byte): uint8 = cast[uint8](b)

proc setParam*(param_id: uint32, value: uint32) =
  let key = concat(Prefix.params.toBytes, param_id.toBytes)
  let value = value.toBytes
  db.put(key, value)

proc setParam*(param_id: uint32, value: uint64) =
  let key = concat(Prefix.params.toBytes, param_id.toBytes)
  let value = value.toBytes
  db.put(key, value)

proc setParam*(param_id: uint32, value: string) =
  let key = concat(Prefix.params.toBytes, param_id.toBytes)
  let value = value.toBytes
  db.put(key, value)

proc getParamUint32*(param_id: uint32): DbResult[uint32] =
  let key = concat(Prefix.params.toBytes, param_id.toBytes)
  var d = db.get(key)
  if d.len == 4:
    var b = newSeq[byte](4)
    bigEndian32(addr b[0], cast[ptr uint32](addr d[0]))
    DbResult[uint32](err: DbStatus.Success, res: cast[ptr uint32](addr b[0])[])
  else:
    DbResult[uint32](err: DbStatus.NotFound)

proc getParamUint64*(param_id: uint32): DbResult[uint64] =
  let key = concat(Prefix.params.toBytes, param_id.toBytes)
  var d = db.get(key)
  if d.len == 8:
    var b = newSeq[byte](8)
    bigEndian64(addr b[0], cast[ptr uint64](addr d[0]))
    DbResult[uint64](err: DbStatus.Success, res: cast[ptr uint64](addr b[0])[])
  else:
    DbResult[uint64](err: DbStatus.NotFound)
  
proc getParamString*(param_id: uint32): DbResult[string] =
  let key = concat(Prefix.params.toBytes, param_id.toBytes)
  var d = db.get(key)
  if d.len > 0:
    DbResult[string](err: DbStatus.Success, res: d.toString)
  else:
    DbResult[string](err: DbStatus.NotFound)

proc delTable*(prefix: Prefix): uint64 {.discardable.} =
  let key = prefix.toBytes
  var count = 0'u64
  for d in db.gets(key):
    db.del(d.key)
    inc(count)
  count

proc setXpub(wid: uint64, xpub: string) =
  let key = concat(Prefix.xpubs.toBytes, wid.toBytes)
  let val = xpub.toBytes
  db.put(key, val)

proc getXpub*(wid: uint64): DbResult[string] =
  let key = concat(Prefix.xpubs.toBytes, wid.toBytes)
  var d = db.get(key)
  if d.len > 0:
    DbResult[string](err: DbStatus.Success, res: d.toString)
  else:
    DbResult[string](err: DbStatus.NotFound)

proc delXpub(wid: uint64) =
  let key = concat(Prefix.xpubs.toBytes, wid.toBytes)
  db.del(key)

proc delXpubs() =
  let key = Prefix.xpubs.toBytes
  for d in db.gets(key):
    db.del(d.key)

proc setWallet*(xpubkey: string, wid: uint64, sequence: uint64,
                next_0_index: uint32, next_1_index: uint32) =
  let key = concat(Prefix.wallets.toBytes,
                  xpubkey.toBytes,
                  wid.toBytes)
  let val = concat(sequence.toBytes,
                  next_0_index.toBytes,
                  next_1_index.toBytes)
  db.put(key, val)
  setXpub(wid, xpubkey)

type
  WalletXpubkeyResult* = tuple[wallet_id: uint64, sequence: uint64,
                              next_0_index: uint32, next_1_index: uint32]

proc getWallet*(xpubkey: string): DbResult[WalletXpubkeyResult] =
  let key = concat(Prefix.wallets.toBytes, xpubkey.toBytes)
  var d = db.gets(key)
  if d.len > 0 and xpubkey == d[0].key[1..^9].toString:
    let wid = d[0].key[^8..^1].toUint64
    let sequence = d[0].val[0..7].toUint64
    let next_0_index = d[0].val[8..11].toUint32
    let next_1_index = d[0].val[12..15].toUint32
    DbResult[WalletXpubkeyResult](err: DbStatus.Success, res: (wid, sequence, next_0_index, next_1_index))
  else:
    DbResult[WalletXpubkeyResult](err: DbStatus.NotFound)

type
  WalletWidResult* = tuple[xpubkey: string, sequence: uint64,
                          next_0_index: uint32, next_1_index: uint32]

proc getWallet*(wid: uint64): DbResult[WalletWidResult] =
  let ret_xpub = getXpub(wid)
  if ret_xpub.err == DbStatus.Success:
    let xpubkey = ret_xpub.res
    let key = concat(Prefix.wallets.toBytes, xpubkey.toBytes)
    var d = db.gets(key)
    if d.len > 0:
      let chk_wid = d[0].key[^8..^1].toUint64
      if chk_wid == wid:
        let sequence = d[0].val[0..7].toUint64
        let next_0_index = d[0].val[8..11].toUint32
        let next_1_index = d[0].val[12..15].toUint32
        return DbResult[WalletWidResult](err: DbStatus.Success, res: (xpubkey, sequence, next_0_index, next_1_index))
  DbResult[WalletWidResult](err: DbStatus.NotFound)

iterator getWallets*(xpubkey: string): tuple[xpubkey: string,
                    wallet_id: uint64, sequence: uint64,
                    next_0_index: uint32, next_1_index: uint32] =
  let key = concat(Prefix.wallets.toBytes, xpubkey.toBytes)
  for d in db.gets(key):
    let xpubkey = d.key[1..^9].toString
    let wid = d.key[^8..^1].toUint64
    let sequence = d.val[0..7].toUint64
    let next_0_index = d.val[8..11].toUint32
    let next_1_index = d.val[12..15].toUint32
    yield (xpubkey, wid, sequence, next_0_index, next_1_index)

proc delWallets*() =
  delTable(Prefix.wallets)
  delTable(Prefix.xpubs)

var createWalletLock: Lock
initLock(createWalletLock)

var wallet_id: uint64

proc loadWalletId() =
  let dbResult = getParamUint64(0)
  if dbResult.err == DbStatus.Success:
    wallet_id = dbResult.res
  else:
    wallet_id = 0
  debug "load wallet_id=", wallet_id

proc acquireWalletId(): uint64 =
  inc(wallet_id)
  setParam(0, wallet_id)
  wallet_id

proc getOrCreateWallet*(xpubkey: string): tuple[wallet_id: uint64,
                        sequence: uint64, next_0_index: uint32,
                        next_1_index: uint32] =
  withLock createWalletLock:
    let d = getWallet(xpubkey)
    if d.err == DbStatus.Success:
      result = d.res
    else:
      setWallet(xpubkey, acquireWalletId(), 0, 0, 0)
      let d2 = getWallet(xpubkey)
      result = d2.res

proc setHdaddr(wid: uint64, change: uint32, index: uint32,
              address: string, sequence: uint64) =
  let key = concat(Prefix.hdaddrs.toBytes,
                  wid.toBytes,
                  change.toBytes,
                  index.toBytes,
                  address.toBytes)
  let val = sequence.toBytes
  db.put(key, val)

iterator getHdaddrs*(wid: uint64): tuple[change: uint32,
                    index: uint32, address: string, sequence: uint64] =
  let key = concat(Prefix.hdaddrs.toBytes, wid.toBytes)
  for d in db.gets(key):
    let change = d.key[9..12].toUint32
    let index = d.key[13..16].toUint32
    let address = d.key[17..^1].toString
    let sequence = d.val.toUint64
    yield (change, index, address, sequence)

proc setAddress*(address: string, change: uint32, index: uint32,
                wid: uint64, sequence: uint64) =
  let key = concat(Prefix.addresses.toBytes,
                  address.toBytes,
                  change.toBytes,
                  index.toBytes,
                  wid.toBytes)
  let val = sequence.toBytes
  db.put(key, val)
  setHdaddr(wid, change, index, address, sequence)

iterator getAddresses*(address: string): tuple[change: uint32,
                      index: uint32, wid: uint64, sequence: uint64] =
  let key = concat(Prefix.addresses.toBytes, address.toBytes)
  for d in db.gets(key):
    let change = d.key[^16..^13].toUint32
    let index = d.key[^12..^9].toUint32
    let wid = d.key[^8..^1].toUint64
    let sequence = d.val.toUint64
    yield (change, index, wid, sequence)

iterator getAddresses*(wid: uint64): tuple[change: uint32,
                      index: uint32, address: string, sequence: uint64] =
  let key = concat(Prefix.hdaddrs.toBytes, wid.toBytes)
  for d in db.gets(key):
    let change = d.key[9..12].toUint32
    let index = d.key[13..16].toUint32
    let address = d.key[17..^1].toString
    let sequence = d.val.toUint64
    yield (change, index, address, sequence)

iterator getAddresses*(): tuple[address: string, change: uint32,
                      index: uint32, wid: uint64, sequence: uint64] =
  let key = Prefix.addresses.toBytes
  for d in db.gets(key):
    let address = d.key[1..^17].toString
    let change = d.key[^16..^13].toUint32
    let index = d.key[^12..^9].toUint32
    let wid = d.key[^8..^1].toUint64
    let sequence = d.val.toUint64
    yield (address, change, index, wid, sequence)

proc setAddrval*(wid: uint64, change: uint32, index: uint32,
                address: string, value: uint64, utxo_count: uint32) =
  let key = concat(Prefix.addrvals.toBytes, wid.toBytes,
                  change.toBytes, index.toBytes, address.toBytes)
  let val = concat(value.toBytes, utxo_count.toBytes)
  db.put(key, val)

iterator getAddrvals*(wid: uint64): tuple[change: uint32,
                      index: uint32, address: string,
                      value: uint64, utxo_cunt: uint32] =
  let key = concat(Prefix.addrvals.toBytes, wid.toBytes)
  for d in db.gets(key):
    let change = d.key[9..12].toUint32
    let index = d.key[13..16].toUint32
    let address = d.key[17..^1].toString
    let value = d.val[0..7].toUint64
    let utxo_count = d.val[8..11].toUint32
    yield (change, index, address, value, utxo_count)

proc delAddrval*(wid: uint64, change: uint32, index: uint32, address: string) =
  let key = concat(Prefix.addrvals.toBytes, wid.toBytes,
                  change.toBytes, index.toBytes, address.toBytes)
  db.del(key)

proc setAddrlog*(wid: uint64, sequence: uint64, txtype: uint8,
                change: uint32, index: uint32, address: string,
                value: uint64, txid: string, height: uint32, time: uint32) =
  let key = concat(Prefix.addrlogs.toBytes, wid.toBytes,
                  sequence.toBytes, txtype.toBytes,
                  change.toBytes, index.toBytes, address.toBytes)
  let val = concat(value.toBytes, txid.toBytes, height.toBytes, time.toBytes)
  db.put(key, val)

iterator getAddrlogs*(wid: uint64): tuple[sequence: uint64, txtype: uint8,
                change: uint32, index: uint32, address: string,
                value: uint64, txid: string, height: uint32, time: uint32] =
  let key = concat(Prefix.addrlogs.toBytes, wid.toBytes)
  for d in db.gets(key):
    let sequence = d.key[9..16].toUint64
    let txtype = d.key[17].toUint8
    let change = d.key[18..21].toUint32
    let index = d.key[22..25].toUint32
    let address = d.key[26..^1].toString
    let value = d.val[0..7].toUint64
    let txid = d.val[8..^9].toString
    let height = d.val[^8..^5].toUint32
    let time = d.val[^4..^1].toUint32
    yield (sequence, txtype, change, index, address, value, txid, height, time)

iterator getAddrlogs_gt*(wid: uint64, sequence: uint64): tuple[
                        sequence: uint64, txtype: uint8, change: uint32,
                        index: uint32, address: string, value: uint64,
                        txid: string, height: uint32, time: uint32] =
  let key = concat(Prefix.addrlogs.toBytes, wid.toBytes, sequence.toBytes)
  for d in db.gets_nobreak(key):
    let prefix = d.key[0].toUint8
    let d_wid = d.key[1..8]
    if Prefix(prefix) != Prefix.addrlogs or d_wid.toUint64 != wid:
      break
    let d_sequence = d.key[9..16].toUint64
    if d_sequence > sequence:
      let d_txtype = d.key[17].toUint8
      let d_change = d.key[18..21].toUint32
      let d_index = d.key[22..25].toUint32
      let d_address = d.key[26..^1].toString
      let d_value = d.val[0..7].toUint64
      let d_txid = d.val[8..^9].toString
      let d_height = d.val[^8..^5].toUint32
      let d_time = d.val[^4..^1].toUint32
      yield (d_sequence, d_txtype, d_change, d_index, d_address, d_value,
            d_txid, d_height, d_time)

iterator getAddrlogsReverse*(wid: uint64): tuple[
                            sequence: uint64, txtype: uint8, change: uint32,
                            index: uint32, address: string, value: uint64,
                            txid: string, height: uint32, time: uint32] =
  let key = concat(Prefix.addrlogs.toBytes, wid.toBytes)
  for d in db.getsRev(key):
    let sequence = d.key[9..16].toUint64
    let txtype = d.key[17].toUint8
    let change = d.key[18..21].toUint32
    let index = d.key[22..25].toUint32
    let address = d.key[26..^1].toString
    let value = d.val[0..7].toUint64
    let txid = d.val[8..^9].toString
    let height = d.val[^8..^5].toUint32
    let time = d.val[^4..^1].toUint32
    yield (sequence, txtype, change, index, address, value, txid, height, time)

iterator getAddrlogsReverse_lt*(wid: uint64, sequence: uint64): tuple[
                                sequence: uint64, txtype: uint8, change: uint32,
                                index: uint32, address: string, value: uint64,
                                txid: string, height: uint32, time: uint32] =
  let key = concat(Prefix.addrlogs.toBytes, wid.toBytes, sequence.toBytes)
  for d in db.getsRev_nobreak(key):
    let prefix = d.key[0].toUint8
    let d_wid = d.key[1..8]
    if Prefix(prefix) != Prefix.addrlogs or d_wid.toUint64 != wid:
      break
    let d_sequence = d.key[9..16].toUint64
    if d_sequence < sequence:
      let d_txtype = d.key[17].toUint8
      let d_change = d.key[18..21].toUint32
      let d_index = d.key[22..25].toUint32
      let d_address = d.key[26..^1].toString
      let d_value = d.val[0..7].toUint64
      let d_txid = d.val[8..^9].toString
      let d_height = d.val[^8..^5].toUint32
      let d_time = d.val[^4..^1].toUint32
      yield (d_sequence, d_txtype, d_change, d_index, d_address, d_value,
            d_txid, d_height, d_time)

proc delAddrlogs*(wid: uint64, sequence: uint64) =
  let key = concat(Prefix.addrlogs.toBytes, wid.toBytes, sequence.toBytes)
  db.dels(key)

proc delAddrlogs_gt*(wid: uint64, sequence: uint64) =
  let key = concat(Prefix.addrlogs.toBytes, wid.toBytes, sequence.toBytes)
  for d in db.gets_nobreak(key):
    let prefix = d.key[0].toUint8
    let d_wid = d.key[1..8]
    if Prefix(prefix) != Prefix.addrlogs or d_wid.toUint64 != wid:
      break
    let d_sequence = d.key[9..16]
    if d_sequence.toUint64 > sequence:
      let d_txtype = d.key[17].toBytes
      let d_change = d.key[18..21]
      let d_index = d.key[22..25]
      let d_address = d.key[26..^1]
      let d_key = concat(Prefix.addrlogs.toBytes, d_wid, d_sequence,
                        d_txtype, d_change, d_index, d_address)
      db.del(d_key)

proc setUnspent*(wid: uint64, sequence: uint64, txid: string, n: uint32,
                address: string, value: uint64) =
  let key = concat(Prefix.unspents.toBytes, wid.toBytes,
                  sequence.toBytes, txid.toBytes, n.toBytes)
  let val = concat(address.toBytes, value.toBytes)
  db.put(key, val)

iterator getUnspents*(wid: uint64): tuple[sequence: uint64, txid: string,
                      n: uint32, address: string, value: uint64] =
  let key = concat(Prefix.unspents.toBytes, wid.toBytes)
  for d in db.gets(key):
    let sequence = d.key[9..16].toUint64
    let txid = d.key[17..^5].toString
    let n = d.key[^4..^1].toUint32
    let address = d.val[0..^9].toString
    let value = d.val[^8..^1].toUint64
    yield (sequence, txid, n, address, value)

iterator getUnspents_gt*(wid: uint64, sequence: uint64): tuple[
                        sequence: uint64, txid: string, n: uint32,
                        address: string, value: uint64] =
  let key = concat(Prefix.unspents.toBytes, wid.toBytes, sequence.toBytes)
  for d in db.gets_nobreak(key):
    let prefix = d.key[0].toUint8
    let d_wid = d.key[1..8]
    if Prefix(prefix) != Prefix.addrlogs or d_wid.toUint64 != wid:
      break
    let d_sequence = d.key[9..16].toUint64
    if d_sequence > sequence:
      let d_txid = d.key[17..^5].toString
      let d_n = d.key[^4..^1].toUint32
      let d_address = d.val[0..^9].toString
      let d_value = d.val[^8..^1].toUint64
      yield (d_sequence, d_txid, d_n, d_address, d_value)

proc delUnspents*(wid: uint64, sequence: uint64) =
  let key = concat(Prefix.unspents.toBytes, wid.toBytes, sequence.toBytes)
  db.dels(key)

proc delUnspents_gt*(wid: uint64, sequence: uint64) =
  let key = concat(Prefix.unspents.toBytes, wid.toBytes, sequence.toBytes)
  for d in db.gets_nobreak(key):
    let prefix = d.key[0].toUint8
    let d_wid = d.key[1..8]
    if Prefix(prefix) != Prefix.unspents or d_wid.toUint64 != wid:
      break
    let d_sequence = d.key[9..16]
    if d_sequence.toUint64 > sequence:
      let txid = d.key[17..^5]
      let n = d.key[^4..^1]
      let d_key = concat(Prefix.unspents.toBytes, d_wid, d_sequence, txid, n)
      db.del(d_key)

proc setBalance*(wid: uint64, value: uint64, utxo_count: uint32,
                address_count: uint32) =
  let key = concat(Prefix.balances.toBytes, wid.toBytes)
  let val = concat(value.toBytes, utxo_count.toBytes, address_count.toBytes)
  db.put(key, val)

type
  BalanceResult* = tuple[value: uint64, utxo_cunt: uint32, address_count: uint32]

proc getBalance*(wid: uint64): DbResult[BalanceResult] =
  let key = concat(Prefix.balances.toBytes, wid.toBytes)
  var d = db.get(key)
  if d.len > 0:
    let value = d[0..7].toUint64
    let utxo_count = d[8..11].toUint32
    let address_count = d[12..15].toUint32
    DbResult[BalanceResult](err: DbStatus.Success, res: (value, utxo_count, address_count))
  else:
    DbResult[BalanceResult](err: DbStatus.NotFound)

proc delBalance*(wid: uint64) =
  let key = concat(Prefix.balances.toBytes, wid.toBytes)
  db.del(key)

proc setTxtime*(txid: string, trans_time: uint64) =
  let key = concat(Prefix.txtimes.toBytes, txid.toBytes)
  let val = trans_time.toBytes
  db.put(key, val)

proc getTxtime*(txid: string): DbResult[uint64] =
  let key = concat(Prefix.txtimes.toBytes, txid.toBytes)
  var d = db.get(key)
  if d.len > 0:
    let trans_time = d.toUint64
    DbResult[uint64](err: DbStatus.Success, res: trans_time)
  else:
    DbResult[uint64](err: DbStatus.NotFound)

proc delTxtime*(txid: string) =
  let key = concat(Prefix.txtimes.toBytes, txid.toBytes)
  db.del(key)

proc getLastUsedAddrIndex*(wid: uint64, change: uint32): DbResult[uint32] =
  let key = concat(Prefix.addrvals.toBytes, wid.toBytes, change.toBytes)
  for d in db.getsRev(key):
    return DbResult[uint32](err: DbStatus.Success, res: d.key[13..16].toUint32)
  DbResult[uint32](err: DbStatus.NotFound)

var openFlag = false

proc start*() =
  debug "db open"
  db.open(".pasteldb", ".pasteldb_backup")
  openFlag = true
  loadWalletId()

proc stop*() =
  if openFlag:
    openFlag = false
    db.close()
    debug "db close"

proc quit() {.noconv.} =
  stop()

exitprocs.addExitProc(quit)

start()


when isMainModule:
  echo getWallet("test")
  echo getOrCreateWallet("test")
  echo getOrCreateWallet("test2")
  echo getOrCreateWallet("test2")
  echo getOrCreateWallet("test3")
  echo getOrCreateWallet("test3")
  for d in getWallets(""):
    echo d
  echo getOrCreateWallet("testtest")

  setAddress("address1", 0, 0, 1, 1)
  for d in getAddresses("address1"):
    echo d, " ", d.wid

  setAddrval(1, 0, 0, "address1", 100, 100)
  for d in getAddrvals(1):
    echo d

  setAddrlog(1, 1, 0, 0, 0, "address1", 200, "txid1", 2, 3)
  for d in getAddrlogs(1):
    echo d

  setUnspent(1, 1, "txid1", 5, "address1", 200)
  for d in getUnspents(1):
    echo d

  let key1 = concat(Prefix.rewards.toBytes, 10'u64.toBytes)
  let val1 = 5'u64.toBytes
  db.put(key1, val1)
  echo db.get(key1)
  db.del(key1)
  echo db.get(key1)
  db.put(key1, val1)

  for i in 1..10:
    let k = concat(Prefix.rewards.toBytes, cast[uint64](i * 10).toBytes)
    let v = cast[uint64](i * 10).toBytes
    db.put(k, v)

  var i = 0
  for d in db.gets_nobreak(Prefix.rewards.toBytes):
    echo "d=", d
    inc(i)
    if i > 3:
      break

  let key2 = Prefix.rewards.toBytes
  echo db.gets(key2)
  db.dels(key2)
  echo db.gets(key2)

  setBalance(1, 1, 2, 3)
  echo getBalance(1)
  delBalance(1)
  echo getBalance(1)

  setAddrval(1, 0, 0, "address1", 100, 100)
  setAddrval(1, 0, 1, "address2", 100, 100)
  setAddrval(1, 1, 2, "address1", 100, 100)
  setAddrval(1, 1, 3, "address2", 100, 100)
  echo getLastUsedAddrIndex(1, 0)
  echo getLastUsedAddrIndex(1, 1)
  echo getLastUsedAddrIndex(1, 2)
