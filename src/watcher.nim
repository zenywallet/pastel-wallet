# Copyright (c) 2019 zenywallet

import os, asyncdispatch, sequtils, tables, random, sets, algorithm, hashes, times, strutils
import ../deps/"websocket.nim"/websocket
import blockstor, db, events, logs, server as stream
import std/exitprocs
import zenyjs
import zenyjs/core
import zenyjs/bip32
import config
import caprese
import caprese/queue
import caprese/server_types

var
  threads: array[5, ref Thread[void]]
  event = createEvent()
  active = true
  ready* = true

proc hdaddress(xpubkey: string, change, index: uint32): string =
  result = ""
  try:
    result = network.getAddress(bip32.node(xpubkey).derive(change).derive(index))
  except:
    let e = getCurrentException()
    Debug.CommonError.write e.name, ": ", e.msg

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

var prev_update_wallets {.threadvar.}: WalletIds
var update_wallets {.threadvar.}: WalletIds

proc addressFinder(sequence: uint64, last_sequence: uint64): bool =
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

      var new_0_index = used_0_index + gaplimit + 1
      var new_1_index = used_1_index + gaplimit + 1
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

    update_wallets = @[]
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
        update_wallets.add(a.wid)

    for wid in walletInfos.keys:
      var w = walletInfos[wid]
      db.setWallet(w.xpubkey, wid, w.sequence, w.next_0_index, w.next_1_index)

    update_wallets = deduplicate(update_wallets)
    var target_wallets = prev_update_wallets.filter(proc(x: WalletId): bool = not update_wallets.contains(x))
    prev_update_wallets = update_wallets
    if target_wallets.len > 0:
      BallCommand.UpdateWallets.send(BallDataUpdateWallets(wallets: target_wallets, status: BallDataUpdateWalletsStatus.Done))
    if update_wallets.len > 0:
      BallCommand.UpdateWallets.send(BallDataUpdateWallets(wallets: update_wallets, status: BallDataUpdateWalletsStatus.Continue))
      result = true
    else:
      result = false
  else:
    var target_wallets = prev_update_wallets
    if target_wallets.len > 0:
      BallCommand.UpdateWallets.send(BallDataUpdateWallets(wallets: target_wallets, status: BallDataUpdateWalletsStatus.Done))
    prev_update_wallets = @[]
    result = false


proc walletRollback(rollbacked_sequence: uint64) =
  for d in db.getWallets(""):
    var tbd_addrs: seq[tuple[change: uint32, index: uint32, address: string]] = @[]
    var addrs: seq[string] = @[]
    for a in db.getAddrlogs_gt(d.wallet_id, rollbacked_sequence):
      tbd_addrs.add((a.change, a.index, a.address))
    tbd_addrs = deduplicate(tbd_addrs)
    for a in tbd_addrs:
      addrs.add(a.address)

    db.delUnspents_gt(d.wallet_id, rollbacked_sequence)

    let balance = blockstor.getAddress(addrs)
    if addrs.len != balance.resLen:
      Debug.CommonError.write "error: getaddress len=", addrs.len, " reslen=", balance.resLen
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
    db.delAddrlogs_gt(d.wallet_id, rollbacked_sequence)

type
  UpdateAddrInfo = ref object
    address: string
    change: uint32
    index: uint32
    wid: uint64
    sequence: uint64

proc updateAddressInfos(updateAddrInfos: seq[UpdateAddrInfo]) =
  if updateAddrInfos.len > 0:
    var addrs: seq[string]
    for a in updateAddrInfos:
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

    for a in updateAddrInfos:
      if addrBalances.hasKey(a.address):
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

        var b = addrBalances[a.address]
        db.setAddrval(a.wid, a.change, a.index, a.address, b.balance, b.utxo_count)
        db.setAddress(a.address, a.change, a.index, a.wid, cur_log_sequence)

