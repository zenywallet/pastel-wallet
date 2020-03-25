# Copyright (c) 2019 zenywallet

import sequtils, endians, algorithm, locks, logs
import rocksdblib
export rocksdblib.RocksDbErr

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

proc toString(s: openarray[byte]): string =
  result = newStringOfCap(len(s))
  for c in s:
    result.add(cast[char](c))

proc toUint(s: var seq[byte]): uint8 or uint16 or uint32 or uint64 =
  if s.len == 8:
    var b = newSeq[byte](8)
    bigEndian64(addr b[0], cast[ptr uint64](addr s[0]))
    result = cast[ptr uint64](addr b[0])[]
  elif s.len == 4:
    debug "s=4"
    var r32: uint32
    var b = newSeq[byte](4)
    bigEndian32(addr b[0], cast[ptr uint32](addr s[0]))
    r32 = cast[ptr uint32](addr b[0])[]
    result = r32
  elif s.len == 2:
    var b = newSeq[byte](2)
    bigEndian16(addr b[0], cast[ptr uint16](addr s[0]))
    result = cast[ptr uint16](addr b[0])[]
  elif s.len == 1:
    result = cast[uint8](s[0])

proc toUint64(s: var seq[byte]): uint64 =
  var b = newSeq[byte](8)
  bigEndian64(addr b[0], cast[ptr uint64](addr s[0]))
  result = cast[ptr uint64](addr b[0])[]

proc toUint32(s: var seq[byte]): uint32 =
  var b = newSeq[byte](4)
  bigEndian32(addr b[0], cast[ptr uint32](addr s[0]))
  result = cast[ptr uint32](addr b[0])[]

proc toUint16(s: var seq[byte]): uint16 =
  var b = newSeq[byte](2)
  bigEndian16(addr b[0], cast[ptr uint16](addr s[0]))
  result = cast[ptr uint16](addr b[0])[]

proc toUint8(s: var seq[byte]): uint8 =
  result = cast[uint8](s[0])

proc toUint64(a: openarray[byte]): uint64 =
  var s = a.toSeq
  var b = newSeq[byte](8)
  bigEndian64(addr b[0], cast[ptr uint64](addr s[0]))
  result = cast[ptr uint64](addr b[0])[]

proc toUint32(a: openarray[byte]): uint32 =
  var s = a.toSeq
  var b = newSeq[byte](4)
  bigEndian32(addr b[0], cast[ptr uint32](addr s[0]))
  result = cast[ptr uint32](addr b[0])[]

proc toUint16(a: openarray[byte]): uint16 =
  var s = a.toSeq
  var b = newSeq[byte](2)
  bigEndian16(addr b[0], cast[ptr uint16](addr s[0]))
  result = cast[ptr uint16](addr b[0])[]

proc toUint8(a: openarray[byte]): uint8 =
  result = cast[uint8](a[0])

proc toUint8(b: byte): uint8 =
  result = cast[uint8](b)

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

proc delTable*(prefix: Prefix): uint64 {.discardable.} =
  let key = prefix.toByte
  var count = 0'u64
  for d in db.gets(key):
    db.del(d.key)
    inc(count)
  count

proc setXpub(wid: uint64, xpub: string) =
  let key = concat(Prefix.xpubs.toByte, wid.toByte)
  let val = xpub.toByte
  db.put(key, val)

proc getXpub*(wid: uint64): tuple[err: DbStatus, res: string] =
  let key = concat(Prefix.xpubs.toByte, wid.toByte)
  var d = db.get(key)
  if d.len > 0:
    result = (DbStatus.Success, d.toString)
  else:
    result = (DbStatus.NotFound, cast[string](nil))

proc delXpub(wid: uint64) =
  let key = concat(Prefix.xpubs.toByte, wid.toByte)
  db.del(key)

proc delXpubs() =
  let key = Prefix.xpubs.toByte
  for d in db.gets(key):
    db.del(d.key)

proc setWallet*(xpubkey: string, wid: uint64, sequence: uint64,
                next_0_index: uint32, next_1_index: uint32) =
  let key = concat(Prefix.wallets.toByte,
                  xpubkey.toByte,
                  wid.toByte)
  let val = concat(sequence.toByte,
                  next_0_index.toByte,
                  next_1_index.toByte)
  db.put(key, val)
  setXpub(wid, xpubkey)

