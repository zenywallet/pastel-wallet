# Copyright (c) 2019 zenywallet

import os, locks, asyncdispatch, sequtils, tables, random, sets, algorithm, hashes
from times import getTime, toUnix, nanosecond
import ../deps/"websocket.nim"/websocket
import libbtc
import blockstor, db, events, logs, stream

const gaplimit: uint32 = 20
const blockstor_apikey = "sample-969a6d71-a259-447c-a486-90bac964992b"
var chain = testnet_bitzeny_chain

var
  threads: array[5, Thread[void]]
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

type
  UpdateAddrInfo = ref object
    address: string
    change: uint32
    index: uint32
    wid: uint64
    sequence: uint64

proc updateAddresses(marker_sequence: uint64, last_sequence: uint64) =
  var updateAddrInfos: seq[UpdateAddrInfo]
  for a in db.getAddresses():
    updateAddrInfos.add(UpdateAddrInfo(address: a.address, change: a.change,
                                      index: a.index, wid: a.wid,
                                      sequence: a.sequence))
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

proc updateBalance(wid: uint64) =
  discard

var block_header_prev_height: uint32 = 0'u32
var blockDataChannel*: Channel[JsonNode]
blockDataChannel.open()

proc applyBlockData(marker_sequence: uint64, last_sequence: uint64) =
  var wids = initHashSet[WalletId]()
  while blockDataChannel.peek() > 0:
    var json = blockDataChannel.recv()
    var height = json["height"].getUint32
    var time = json["time"].getUint32
    if block_header_prev_height + 1 == height:
      var addresses = json["addrs"]
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
      while blockDataChannel.peek() > 0:
        json = blockDataChannel.recv()
      height = json["height"].getUint32
      updateAddresses(marker_sequence, last_sequence)
      block_header_prev_height = height
      break

  for wid in wids:
    updateBalance(wid)

  for w in db.getWallets(""):
    if wids.contains(w.wallet_id):
      db.setWallet(w.xpubkey, w.wallet_id, last_sequence, w.next_0_index, w.next_1_index)

proc main() =
  let j_marker = blockstor.getMarker(blockstor_apikey)
  if j_marker.kind == JNull:
    echo "error: getMarker is null"
    return
  let marker_err = getBsErrorCode(j_marker["err"].getInt)
  case marker_err
  of BsErrorCode.SUCCESS:
    try:
      let res = j_marker["res"]
      let marker_sequence = res["sequence"].getUint64
      let last_sequence = res["last"].getUint64
      applyBlockData(marker_sequence, last_sequence)
      addressFinder(marker_sequence, last_sequence)
      let smarker = blockstor.setMarker(blockstor_apikey, last_sequence)
      if smarker.kind == JNull:
        debug "error: setmarker is null"
        return
      let smarker_err = getBsErrorCode(smarker["err"].getInt)
      if smarker_err != BsErrorCode.SUCCESS:
        debug "info: setmarker err=", smarker_err
    except:
        echo "EXCEPTION: BsErrorCode.SUCCESS ", j_marker
        let e = getCurrentException()
        debug e.name, ": ", e.msg
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

proc block_reader(json: JsonNode) =
  if json.hasKey("height"):
    blockDataChannel.send(json)
    doWork()

proc stream_main() {.thread.} =
  let ws = waitFor newAsyncWebsocketClient("localhost", Port(8001),
    path = "/api", ssl = false, protocols = @[], userAgent = "pastel-v0.1")

  proc read() {.async.} =
    while true:
      let (opcode, data) = await ws.readData()
      if opcode == Opcode.Text:
        try:
          var json = parseJson(data)
          echo json.pretty
          block_reader(json)
          BallCommand.BsStream.send(BallDataBsStream(data: json))

          # test send
          StreamCommand.BsStream.send(StreamDataBsStream(data: json))
          for d in db.getWallets(""):
            stream.send(d.wallet_id, data)

        except:
          let e = getCurrentException()
          echo e.name, ": ", e.msg

  asyncCheck read()
  StreamCommand.BsStreamInit.send()
  while true:
    if not active:
      break
    poll()