proc updateAddresses() =
  var updateAddrInfos: seq[UpdateAddrInfo]
  for a in db.getAddresses():
    updateAddrInfos.add(UpdateAddrInfo(address: a.address, change: a.change,
                                      index: a.index, wid: a.wid,
                                      sequence: a.sequence))
  updateAddressInfos(updateAddrInfos)

proc updateAddresses(target_wids: HashSet[WalletId]) =
  var updateAddrInfos: seq[UpdateAddrInfo]
  for a in db.getAddresses():
    if target_wids.contains(a.wid):
      updateAddrInfos.add(UpdateAddrInfo(address: a.address, change: a.change,
                                        index: a.index, wid: a.wid,
                                        sequence: a.sequence))
  updateAddressInfos(updateAddrInfos)

proc updateBalance(wid: uint64) =
  discard

var block_header_prev_height: uint32 = 0'u32
var blockDataChannel* = queue.newQueue[JsonNode](0x10000)

proc applyBlockData(marker_sequence: uint64, last_sequence: uint64) =
  var wids = initHashSet[WalletId]()
  while blockDataChannel.count > 0:
    var json = blockDataChannel.recv()
    var height = json["height"].getUint32
    var time = json["time"].getUint32
    if block_header_prev_height + 1 == height:
      for b in json["addrs"].pairs:
        var address = b.key
        var val = b.val
        for a in db.getAddresses(address):
          wids.incl(a.wid)
          db.setAddrval(a.wid, a.change, a.index, address,
                        val["balance"].getUint64, val["utxo_count"].getUint32)
          for v in val["vals"]:
            var sequence = v["sequence"].getUint64
            var txid = json["txs"][$sequence].getStr
            db.setAddrlog(a.wid, v["sequence"].getUint64, v["type"].getUint8,
                          a.change, a.index, address, v["value"].getUint64,
                          txid, height, time)
      block_header_prev_height = height
    else:
      for w in db.getWallets(""):
        wids.incl(w.wallet_id)
      while blockDataChannel.count > 0:
        json = blockDataChannel.recv()
      height = json["height"].getUint32
      updateAddresses()
      block_header_prev_height = height
      break

  for wid in wids:
    updateBalance(wid)

  for w in db.getWallets(""):
    if wids.contains(w.wallet_id):
      db.setWallet(w.xpubkey, w.wallet_id, last_sequence, w.next_0_index, w.next_1_index)

proc main(): bool =
  result = false
  let j_marker = blockstor.getMarker(blockstor_apikey)
  if j_marker.kind == JNull:
    Debug.CommonError.write "error: getMarker is null"
    return
  let marker_err = getBsErrorCode(j_marker["err"].getInt)
  case marker_err
  of BsErrorCode.SUCCESS:
    try:
      let res = j_marker["res"]
      let marker_sequence = res["sequence"].getUint64
      let last_sequence = res["last"].getUint64
      applyBlockData(marker_sequence, last_sequence)
      result = addressFinder(marker_sequence, last_sequence)
      let smarker = blockstor.setMarker(blockstor_apikey, last_sequence)
      if smarker.kind == JNull:
        Debug.CommonError.write "error: setmarker is null"
        return
      let smarker_err = getBsErrorCode(smarker["err"].getInt)
      if smarker_err != BsErrorCode.SUCCESS:
        debug "info: setmarker err=", smarker_err
    except:
        Debug.CommonError.write "EXCEPTION: BsErrorCode.SUCCESS ", j_marker
        let e = getCurrentException()
        Debug.CommonError.write e.name, ": ", e.msg
  of BsErrorCode.ROLLBACKED:
    let res = j_marker["res"]
    let rollbacked_sequence = res["sequence"].getUint64
    walletRollback(rollbacked_sequence)
    let smarker_update = blockstor.setMarker(blockstor_apikey, rollbacked_sequence)
    if smarker_update.kind == JNull:
      Debug.CommonError.write "error: setmarker in rollback is null"
      return
    BallCommand.Rollbacked.send(BallDataRollbacked(sequence: rollbacked_sequence))
    let smarker_update_err = getBsErrorCode(smarker_update["err"].getInt)
    if smarker_update_err != BsErrorCode.SUCCESS:
      debug "info: setmarker err=", smarker_update_err
  of BsErrorCode.ROLLBACKING:
    debug "info: blockstor rollbacking"
  of BsErrorCode.UNKNOWN_APIKEY:
    Debug.CommonError.write "error: invalid apikey"
  else:
    Debug.CommonError.write "error: getMarker err=", marker_err