proc getWallet*(xpubkey: string): tuple[err: DbStatus,
                res: tuple[wallet_id: uint64, sequence: uint64,
                next_0_index: uint32, next_1_index: uint32]] =
  let key = concat(Prefix.wallets.toByte, xpubkey.toByte)
  var d = db.gets(key)
  if d.len > 0:
    let wid = d[0].key[^8..^1].toUint64
    let sequence = d[0].value[0..7].toUint64
    let next_0_index = d[0].value[8..11].toUint32
    let next_1_index = d[0].value[12..15].toUint32
    result = (DbStatus.Success, (wid, sequence, next_0_index, next_1_index))
  else:
    result = (DbStatus.NotFound, (cast[uint64](nil), cast[uint64](nil),
              cast[uint32](nil), cast[uint32](nil)))

proc getWallet*(wid: uint64): tuple[err: DbStatus,
                res: tuple[xpubkey: string, sequence: uint64,
                next_0_index: uint32, next_1_index: uint32]] =
  let ret_xpub = getXpub(wid)
  if ret_xpub.err == DbStatus.Success:
    let xpubkey = ret_xpub.res
    let key = concat(Prefix.wallets.toByte, xpubkey.toByte)
    var d = db.gets(key)
    if d.len > 0:
      let chk_wid = d[0].key[^8..^1].toUint64
      if chk_wid == wid:
        let sequence = d[0].value[0..7].toUint64
        let next_0_index = d[0].value[8..11].toUint32
        let next_1_index = d[0].value[12..15].toUint32
        result = (DbStatus.Success, (xpubkey, sequence, next_0_index, next_1_index))
        return
  result = (DbStatus.NotFound, (cast[string](nil), cast[uint64](nil),
            cast[uint32](nil), cast[uint32](nil)))

iterator getWallets*(xpubkey: string): tuple[xpubkey: string,
                    wallet_id: uint64, sequence: uint64,
                    next_0_index: uint32, next_1_index: uint32] =
  let key = concat(Prefix.wallets.toByte, xpubkey.toByte)
  for d in db.gets(key):
    let xpubkey = d.key[1..^9].toString
    let wid = d.key[^8..^1].toUint64
    let sequence = d.value[0..7].toUint64
    let next_0_index = d.value[8..11].toUint32
    let next_1_index = d.value[12..15].toUint32
    yield (xpubkey, wid, sequence, next_0_index, next_1_index)

proc delWallets*() =
  delTable(Prefix.wallets)
  delTable(Prefix.xpubs)

var createWalletLock: Lock
initLock(createWalletLock)

var wallet_id: uint64

proc loadWalletId() =
  let (err, wid) = getParamUint64(0)
  if err == DbStatus.Success:
    wallet_id = wid
  else:
    wallet_id = 0
  debug "load wallet_id=", wallet_id

proc acquireWalletId(): uint64 =
  inc(wallet_id)
  setParam(0, wallet_id)
  result = wallet_id

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
  let key = concat(Prefix.hdaddrs.toByte,
                  wid.toByte,
                  change.toByte,
                  index.toByte,
                  address.toByte)
  let val = sequence.toByte
  db.put(key, val)

iterator getHdaddrs*(wid: uint64): tuple[change: uint32,
                    index: uint32, address: string, sequence: uint64] =
  let key = concat(Prefix.hdaddrs.toByte, wid.toByte)
  for d in db.gets(key):
    let change = d.key[9..12].toUint32
    let index = d.key[13..16].toUint32
    let address = d.key[17..^1].toString
    let sequence = d.value.toUint64
    yield (change, index, address, sequence)

proc setAddress*(address: string, change: uint32, index: uint32,
                wid: uint64, sequence: uint64) =
  let key = concat(Prefix.addresses.toByte,
                  address.toByte,
                  change.toByte,
                  index.toByte,
                  wid.toByte)
  let val = sequence.toByte
  db.put(key, val)
  setHdaddr(wid, change, index, address, sequence)