proc j_uint64(val: uint64): JsonNode =
  if val > 9007199254740991'u64:
    newJString($val)
  else:
    newJInt(BiggestInt(val))

proc cmd_main() {.thread.} =
  var mempool: JsonNode = newJArray()

  while true:
    let cdata = cmdChannel.recv()
    debug "cmdManager cmd=", cdata.cmd
    case cdata.cmd
    of StreamCommand.Unconfs:
      var client = StreamDataUnconfs(cdata.data)
      var json = %*{"type": "unconfs"}
      #let j_mempool = blockstor.getMempool()
      #if j_mempool.kind != JNull and j_mempool.hasKey("res") and getBsErrorCode(j_mempool["err"].getInt) == BsErrorCode.SUCCESS:
      json.add("data", newJObject())
      json["data"].add("mempool", newJObject())
      var addresses = initHashSet[string]()
      var addrbalances = initTable[string, uint64]()
      for m in mempool:
        for a in m["addrs"].pairs:
          var find = false
          for ba in db.getAddresses(a.key):
            for wid in client.wallets:
              if ba.wid == wid:
                find = true
                addresses.incl(a.key)
                var jd_mempool = json["data"]["mempool"]
                if jd_mempool.hasKey(a.key):
                  for v in a.val.pairs:
                    if jd_mempool[a.key].hasKey(v.key):
                      jd_mempool[a.key][v.key] = j_uint64(jd_mempool[a.key][v.key].getUint64 + v.val.getUint64)
                    else:
                      jd_mempool[a.key].add(v.key, v.val)
                else:
                  jd_mempool.add(a.key, a.val)
      if addresses.len > 0:
        var addrs_array: seq[string]
        for a in addresses:
          addrs_array.add(a)
        var j_unconfs: JsonNode
        try:
          j_unconfs = blockstor.getUnconf(addrs_array)
          if j_unconfs.kind != JNull:
            json["data"].add("unconfs", newJObject())
            for i, a in addrs_array:
              json["data"]["unconfs"][a] = j_unconfs["res"][i]
        except:
          echo "EXCEPTION: StreamCommand.Unconfs ", j_unconfs
          let e = getCurrentException()
          debug e.name, ": ", e.msg
      stream.send(client.wallets[0], $json)
    of StreamCommand.Balance:
      var client = StreamDataBalance(cdata.data)
      var balance: uint64 = 0'u64
      for wid in client.wallets:
        for addrval in getAddrvals(wid):
          balance += addrval.value
      var json = %*{"type": "balance", "data": j_uint64(balance)}
      stream.send(client.wallets[0], $json)
    of StreamCommand.Addresses:
      var client = StreamDataAddresses(cdata.data)
      var json = %*{"type": "addresses", "data": []}
      for wid in client.wallets:
        for addrval in getAddrvals(wid):
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
        for addrval in getAddrvals(client.wallet_id):
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
    of StreamCommand.BsStream:
      echo "StreamCommand.BsStream"
      try:
        var json = StreamDataBsStream(cdata.data).data
        echo json.pretty
        if json.hasKey("height"):
          echo "height"
          var mempool_tmp: JsonNode = newJArray()
          let j_mempool = blockstor.getMempool()
          if j_mempool.kind != JNull and j_mempool.hasKey("res") and getBsErrorCode(j_mempool["err"].getInt) == BsErrorCode.SUCCESS:
            for m in j_mempool["res"]:
              mempool_tmp.add(m)
          mempool = mempool_tmp

        elif json.hasKey("mempool"):
          echo "mempool"
          for m in json["mempool"]:
            mempool.add(m)
      except:
        let e = getCurrentException()
        echo e.name, ": ", e.msg

    of StreamCommand.BsStreamInit:
      let j_mempool = blockstor.getMempool()
      if j_mempool.kind != JNull and j_mempool.hasKey("res") and getBsErrorCode(j_mempool["err"].getInt) == BsErrorCode.SUCCESS:
        for m in j_mempool["res"]:
          mempool.add(m)

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