proc threadWorkerFunc() {.thread.} =
  while active:
    ready = false
    if not main():
      ready = true
      waitFor event

proc doWork*() =
  event.setEvent()

proc watcher_main() {.thread.} =
  while true:
    if ready:
      doWork()
    for i in 0..<6:
      if not active:
        return
      sleep(500)

proc block_reader(json: JsonNode) =
  if not blockDataChannel.send(json):
    Debug.CommonError.write "error: blockDataChannel is null"
  doWork()

proc stream_main() {.thread.} =

  proc read() {.async.} =
    while true:
      try:
        let ws = waitFor newAsyncWebsocketClient(config.blockstor_wshost, Port(config.blockstor_wsport),
          path = "api", ssl = false, protocols = @[], userAgent = "pastel-v0.1")

        while true:
          let (opcode, data) = await ws.readData()
          if opcode == Opcode.Text:
            var json = parseJson(data)
            if json.hasKey("height"):
              block_reader(json)
              await sleepAsync(6000)
            BallCommand.BsStream.send(BallDataBsStream(data: json))

      except:
        let e = getCurrentException()
        Debug.CommonError.write e.name, ": ", e.msg
        if not active:
          break

      await sleepAsync(6000)

  asyncCheck read()
  while true:
    if not active:
      break
    poll()

proc cmd_main() {.thread.} =
  var mempool: JsonNode = newJArray()

  while true:
    let cdata = cmdChannel.recv()
    Debug.Stream.write "cmdManager cmd=", cdata.cmd
    case cdata.cmd
    of StreamCommand.Balance:
      var client = StreamDataBalance(cdata.data)
      var balance: uint64 = 0'u64
      for wid in client.wallets:
        for addrval in db.getAddrvals(wid):
          balance += addrval.value
      var json = %*{"type": "balance", "data": j_uint64(balance)}
      stream.send(client.wallets[0], $json)
    of StreamCommand.Addresses:
      var client = StreamDataAddresses(cdata.data)
      var json = %*{"type": "addresses", "data": []}
      for wid in client.wallets:
        for addrval in db.getAddrvals(wid):
          if addrval.value > 0'u64:
            var v = newJObject()
            v["change"] = newJInt(addrval.change.BiggestInt)
            v["index"] = newJInt(addrval.index.BiggestInt)
            v["address"] = newJString(addrval.address)
            v["value"] = j_uint64(addrval.value)
            v["utxo_cunt"] = newJInt(addrval.utxo_cunt.BiggestInt)
            json["data"].add(v)
      stream.send(client.wallets[0], $json)
    of StreamCommand.Unused:
      const UnusedMax = 20
      var client = StreamDataUnused(cdata.data)
      var json = %*{"type": "unused", "data": []}
      var count = 0
      var index = 0
      var unused_index: uint32 = 0
      var used_0 = db.getLastUsedAddrIndex(client.wallet_id, 0)
      if used_0.err == DbStatus.Success:
        unused_index = used_0.res + 1
      block searchUnused:
        for addrval in db.getAddrvals(client.wallet_id):
          if addrval.change != 0:
            break
          for i in index..<addrval.index.ord:
            json["data"].add(newJInt(i))
            inc(count)
            if i >= unused_index.ord and count >= UnusedMax:
              break searchUnused
          index = addrval.index.ord + 1
        for i in count..<UnusedMax:
          json["data"].add(newJInt(index))
          inc(index)
          if index >= unused_index.ord:
            break
      stream.send(client.wallet_id, $json)
    of StreamCommand.RawTx:
      var client = StreamDataRawTx(cdata.data)
      Debug.Stream.write "RawTx ", client.rawtx
      let ret_rawtx = blockstor.send(client.rawtx)
      Debug.Stream.write "RawTx ret=", ret_rawtx
      var json = %*{"type": "rawtx", "data": ret_rawtx}
      stream.send(client.wallet_id, $json)
    of StreamCommand.Abort:
      return