iterator getAddresses*(address: string): tuple[change: uint32,
                      index: uint32, wid: uint64, sequence: uint64] =
  let key = concat(Prefix.addresses.toByte, address.toByte)
  for d in db.gets(key):
    let change = d.key[^16..^13].toUint32
    let index = d.key[^12..^9].toUint32
    let wid = d.key[^8..^1].toUint64
    let sequence = d.value.toUint64
    yield (change, index, wid, sequence)

iterator getAddresses*(wid: uint64): tuple[change: uint32,
                      index: uint32, address: string, sequence: uint64] =
  let key = concat(Prefix.hdaddrs.toByte, wid.toByte)
  for d in db.gets(key):
    let change = d.key[9..12].toUint32
    let index = d.key[13..16].toUint32
    let address = d.key[17..^1].toString
    let sequence = d.value.toUint64
    yield (change, index, address, sequence)

iterator getAddresses*(): tuple[address: string, change: uint32,
                      index: uint32, wid: uint64, sequence: uint64] =
  let key = Prefix.addresses.toByte
  for d in db.gets(key):
    let address = d.key[1..^17].toString
    let change = d.key[^16..^13].toUint32
    let index = d.key[^12..^9].toUint32
    let wid = d.key[^8..^1].toUint64
    let sequence = d.value.toUint64
    yield (address, change, index, wid, sequence)

proc setAddrval*(wid: uint64, change: uint32, index: uint32,
                address: string, value: uint64, utxo_count: uint32) =
  let key = concat(Prefix.addrvals.toByte, wid.toByte,
                  change.toByte, index.toByte, address.toByte)
  let val = concat(value.toByte, utxo_count.toByte)
  db.put(key, val)

iterator getAddrvals*(wid: uint64): tuple[change: uint32,
                      index: uint32, address: string,
                      value: uint64, utxo_cunt: uint32] =
  let key = concat(Prefix.addrvals.toByte, wid.toByte)
  for d in db.gets(key):
    let change = d.key[9..12].toUint32
    let index = d.key[13..16].toUint32
    let address = d.key[17..^1].toString
    let value = d.value[0..7].toUint64
    let utxo_count = d.value[8..11].toUint32
    yield (change, index, address, value, utxo_count)

proc delAddrval*(wid: uint64, change: uint32, index: uint32, address: string) =
  let key = concat(Prefix.addrvals.toByte, wid.toByte,
                  change.toByte, index.toByte, address.toByte)
  db.del(key)

proc setAddrlog*(wid: uint64, sequence: uint64, txtype: uint8,
                change: uint32, index: uint32, address: string,
                value: uint64, txid: string, height: uint32, time: uint32) =
  let key = concat(Prefix.addrlogs.toByte, wid.toByte,
                  sequence.toByte, txtype.toByte,
                  change.toByte, index.toByte, address.toByte)
  let val = concat(value.toByte, txid.toByte, height.toByte, time.toByte)
  db.put(key, val)

iterator getAddrlogs*(wid: uint64): tuple[sequence: uint64, txtype: uint8,
                change: uint32, index: uint32, address: string,
                value: uint64, txid: string, height: uint32, time: uint32] =
  let key = concat(Prefix.addrlogs.toByte, wid.toByte)
  for d in db.gets(key):
    let sequence = d.key[9..16].toUint64
    let txtype = d.key[17].toUint8
    let change = d.key[18..21].toUint32
    let index = d.key[22..25].toUint32
    let address = d.key[26..^1].toString
    let value = d.value[0..7].toUint64
    let txid = d.value[8..^9].toString
    let height = d.value[^8..^5].toUint32
    let time = d.value[^4..^1].toUint32
    yield (sequence, txtype, change, index, address, value, txid, height, time)

iterator getAddrlogs_gt*(wid: uint64, sequence: uint64): tuple[
                        sequence: uint64, txtype: uint8, change: uint32,
                        index: uint32, address: string, value: uint64,
                        txid: string, height: uint32, time: uint32] =
  let key = concat(Prefix.addrlogs.toByte, wid.toByte, sequence.toByte)
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
      let d_value = d.value[0..7].toUint64
      let d_txid = d.value[8..^9].toString
      let d_height = d.value[^8..^5].toUint32
      let d_time = d.value[^4..^1].toUint32
      yield (d_sequence, d_txtype, d_change, d_index, d_address, d_value,
            d_txid, d_height, d_time)

