# Copyright (c) 2019 zenywallet

import os, locks, asyncdispatch, sequtils, tables, random
from times import getTime, toUnix, nanosecond
import ../deps/"websocket.nim"/websocket
import libbtc
import blockstor, db, events, logs, stream

const gaplimit: uint32 = 20
const blockstor_apikey = "sample-969a6d71-a259-447c-a486-90bac964992b"
var chain = testnet_bitzeny_chain

var
  threads: array[3, Thread[void]]
  event = createEvent()
  active = true
  ready* = true

const extkeyout_size: csize = 128
const address_size: csize = 128
proc hdaddress(xpubkey: string, change, index: uint32): string =
  result = ""
  let keypath: cstring = "m/" & $change & "/" & $index
  var extkeyout: cstring = newString(extkeyout_size)
  if hd_derive(addr chain, xpubkey, keypath, extkeyout, extkeyout_size):
    var node: btc_hdnode
    if btc_hdnode_deserialize(extkeyout, addr chain, addr node):
      var address: cstring = newString(address_size)
      btc_hdnode_get_p2pkh_address(addr node, addr chain, address, cast[cint](address_size))
      result = $address

template enumRangeCheck(enumtype: type, value: int): bool =
  (enumtype.low.ord..enumtype.high.ord).contains(value)

proc timeseed() =
  let now = getTime()
  randomize(now.toUnix * 1000000000 + now.nanosecond)

type
  WalletInfo = ref object
    xpubkey: string
    wid: uint64
    sequence: uint64
    next_0_index: uint32
    next_1_index: uint32

  AddrInfo = ref object
    wid: uint64
    change: uint32
    index: uint32
    address: string

  AddrBalance = ref object
    balance: uint64
    utxo_count: uint32

proc addressFinder(sequence: uint64, last_sequence: uint64) =
  var walletInfos = initTable[uint64, WalletInfo]()
  var addrInfos: seq[AddrInfo]
  for d in db.getWallets(""):
    if sequence > d.sequence or d.sequence == 0'u64:

      var used_0_index: uint32 = 0
      var used_0 = db.getLastUsedAddrIndex(d.wallet_id, 0)
      if used_0.err == DbStatus.Success:
        used_0_index = used_0.res

      var used_1_index: uint32 = 0
      var used_1 = db.getLastUsedAddrIndex(d.wallet_id, 1)
      if used_1.err == DbStatus.Success:
        used_1_index = used_1.res

      var new_0_index = used_0_index + gaplimit
      var new_1_index = used_1_index + gaplimit
      for i in (d.next_0_index..<new_0_index):
        var address = hdaddress(d.xpubkey, 0, i)
        if address.len > 0:
          addrInfos.add(AddrInfo(wid: d.wallet_id, change: 0, index: i, address: address))
      for i in (d.next_1_index..<new_1_index):
        var address = hdaddress(d.xpubkey, 1, i)
        if address.len > 0:
          addrInfos.add(AddrInfo(wid: d.wallet_id, change: 1, index: i, address: address))

      if d.next_0_index < new_0_index or d.next_1_index < new_1_index:
        walletInfos[d.wallet_id] = WalletInfo(xpubkey: d.xpubkey,
                                  sequence: d.sequence,
                                  next_0_index: new_0_index,
                                  next_1_index: new_1_index)

  if addrInfos.len > 0:
    var addrs: seq[string]
    for a in addrInfos:
      addrs.add(a.address)
    timeseed()
    shuffle(addrs)

    var addrBalances = initTable[string, AddrBalance]()
    var split_addrs = addrs.distribute(1 + addrs.len div 50)
    for sa in split_addrs:
      let balance = blockstor.getAddress(sa)
      if sa.len == balance.resLen:
        var i = 0
        for b in balance.toApiResIterator:
          if b{"balance"} != nil:
            addrBalances[sa[i]] = AddrBalance(balance: b["balance"].getUint64,
                                              utxo_count: b["utxo_count"].getUint32)
          inc(i)

    for a in addrInfos:
      if not addrBalances.hasKey(a.address):
        db.setAddress(a.address, a.change, a.index, a.wid, 0)
      else:
        var cur_log_sequence = 0'u64
        while true:
          var addrlogs = blockstor.getAddrlog(a.address, (gte: cur_log_sequence,
                                              limit: 1000, reverse: 0,
                                              seqbreak: 1))
          let reslen = addrlogs.resLen
          for alog in addrlogs.toApiResIterator:
            db.setAddrlog(a.wid, alog["sequence"].getUint64, alog["type"].getUint8,
                          a.change, a.index, a.address, alog["value"].getUint64,
                          alog["txid"].getStr, alog["height"].getUint32,
                          alog["time"].getUint32)
          if reslen == 0:
            break
          cur_log_sequence = addrlogs["res"][reslen - 1]["sequence"].getUint64
          if reslen < 1000:
            break

        var cur_utxo_sequence = 0'u64
        while true:
          var utxos = blockstor.getUtxo(a.address, (gte: cur_utxo_sequence,
                                        limit: 1000, reverse: 0, seqbreak: 1))
          let reslen = utxos.resLen
          for utxo in utxos.toApiResIterator:
            db.setUnspent(a.wid, utxo["sequence"].getUint64, utxo["txid"].getStr,
                          utxo["n"].getUint32, a.address, utxo["value"].getUint64)
          if reslen == 0:
            break
          cur_utxo_sequence = utxos["res"][reslen - 1]["sequence"].getUint64
          if reslen < 1000:
            break

        var b = addrBalances[a.address]
        db.setAddrval(a.wid, a.change, a.index, a.address, b.balance, b.utxo_count)
        db.setAddress(a.address, a.change, a.index, a.wid, cur_log_sequence)
        walletInfos[a.wid].sequence = max(walletInfos[a.wid].sequence, cur_log_sequence)

    for wid in walletInfos.keys:
      var w = walletInfos[wid]
      db.setWallet(w.xpubkey, wid, w.sequence, w.next_0_index, w.next_1_index)