type
  UserUtxo = object
    sequence: uint64
    txid: string
    n: uint32
    address: string
    value: uint64
    change: uint32
    index: uint32
    xpub_idx: int

  UserAddrInfo = object
    change: uint32
    index: uint32
    xpub_idx: int

  WidAddressPairs = object
    wid: WalletId
    address: string

  WidTxPairs = object
    wid: WalletId
    txid: string

  TWidInfos = tuple[addrs: HashSet[WidAddressPairs], txs: HashSet[WidTxPairs]]

proc UserUtxoCmp(x, y: UserUtxo): int =
  result = cmp(x.sequence, y.sequence)
  if result == 0:
    result = cmp(x.change, y.change)
    if result == 0:
      result = cmp(x.index, y.index)

proc hash*(xs: WalletIds): hashes.Hash =
  var s: string
  for x in xs:
    s.add("#" & $x)
  result = s.hash

proc hash*(x: UserUtxo): hashes.Hash =
  var s: string = $x.sequence & "-" & x.txid & "-" & $x.n
  result = s.hash

proc hash*(x: WidAddressPairs): hashes.Hash =
  var s: string = $x.wid & "-" & x.address
  result = s.hash

proc hash*(x: WidTxPairs): hashes.Hash =
  var s: string = $x.wid & "-" & x.txid
  result = s.hash

proc clientUnspents(wallets: seq[uint64]): seq[UserUtxo] =
  var addrInfos = initTable[string, UserAddrInfo]()
  for i, wid in wallets:
    for a in db.getAddrvals(wid):
      addrInfos[a.address] = UserAddrInfo(change: a.change, index: a.index, xpub_idx: i)

  var addrs: seq[string]
  if addrInfos.len > 0:
      for address in addrInfos.keys:
        addrs.add(address)
      timeseed()
      shuffle(addrs)

  var unspents: seq[UserUtxo] = @[]
  var split_addrs = addrs.distribute(1 + addrs.len div 50)
  for sa in split_addrs:
    var utxos = blockstor.getUtxo(sa, (gte: 0, limit: 1000, reverse: 0, seqbreak: 1))
    var i = 0
    for utxo in utxos.toApiResIterator:
      let address = sa[i]
      let a = addrInfos[address]
      for u in utxo:
        unspents.add(UserUtxo(sequence: u["sequence"].getUint64, txid: u["txid"].getStr,
                              n: u["n"].getUint32, address: address, value: u["value"].getUint64,
                              change: a.change, index: a.index, xpub_idx: a.xpub_idx))
      inc(i)
  unspents.sort(UserUtxoCmp)
  if unspents.len > 1000:
    unspents.delete(1000..unspents.high)
  unspents