iterator getAddrlogsReverse*(wid: uint64): tuple[
                            sequence: uint64, txtype: uint8, change: uint32,
                            index: uint32, address: string, value: uint64,
                            txid: string, height: uint32, time: uint32] =
  let key = concat(Prefix.addrlogs.toByte, wid.toByte)
  for d in db.getsReverse(key):
    let sequence = d.key[9..16].toUint64
    let txtype = d.key[17].toUint8
    let change = d.key[18..21].toUint32
    let index = d.key[22..25].toUint32
    let address = d.key[26..^1].toString
    let value = d.value[0..7].toUint64
    let txid = d.value[8..^9].toString
    let height = d.value[^8..^5].toUint32
    let time = d.value[^4..^1].toUint32
    yield (sequence, txtype, change, index, address, value, txid, height, time)

iterator getAddrlogsReverse_lt*(wid: uint64, sequence: uint64): tuple[
                                sequence: uint64, txtype: uint8, change: uint32,
                                index: uint32, address: string, value: uint64,
                                txid: string, height: uint32, time: uint32] =
  let key = concat(Prefix.addrlogs.toByte, wid.toByte, sequence.toByte)
  for d in db.getsReverse_nobreak(key):
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
      let d_value = d.value[0..7].toUint64
      let d_txid = d.value[8..^9].toString
      let d_height = d.value[^8..^5].toUint32
      let d_time = d.value[^4..^1].toUint32
      yield (d_sequence, d_txtype, d_change, d_index, d_address, d_value,
            d_txid, d_height, d_time)

proc delAddrlogs*(wid: uint64, sequence: uint64) =
  let key = concat(Prefix.addrlogs.toByte, wid.toByte, sequence.toByte)
  db.dels(key)

proc delAddrlogs_gt*(wid: uint64, sequence: uint64) =
  let key = concat(Prefix.addrlogs.toByte, wid.toByte, sequence.toByte)
  for d in db.gets_nobreak(key):
    let prefix = d.key[0].toUint8
    let d_wid = d.key[1..8]
    if Prefix(prefix) != Prefix.addrlogs or d_wid.toUint64 != wid:
      break
    let d_sequence = d.key[9..16]
    if d_sequence.toUint64 > sequence:
      let d_txtype = d.key[17].toByte
      let d_change = d.key[18..21]
      let d_index = d.key[22..25]
      let d_address = d.key[26..^1]
      let d_key = concat(Prefix.addrlogs.toByte, d_wid, d_sequence,
                        d_txtype, d_change, d_index, d_address)
      db.del(d_key)

proc setUnspent*(wid: uint64, sequence: uint64, txid: string, n: uint32,
                address: string, value: uint64) =
  let key = concat(Prefix.unspents.toByte, wid.toByte,
                  sequence.toByte, txid.toByte, n.toByte)
  let val = concat(address.toByte, value.toByte)
  db.put(key, val)

iterator getUnspents*(wid: uint64): tuple[sequence: uint64, txid: string,
                      n: uint32, address: string, value: uint64] =
  let key = concat(Prefix.unspents.toByte, wid.toByte)
  for d in db.gets(key):
    let sequence = d.key[9..16].toUint64
    let txid = d.key[17..^5].toString
    let n = d.key[^4..^1].toUint32
    let address = d.value[0..^9].toString
    let value = d.value[^8..^1].toUint64
    yield (sequence, txid, n, address, value)

iterator getUnspents_gt*(wid: uint64, sequence: uint64): tuple[
                        sequence: uint64, txid: string, n: uint32,
                        address: string, value: uint64] =
  let key = concat(Prefix.unspents.toByte, wid.toByte, sequence.toByte)
  for d in db.gets_nobreak(key):
    let prefix = d.key[0].toUint8
    let d_wid = d.key[1..8]
    if Prefix(prefix) != Prefix.addrlogs or d_wid.toUint64 != wid:
      break
    let d_sequence = d.key[9..16].toUint64
    if d_sequence > sequence:
      let d_txid = d.key[17..^5].toString
      let d_n = d.key[^4..^1].toUint32
      let d_address = d.value[0..^9].toString
      let d_value = d.value[^8..^1].toUint64
      yield (d_sequence, d_txid, d_n, d_address, d_value)