proc UserUtxoCmp(x, y: UserUtxo): int =
  result = cmp(x.sequence, y.sequence)
  if result == 0:
    result = cmp(x.change, y.change)
    if result == 0:
      result = cmp(x.index, y.index)

proc hash*(x: UserUtxo): Hash =
  var s: string = $x.sequence & "-" & x.txid & "-" & $x.n
  result = s.hash

proc hash*(x: WidAddressPairs): Hash =
  var s: string = $x.wid & "-" & x.address
  result = s.hash

proc clientUnspents(wallets: seq[uint64]): seq[UserUtxo] =
  var addrInfos = initTable[string, UserAddrInfo]()
  for i, wid in wallets:
    for a in db.getAddrvals(wid):
      addrInfos.add(a.address, UserAddrInfo(change: a.change, index: a.index, xpub_idx: i))

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
    unspents.delete(1000, unspents.high)
  unspents

proc ball_main() {.thread.} =
  var wallet_ids = initHashSet[WalletIds]()
  var client_unspents = initTable[WalletId, HashSet[UserUtxo]]()
  var active_wids = initHashSet[WalletId]()
  var full_wid_addrs = initHashSet[WidAddressPairs]()

  proc sendUnconfs(wid_addrs: HashSet[WidAddressPairs], wids: seq[WalletIds], send_empty: bool = false): WalletIds {.discardable.} =
    var sent_wids: WalletIds
    for wallets in wids:
      var sent = false
      var addrs_array: seq[string] = @[]
      for wid_addr in wid_addrs:
        if wallets.contains(wid_addr.wid):
          addrs_array.add(wid_addr.address)
      echo "addrs_array.len=", addrs_array.len, " ", addrs_array
      if addrs_array.len > 0:
        echo blockstor.getAddress(addrs_array)
        var j_unconfs = blockstor.getUnconf(addrs_array)
        echo "j_unconfs=", j_unconfs
        if j_unconfs.kind != JNull:
          var json = %*{"type": "unconfs"}
          json.add("data", newJObject())
          for i, a in addrs_array:
            var j = j_unconfs["res"][i]
            if j.hasKey("spents"):
              for v in j["spents"]:
                v["value"] = j_uint64(v["value"].getUint64)
            if j.hasKey("txouts"):
              for v in j["txouts"]:
                v["value"] = j_uint64(v["value"].getUint64)
              json["data"][a] = j
            for da in db.getAddresses(a):
              var idx = wallets.find(da.wid)
              if idx >= 0:
                json["data"][a].add("change", newJInt(da.change.BiggestInt))
                json["data"][a].add("index", newJInt(da.index.BiggestInt))
                json["data"][a].add("xpub_idx", newJInt(idx.BiggestInt))
                break
          let client_wid: WalletId = wallets[0]
          stream.send(client_wid, $json)
          sent_wids.add(client_wid)
          sent = true
          echo "BallCommand.BsStream=", json
      if send_empty and not sent:
        var json = %*{"type": "unconfs"}
        json.add("data", newJObject())
        let client_wid: WalletId = wallets[0]
        stream.send(client_wid, $json)
    sent_wids

  proc fullMempoolAddrs(): HashSet[WidAddressPairs] =
    var wid_addrs = initHashSet[WidAddressPairs]()
    let j_mempool = blockstor.getMempool()
    if j_mempool.kind != JNull and j_mempool.hasKey("res") and getBsErrorCode(j_mempool["err"].getInt) == BsErrorCode.SUCCESS:
      for m in j_mempool["res"]:
        for a in m["addrs"].pairs:
          for da in db.getAddresses(a.key):
            if active_wids.contains(da.wid):
              wid_addrs.incl([WidAddressPairs(wid: da.wid, address: a.key)].toHashSet())
    wid_addrs

  proc mempoolAddrs(mempool: JsonNode): HashSet[WidAddressPairs] =
    var wid_addrs = initHashSet[WidAddressPairs]()
    for m in mempool:
      for a in m["addrs"].pairs:
        for da in db.getAddresses(a.key):
          if active_wids.contains(da.wid):
            wid_addrs.incl([WidAddressPairs(wid: da.wid, address: a.key)].toHashSet())
    for w in wid_addrs:
      echo w.wid, " ", w.address
    wid_addrs

  while true:
    let ch_data = ballChannel.recv()
    debug "ballChannel cmd=", ch_data.cmd
    case ch_data.cmd
    of BallCommand.BsStream:
      try:
        var j_bs = BallDataBsStream(ch_data.data).data
        echo j_bs.pretty
        var sent_wids: WalletIds
        if j_bs.hasKey("height"):
          full_wid_addrs = fullMempoolAddrs()
          sent_wids = sendUnconfs(full_wid_addrs, wallet_ids.toSeq, true)
        elif j_bs.hasKey("mempool"):
          var wid_addrs = mempoolAddrs(j_bs["mempool"])
          full_wid_addrs = full_wid_addrs + wid_addrs
          sent_wids = sendUnconfs(full_wid_addrs, wallet_ids.toSeq)
        for w in sent_wids:
          BallCommand.Unused.send(BallDataUnused(wallet_id: w))
      except:
        let e = getCurrentException()
        echo e.name, ": ", e.msg

    of BallCommand.MemPool:
      var data = BallDataMemPool(ch_data.data)
      echo data.client.wallets
      full_wid_addrs = fullMempoolAddrs()
      sendUnconfs(full_wid_addrs, @[data.client.wallets], true)

    of BallCommand.Unspents:
      var data = BallDataUnspents(ch_data.data)
      echo data.client.wallets
      var unspents: seq[UserUtxo] = @[]
      let client_wid: WalletId = data.client.wallets[0]
      if data.client.wallets.len > 0:
        unspents = clientUnspents(data.client.wallets)
        client_unspents[client_wid] = unspents.toHashSet()
      var json = %*{"type": "unspents", "data": unspents}
      for j in json["data"]:
        j["value"] = j_uint64(j["value"].getUint64)
      echo json
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
        echo "unconf_idxs=", unconf_idxs
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
      echo json
      stream.send(client_wid, $json)

    of BallCommand.AddClient:
      var data = BallDataAddClient(ch_data.data)
      echo data.client.wallets
      wallet_ids.incl(data.client.wallets)
      active_wids.incl(data.client.wallets.toHashSet())
      BallCommand.Unspents.send(BallDataUnspents(client: data.client))
      BallCommand.MemPool.send(BallDataMemPool(client: data.client))
      BallCommand.Unused.send(BallDataUnused(wallet_id: data.client.wallets[0]))

    of BallCommand.DelClient:
      var data = BallDataDelClient(ch_data.data)
      echo data.client.wallets
      let client_wid: WalletId = data.client.wallets[0]
      wallet_ids.excl(data.client.wallets)
      var find = false
      for wallets in wallet_ids:
        if wallets[0] == client_wid:
          find = true
          break
      if not find:
        active_wids.excl(data.client.wallets.toHashSet())

    of BallCommand.Abort:
      return

proc stop*() =
  active = false
  event.setEvent()
  StreamCommand.Abort.send()
  BallCommand.Abort.send()
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
  createThread(threads[1], ball_main)
  createThread(threads[2], cmd_main)
  createThread(threads[3], watcher_main)
  createThread(threads[4], stream_main)
  addQuitProc(quit)
  threads[3]