proc ball_main() {.thread.} =
  var wallet_ids = initHashSet[WalletIds]()
  var client_unspents = initTable[WalletId, HashSet[UserUtxo]]()
  var active_wids = initHashSet[WalletId]()
  var full_wid_addrs = initHashSet[WidAddressPairs]()
  var full_wid_txs = initHashSet[WidTxPairs]()
  var height: uint32
  var prev_stream_height: uint32 = 0

  proc sendUnconfs(wid_addrs: HashSet[WidAddressPairs], wid_txs: HashSet[WidTxPairs], mempool: JsonNode, wids: seq[WalletIds], send_empty: bool = false): WalletIds {.discardable.} =
    var sent_wids: WalletIds
    for wallets in wids:
      var sent = false
      var addrs_array: seq[string] = @[]
      var txs_array: seq[string] = @[]
      for wid_addr in wid_addrs:
        if wallets.contains(wid_addr.wid):
          addrs_array.add(wid_addr.address)
      for wid_tx in wid_txs:
        if wallets.contains(wid_tx.wid):
          txs_array.add(wid_tx.txid)
      if addrs_array.len > 0:
        var j_unconfs = blockstor.getUnconf(addrs_array)
        if j_unconfs.kind != JNull:
          var json = %*{"type": "unconfs", "data": {"addrs": {}, "txs": {}}}
          let j_addrs = json["data"]["addrs"]
          let j_txs = json["data"]["txs"]
          for i, a in addrs_array:
            var j = j_unconfs["res"][i]
            if j.hasKey("spents") or j.hasKey("txouts"):
              if j.hasKey("spents"):
                for v in j["spents"]:
                  v["value"] = j_uint64(v["value"].getUint64)
              if j.hasKey("txouts"):
                for v in j["txouts"]:
                  v["value"] = j_uint64(v["value"].getUint64)
              j_addrs[a] = j
              for da in db.getAddresses(a):
                var idx = wallets.find(da.wid)
                if idx >= 0:
                  j_addrs[a].add("change", newJInt(da.change.BiggestInt))
                  j_addrs[a].add("index", newJInt(da.index.BiggestInt))
                  j_addrs[a].add("xpub_idx", newJInt(idx.BiggestInt))
                  if j_addrs[a].hasKey("spents"):
                    for spent in j_addrs[a]["spents"]:
                      let dt = db.getTxtime(spent["txid"].getStr)
                      if dt.err == DbStatus.Success:
                        spent.add("trans_time", j_uint64(dt.res))
                  if j_addrs[a].hasKey("txouts"):
                    for txout in j_addrs[a]["txouts"]:
                      let dt = db.getTxtime(txout["txid"].getStr)
                      if dt.err == DbStatus.Success:
                        txout.add("trans_time", j_uint64(dt.res))
                  break
          for t in txs_array:
            for m in mempool:
              if m["txid"].getStr == t:
                j_txs[t] = %*{"data": m["addrs"]}
                let dt = db.getTxtime(t)
                if dt.err == DbStatus.Success:
                  j_txs[t].add("trans_time", j_uint64(dt.res))

          let client_wid: WalletId = wallets[0]
          stream.send(client_wid, $json)
          sent_wids.add(client_wid)
          sent = true
      if send_empty and not sent:
        var json = %*{"type": "unconfs"}
        json.add("data", newJObject())
        let client_wid: WalletId = wallets[0]
        stream.send(client_wid, $json)
    sent_wids

  proc setTransimissionTime(txid: string) =
    let d = db.getTxtime(txid)
    if d.err == DbStatus.NotFound:
      db.setTxtime(txid, cast[uint64](getTime().toUnix))

  proc fullMempoolAddrsAndTxs(mempool: JsonNode): TWidInfos =
    var wid_addrs = initHashSet[WidAddressPairs]()
    var wid_txs = initHashSet[WidTxPairs]()
    for m in mempool:
      let txid = m["txid"].getStr
      setTransimissionTime(txid)
      for a in m["addrs"].pairs:
        for da in db.getAddresses(a.key):
          if active_wids.contains(da.wid):
            wid_addrs.incl([WidAddressPairs(wid: da.wid, address: a.key)].toHashSet())
            wid_txs.incl([WidTxPairs(wid: da.wid, txid: txid)].toHashSet())
    (addrs: wid_addrs, txs: wid_txs)

  proc mempoolAddrsAndTxs(mempool: JsonNode): TWidInfos =
    var wid_addrs = initHashSet[WidAddressPairs]()
    var wid_txs = initHashSet[WidTxPairs]()
    for m in mempool:
      let txid = m["txid"].getStr
      setTransimissionTime(txid)
      for a in m["addrs"].pairs:
        for da in db.getAddresses(a.key):
          if active_wids.contains(da.wid):
            wid_addrs.incl([WidAddressPairs(wid: da.wid, address: a.key)].toHashSet())
            wid_txs.incl([WidTxPairs(wid: da.wid, txid: txid)].toHashSet())
    (addrs: wid_addrs, txs: wid_txs)

  let j_height = blockstor.getHeight()
  if j_height.kind != JNull:
    height = j_height["res"].getUint32

  while true:
    let ch_data = ballChannel.recv()
    debug "ballChannel cmd=", ch_data.cmd
    case ch_data.cmd
    of BallCommand.BsStream:
      try:
        var j_bs = BallDataBsStream(ch_data.data).data
        var sent_wids: WalletIds
        var height_flag = false
        if j_bs.hasKey("height"):
          height_flag = true
          height = j_bs["height"].getUint32
          if prev_stream_height >= height:
            var min_sequence: uint64
            var first = true
            for tx in j_bs["txs"].pairs:
              if first:
                min_sequence = cast[uint64](parseBiggestUInt(tx.key))
                first = false
              else:
                var s = cast[uint64](parseBiggestUInt(tx.key))
                if min_sequence > s:
                  min_sequence = s
            if not first:
              for ids in wallet_ids:
                BallCommand.Rollback.send(BallDataRollback(wallet_id: ids[0], sequence: min_sequence))
          prev_stream_height = height
          let j_mempool = blockstor.getMempool()
          if j_mempool.kind != JNull and j_mempool.hasKey("res") and getBsErrorCode(j_mempool["err"].getInt) == BsErrorCode.SUCCESS:
            var twidinfos: TWidInfos = fullMempoolAddrsAndTxs(j_mempool["res"])
            full_wid_addrs = twidinfos.addrs
            full_wid_txs = twidinfos.txs
            sent_wids = sendUnconfs(full_wid_addrs, full_wid_txs, j_mempool["res"], wallet_ids.toSeq, true)
        elif j_bs.hasKey("mempool"):
          var twidinfos: TWidInfos = mempoolAddrsAndTxs(j_bs["mempool"])
          full_wid_addrs = full_wid_addrs + twidinfos.addrs
          full_wid_txs = full_wid_txs + twidinfos.txs
          let j_mempool = blockstor.getMempool()
          if j_mempool.kind != JNull and j_mempool.hasKey("res") and getBsErrorCode(j_mempool["err"].getInt) == BsErrorCode.SUCCESS:
            sent_wids = sendUnconfs(full_wid_addrs, full_wid_txs, j_mempool["res"], wallet_ids.toSeq)
            for sent_wid in sent_wids:
              for ids in wallet_ids:
                if ids[0] == sent_wid:
                  BallCommand.Unspents.send(BallDataUnspents(wallets: ids))
        updateAddresses(active_wids)
        for w in sent_wids:
          BallCommand.Unused.send(BallDataUnused(wallet_id: w))
        for ids in wallet_ids:
          StreamCommand.Balance.send(StreamDataBalance(wallets: ids))
        if height_flag:
          for ids in wallet_ids:
            BallCommand.Height.send(BallDataHeight(wallet_id: ids[0]))

      except:
        let e = getCurrentException()
        Debug.CommonError.write e.name, ": ", e.msg

    of BallCommand.MemPool:
      var data = BallDataMemPool(ch_data.data)
      var client = getClient(data.client.ClientId)
      if client.isNil: continue
      var clientWallets = client.wallets
      let j_mempool = blockstor.getMempool()
      if j_mempool.kind != JNull and j_mempool.hasKey("res") and getBsErrorCode(j_mempool["err"].getInt) == BsErrorCode.SUCCESS:
        var widinfos: TWidInfos = fullMempoolAddrsAndTxs(j_mempool["res"])
        full_wid_addrs = widinfos.addrs
        full_wid_txs = widinfos.txs
        sendUnconfs(full_wid_addrs, full_wid_txs, j_mempool["res"], @[clientWallets], true)

    of BallCommand.Unspents:
      var data = BallDataUnspents(ch_data.data)
      var unspents: seq[UserUtxo] = @[]
      let client_wid: WalletId = data.wallets[0]
      if data.wallets.len > 0:
        unspents = clientUnspents(data.wallets)
        client_unspents[client_wid] = unspents.toHashSet()
      var json = %*{"type": "unspents", "data": unspents}
      for j in json["data"]:
        j["value"] = j_uint64(j["value"].getUint64)
      stream.send(client_wid, $json)

    of BallCommand.Unused:
      const UnusedMax = 20
      var data = BallDataUnused(ch_data.data)
      let client_wid: WalletId = data.wallet_id
      var unconf_addrs: seq[string] = @[]
      for f in full_wid_addrs:
        if f.wid == client_wid:
          unconf_addrs.add(f.address)
      var unconf_idxs: seq[uint32] = @[]
      for a in unconf_addrs:
        for da in db.getAddresses(a):
          if da.change == 0:
            unconf_idxs.add(da.index)
      var json = %*{"type": "unused", "data": []}
      var count = 0
      var index: uint32 = 0
      var unused_index: uint32 = 0
      var used_0 = db.getLastUsedAddrIndex(client_wid, 0)
      if used_0.err == DbStatus.Success:
        unused_index = used_0.res + 1
      if unconf_idxs.len > 0:
        unconf_idxs.sort()
        var last_unconf_idx = unconf_idxs[unconf_idxs.high]
        if last_unconf_idx >= unused_index:
          unused_index = last_unconf_idx + 1
      block searchBallUnused:
        for addrval in db.getAddrvals(client_wid):
          if addrval.change != 0:
            break
          for i in index..<addrval.index:
            if not unconf_idxs.contains(i.uint32):
              json["data"].add(newJInt(i.BiggestInt))
              inc(count)
              if count >= UnusedMax:
                break searchBallUnused
            if i >= unused_index:
              break searchBallUnused
          index = addrval.index + 1'u32
        while count < UnusedMax:
          if not unconf_idxs.contains(index.uint32):
            json["data"].add(newJInt(index.BiggestInt))
            inc(count)
          if index >= unused_index:
            break
          inc(index)
      stream.send(client_wid, $json)

    of BallCommand.Change:
      const ChangeMax = 1
      var data = BallDataChange(ch_data.data)
      let client_wid: WalletId = data.wallet_id
      var unconf_addrs: seq[string] = @[]
      for f in full_wid_addrs:
        if f.wid == client_wid:
          unconf_addrs.add(f.address)
      var unconf_idxs: seq[uint32] = @[]
      for a in unconf_addrs:
        for da in db.getAddresses(a):
          if da.change == 1:
            unconf_idxs.add(da.index)
      var json = %*{"type": "change", "data": []}
      var count = 0
      var index: uint32 = 0
      var unused_index: uint32 = 0
      var used_1 = db.getLastUsedAddrIndex(client_wid, 1)
      if used_1.err == DbStatus.Success:
        unused_index = used_1.res + 1
      if unconf_idxs.len > 0:
        unconf_idxs.sort()
        var last_unconf_idx = unconf_idxs[unconf_idxs.high]
        if last_unconf_idx >= unused_index:
          unused_index = last_unconf_idx + 1
      block searchBallUnused:
        for addrval in db.getAddrvals(client_wid):
          if addrval.change == 0:
            continue
          for i in index..<addrval.index:
            if not unconf_idxs.contains(i.uint32):
              json["data"].add(newJInt(i.BiggestInt))
              inc(count)
              if count >= ChangeMax:
                break searchBallUnused
            if i >= unused_index:
              break searchBallUnused
          index = addrval.index + 1'u32
        while count < ChangeMax:
          if not unconf_idxs.contains(index.uint32):
            json["data"].add(newJInt(index.BiggestInt))
            inc(count)
          if index >= unused_index:
            break
          inc(index)
      stream.send(client_wid, $json)

    of BallCommand.Height:
      var data = BallDataHeight(ch_data.data)
      let client_wid: WalletId = data.wallet_id
      var json = %*{"type": "height", "data": height}
      stream.send(client_wid, $json)

    of BallCommand.Rollback:
      var data = BallDataRollback(ch_data.data)
      let client_wid: WalletId = data.wallet_id
      var sequence = data.sequence
      var json = %*{"type": "rollback", "data": sequence}
      stream.send(client_wid, $json)

    of BallCommand.Rollbacked:
      var data = BallDataRollbacked(ch_data.data)
      var sequence = data.sequence
      var json = %*{"type": "rollbacked", "data": sequence}
      for ids in wallet_ids:
        stream.send(ids[0], $json)

    of BallCommand.AddClient:
      var data = BallDataAddClient(ch_data.data)
      var client = getClient(data.client.ClientId)
      if client.isNil: continue
      var clientWallets = client.wallets
      debug "AddClient ", clientWallets
      if clientWallets.len > 0:
        wallet_ids.incl(clientWallets)
        active_wids.incl(clientWallets.toHashSet())
        BallCommand.Unspents.send(BallDataUnspents(wallets: clientWallets))
        BallCommand.MemPool.send(BallDataMemPool(client: data.client.ClientId))
        BallCommand.Height.send(BallDataHeight(wallet_id: clientWallets[0]))
        BallCommand.Unused.send(BallDataUnused(wallet_id: clientWallets[0]))
        StreamCommand.Balance.send(StreamDataBalance(wallets: clientWallets))
        StreamCommand.Addresses.send(StreamDataAddresses(wallets: clientWallets))

    of BallCommand.DelClient:
      var data = BallDataDelClient(ch_data.data)
      var client = getClient(data.client.ClientId)
      if client.isNil: continue
      var clientWallets = client.wallets
      debug "DelClient ", clientWallets
      if clientWallets.len > 0:
        client.wallets = @[]
        let client_wid: WalletId = clientWallets[0]
        wallet_ids.excl(clientWallets)
        var find = false
        for wallets in wallet_ids:
          if wallets[0] == client_wid:
            find = true
            break
        if not find:
          active_wids.excl(clientWallets.toHashSet())
        client.wallets = @[]

    of BallCommand.UpdateWallets:
      var data = BallDataUpdateWallets(ch_data.data)
      let wallets: WalletIds = data.wallets
      if data.status == BallDataUpdateWalletsStatus.Continue:
        for ids in wallet_ids:
          for id in ids:
            if wallets.contains(id):
              StreamCommand.Balance.send(StreamDataBalance(wallets: ids))
              break
      elif data.status == BallDataUpdateWalletsStatus.Done:
        for ids in wallet_ids:
          for id in ids:
            if wallets.contains(id):
              BallCommand.Unspents.send(BallDataUnspents(wallets: ids))
              break

    of BallCommand.Abort:
      return

proc stop*() =
  active = false
  event.setEvent()
  StreamCommand.Abort.send()
  BallCommand.Abort.send()
  for i in 0..threads.high: joinThread(threads[i][])
  Debug.Common.write "watcher stop"
  serverStop()
  sendMesChannel.drop()

proc quit() {.noconv.} =
  stop()

proc start*(): ref Thread[void] =
  Debug.Common.write "watcher start"
  active = true
  for i in 0..threads.high:
    threads[i] = new Thread[void]
  createThread(threads[0][], threadWorkerFunc)
  createThread(threads[1][], ball_main)
  createThread(threads[2][], cmd_main)
  createThread(threads[3][], watcher_main)
  createThread(threads[4][], stream_main)
  exitprocs.addExitProc(quit)
  threads[3]