proc delUnspents*(wid: uint64, sequence: uint64) =
  let key = concat(Prefix.unspents.toByte, wid.toByte, sequence.toByte)
  db.dels(key)

proc delUnspents_gt*(wid: uint64, sequence: uint64) =
  let key = concat(Prefix.unspents.toByte, wid.toByte, sequence.toByte)
  for d in db.gets_nobreak(key):
    let prefix = d.key[0].toUint8
    let d_wid = d.key[1..8]
    if Prefix(prefix) != Prefix.unspents or d_wid.toUint64 != wid:
      break
    let d_sequence = d.key[9..16]
    if d_sequence.toUint64 > sequence:
      let txid = d.key[17..^5]
      let n = d.key[^4..^1]
      let d_key = concat(Prefix.unspents.toByte, d_wid, d_sequence, txid, n)
      db.del(d_key)

proc setBalance*(wid: uint64, value: uint64, utxo_count: uint32,
                address_count: uint32) =
  let key = concat(Prefix.balances.toByte, wid.toByte)
  let val = concat(value.toByte, utxo_count.toByte, address_count.toByte)
  db.put(key, val)

proc getBalance*(wid: uint64): tuple[err: DbStatus,
                res: tuple[value: uint64, utxo_cunt: uint32,
                address_count: uint32]] =
  let key = concat(Prefix.balances.toByte, wid.toByte)
  var d = db.get(key)
  if d.len > 0:
    let value = d[0..7].toUint64
    let utxo_count = d[8..11].toUint32
    let address_count = d[12..15].toUint32
    result = (DbStatus.Success, (value, utxo_count, address_count))
  else:
    result = (DbStatus.NotFound, (cast[uint64](nil), cast[uint32](nil),
              cast[uint32](nil)))

proc delBalance*(wid: uint64) =
  let key = concat(Prefix.balances.toByte, wid.toByte)
  db.del(key)

proc setTxtime*(txid: string, trans_time: uint64) =
  let key = concat(Prefix.txtimes.toByte, txid.toByte)
  let val = trans_time.toByte
  db.put(key, val)

proc getTxtime*(txid: string): tuple[err: DbStatus, res: uint64] =
  let key = concat(Prefix.txtimes.toByte, txid.toByte)
  var d = db.get(key)
  if d.len > 0:
    let trans_time = d.toUint64
    result = (DbStatus.Success, trans_time)
  else:
    result = (DbStatus.NotFound, cast[uint64](nil))

proc delTxtime*(txid: string) =
  let key = concat(Prefix.txtimes.toByte, txid.toByte)
  db.del(key)

proc getLastUsedAddrIndex*(wid: uint64, change: uint32): tuple[err: DbStatus, res: uint32] =
  result = (DbStatus.NotFound, cast[uint32](nil))
  let key = concat(Prefix.addrvals.toByte, wid.toByte, change.toByte)
  for d in db.getsReverse(key):
    result = (DbStatus.Success, d.key[13..16].toUint32)
    break

block start:
  debug "db open"
  db.open(".pasteldb", ".pasteldb_backup")

  proc quit() {.noconv.} =
    db.close()
    debug "db close"

  addQuitProc(quit)
  loadWalletId()

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

  let key1 = concat(Prefix.rewards.toByte, 10'u64.toByte)
  let val1 = 5'u64.toByte
  db.put(key1, val1)
  echo db.get(key1)
  db.del(key1)
  echo db.get(key1)
  db.put(key1, val1)

  for i in 1..10:
    let k = concat(Prefix.rewards.toByte, cast[uint64](i * 10).toByte)
    let v = cast[uint64](i * 10).toByte
    db.put(k, v)

  var i = 0
  for d in db.gets_nobreak(Prefix.rewards.toByte):
    echo "d=", d
    inc(i)
    if i > 3:
      break

  let key2 = Prefix.rewards.toByte
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