proc walletRollback(rollbacked_sequence: uint64) =
  for d in db.getWallets(""):
    var tbd_addrs: seq[tuple[change: uint32, index: uint32, address: string]] = @[]
    var addrs: seq[string] = @[]
    for a in getAddrlogs_gt(d.wallet_id, rollbacked_sequence):
      tbd_addrs.add((a.change, a.index, a.address))
    tbd_addrs = deduplicate(tbd_addrs)
    for a in tbd_addrs:
      addrs.add(a.address)

    delUnspents_gt(d.wallet_id, rollbacked_sequence)

    let balance = blockstor.getAddress(addrs)
    if addrs.len != balance.resLen:
      debug "error: getaddress len=", addrs.len, " reslen=", balance.resLen
      return

    var pos = 0
    for b in balance.toApiResIterator:
      if b{"balance"} != nil:
        db.delAddrval(d.wallet_id, tbd_addrs[pos].change,
                      tbd_addrs[pos].index, tbd_addrs[pos].address)
      else:
        db.setAddrval(d.wallet_id, tbd_addrs[pos].change,
                      tbd_addrs[pos].index, tbd_addrs[pos].address,
                      b["balance"].getUint64, b["utxo_count"].getUint32)
    db.setWallet(d.xpubkey, d.wallet_id, rollbacked_sequence,
                d.next_0_index, d.next_1_index)

    for a in tbd_addrs:
      db.setAddress(a.address, a.change, a.index, d.wallet_id, rollbacked_sequence)
    delAddrlogs_gt(d.wallet_id, rollbacked_sequence)

proc main() =
  let j_marker = blockstor.getMarker(blockstor_apikey)
  if j_marker.kind == JNull:
    echo "error: getMarker is null"
    return
  let marker_err = getBsErrorCode(j_marker["err"].getInt)
  case marker_err
    of BsErrorCode.SUCCESS:
      let res = j_marker["res"]
      let marker_sequence = res["sequence"].getUint64
      let last_sequence = res["last"].getUint64
      addressFinder(marker_sequence, last_sequence)
      let smarker = blockstor.setMarker(blockstor_apikey, last_sequence)
      if smarker.kind == JNull:
        debug "error: setmarker is null"
        return
      let smarker_err = getBsErrorCode(smarker["err"].getInt)
      if smarker_err != BsErrorCode.SUCCESS:
        debug "info: setmarker err=", smarker_err
    of BsErrorCode.ROLLBACKED:
      let res = j_marker["res"]
      let rollbacked_sequence = res["sequence"].getUint64
      walletRollback(rollbacked_sequence)
      let smarker_update = blockstor.setMarker(blockstor_apikey, rollbacked_sequence)
      if smarker_update.kind == JNull:
        debug "error: setmarker in rollback is null"
        return
      let smarker_update_err = getBsErrorCode(smarker_update["err"].getInt)
      if smarker_update_err != BsErrorCode.SUCCESS:
        debug "info: setmarker err=", smarker_update_err
    of BsErrorCode.ROLLBACKING:
      debug "info: blockstor rollbacking"
    of BsErrorCode.UNKNOWN_APIKEY:
      echo "error: invalid apikey"
    else:
      echo "error: getMarker err=", marker_err

proc threadWorkerFunc() {.thread.} =
  while active:
    ready = false
    main()
    ready = true
    waitFor event

proc doWork*() =
  event.setEvent()

proc watcher_main() {.thread.} =
  while true:
    if ready:
      doWork()
      for d in db.getWallets(""):
        debug "wid=", d.wallet_id, " ", d.xpubkey
        debug "---getAddrvals"
        for g in db.getAddrvals(d.wallet_id):
          debug g
        debug "---getAddrlogs"
        for g in db.getAddrlogs(d.wallet_id):
          debug g
        debug "---getUnspents"
        for g in db.getUnspents(d.wallet_id):
          debug g
    for i in 0..<6:
      if not active:
        return
      sleep(500)

proc stream_main() {.thread.} =
  let ws = waitFor newAsyncWebsocketClient("localhost", Port(8001),
    path = "/api", ssl = false, protocols = @[], userAgent = "pastel-v0.1")

  proc read() {.async.} =
    while true:
      let (opcode, data) = await ws.readData()
      if opcode == Opcode.Text:
        echo parseJson(data).pretty
        # test send
        for d in db.getWallets(""):
          stream.send(d.wallet_id, data);

  asyncCheck read()
  while true:
    if not active:
      break
    poll()

proc stop*() =
  active = false
  event.setEvent()
  joinThreads(threads)
  btc_ecc_stop()
  debug "watcher stop"

proc quit() {.noconv.} =
    stop()

proc start*(): Thread[void] =
  debug "watcher start"
  active = true
  btc_ecc_start()
  createThread(threads[0], threadWorkerFunc)
  createThread(threads[1], watcher_main)
  createThread(threads[2], stream_main)
  addQuitProc(quit)
  threads[1]
