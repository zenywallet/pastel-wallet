# Copyright (c) 2019 zenywallet

import os, locks, asyncdispatch, sequtils
import libbtc
import blockstor, db, events

const gaplimit: uint32 = 20
const blockstor_apikey = "sample-969a6d71-a259-447c-a486-90bac964992b"

var
  worker: Thread[int]
  event = createEvent()
  active = true
  ready* = true

var chain = bitzeny_chain
const extkeyout_size: csize = 128
const address_size: csize = 128
proc hdaddress(xpubkey: string, change, index: uint32): string =
  result = ""
  let keypath: cstring = "m/" & $change & "/" & $index
  var extkeyout: cstring = newString(extkeyout_size)
  if not hd_derive(addr chain, xpubkey, keypath, extkeyout, extkeyout_size):
    return
  var node: btc_hdnode
  if not btc_hdnode_deserialize(extkeyout, addr chain, addr node):
    return
  var address: cstring = newString(address_size)
  btc_hdnode_get_p2pkh_address(addr node, addr chain, address, cast[cint](address_size))
  result = $address

proc main() =
  let marker = blockstor.getMarker(blockstor_apikey)
  if marker.kind == JNull or marker["err"].getInt != 0:
    echo "error: marker=", marker
    return
  echo "marker=", marker
  let marker_sequence = marker["res"].getUint64
  var max_sequence = marker_sequence

  for d in db.getWallets(""):
    echo "wid=", d.wallet_id, " ", d.xpubkey
    var address_list: seq[tuple[wid: uint64, change: uint32, index: uint32,
                          address: string]]
    var target_list: seq[tuple[wid: uint64, change: uint32, index: uint32,
                          address: string, used: bool, value: uint64,
                          utxo_count: uint32]]
    var addrs: seq[string]
    var new_last_0_index, new_last_1_index: uint32
    var base_index: uint32 = 0
    var find_0 = true
    var find_1 = true
    new_last_0_index = d.last_0_index
    new_last_1_index = d.last_1_index

    var try_limit = 10
    target_list = @[]
    while find_0 or find_1:
      address_list = @[]
      addrs = @[]
      if find_0:
        for i in (d.last_0_index + base_index)..(d.last_0_index + base_index + gaplimit - 1'u32):
          var address = hdaddress(d.xpubkey, 0, i)
          if address.len <= 0:
            break
          address_list.add((wid: d.wallet_id, change: 0'u32, index: i, address: address))
          addrs.add(address)

      if find_1:
        for i in (d.last_1_index + base_index)..(d.last_1_index + base_index + gaplimit - 1'u32):
          var address = hdaddress(d.xpubkey, 1, i)
          if address.len <= 0:
            break
          address_list.add((wid: d.wallet_id, change: 1'u32, index: i, address: address))
          addrs.add(address)
      base_index = base_index + gaplimit

      find_0 = false
      find_1 = false
      if addrs.len > 0:
        let balance = blockstor.getAddress(addrs)
        if addrs.len == balance.resLen:
          var pos = 0
          for b in balance.toApiResIterator:
            if b{"balance"} != nil:
              if address_list[pos].change == 0:
                new_last_0_index = address_list[pos].index + 1
                find_0 = true
              elif address_list[pos].change == 1:
                new_last_1_index = address_list[pos].index + 1
                find_1 = true
              target_list.add((address_list[pos].wid, address_list[pos].change,
                            address_list[pos].index, address_list[pos].address,
                            true, b["balance"].getUint64,
                            b["utxo_count"].getUint32))
            else:
              target_list.add((address_list[pos].wid, address_list[pos].change,
                            address_list[pos].index, address_list[pos].address,
                            false, 0'u64, 0'u32))
            inc(pos)

      dec(try_limit)
      if try_limit <= 0:
        break

    echo target_list
    if find_0 or find_1:
      echo "postpone ", find_0, " ", find_1, " ", new_last_0_index, " ",
            new_last_1_index, " wid=", d.wallet_id, " ", d.xpubkey

    target_list.keepIf(proc(d: auto): bool =
      (d.change == 0 and d.index < new_last_0_index + gap_limit) or
      (d.change == 1 and d.index < new_last_1_index + gap_limit))

    echo target_list

    echo "new_last_0_index=", new_last_0_index
    echo "new_last_1_index=", new_last_1_index

    for t in target_list:
      let addrlogs = blockstor.getAddrlog(t.address, (gt: marker_sequence,
                                          limit: 1000, reverse: 0,
                                          seqbreak: 1))
      for a in addrlogs.toApiResIterator:
        db.setAddrlog(t.wid, a["sequence"].getUint64, a["type"].getUint8,
                      t.change, t.index, t.address, a["value"].getUint64,
                      a["txid"].getStr, a["height"].getUint32,
                      a["time"].getUint32)
      if addrlogs.resLen > 0:
        max_sequence = max(max_sequence, addrlogs["res"][addrlogs.resLen - 1]["sequence"].getUint64)
      let utxos = blockstor.getUtxo(t.address, (gt: marker_sequence,
                                    limit: 1000, reverse: 0, seqbreak: 1))
      for a in utxos.toApiResIterator:
        db.setUnspent(t.wid, a["sequence"].getUint64, a["txid"].getStr,
                      a["n"].getUint32, t.address, a["value"].getUint64)

    echo "max_sequence=", max_sequence

    for t in target_list:
      if t.used:
        db.setAddrval(t.wid, t.change, t.index, t.address, t.value, t.utxo_count)
      db.setAddress(t.address, t.change, t.index, t.wid, max_sequence)

    db.setWallet(d.xpubkey, d.wallet_id, max_sequence, new_last_0_index,
                new_last_1_index)
    let smarker = blockstor.setMarker(blockstor_apikey, max_sequence)
    echo "smarker=", smarker
    if smarker.kind != JNull:
      case smarker["err"].getInt:
        of ord(BsErrorCode.SUCCESS), ord(BsErrorCode.ROLLBACKING):
          echo "done"
        of ord(BsErrorCode.ROLLBACKED):
          let sequence = smarker["res"].getUint64
          # > seq: remove
          let smarker = blockstor.setMarker(blockstor_apikey, sequence)
        of ord(BsErrorCode.UNKNOWN_APIKEY):
          echo "invalid apikey"
        else:
          echo "setmaker err=", smarker["err"].getInt

    echo "---getWallet"
    echo db.getWallet(d.xpubkey)
    echo "---getAddrvals"
    for g in db.getAddrvals(1'u64):
      echo g
    echo "---getAddrlogs"
    for g in db.getAddrlogs(1'u64):
      echo g
    echo "---getUnspents"
    for g in db.getUnspents(1'u64):
      echo g
    echo "---getAddresses"
    for g in db.getAddresses("Z.."):
      echo g

    when isMainModule:
      active = false
      event.setEvent()

proc threadWorkerFunc(cb: int) {.thread.} =
  while active:
    ready = false
    echo "do work"
    main()
    ready = true
    waitFor event

proc doWork*() =
  event.setEvent()

proc start*() =
  echo "watcher start"
  active = true
  btc_ecc_start()
  createThread(worker, threadWorkerFunc, 0)

proc stop*() =
  active = false
  event.setEvent()
  joinThread(worker)
  btc_ecc_stop()
  echo "watcher stop"

block start:
  start()

  proc quit() {.noconv.} =
    stop()

  addQuitProc(quit)

when isMainModule:
  #[
  proc test() {.async.} =
    for i in 1..20:
      echo i
      while ready == false:
        echo "wait ready"
        await sleepAsync(200)
      echo "ready=", ready
      doWork()
      await sleepAsync(200)

  proc test2() {.async.} =
    await sleepAsync(5000)
    stop()
    await sleepAsync(1000)
    start()
    await sleepAsync(5000)

  asyncCheck test()
  waitFor test2()
  ]#
  joinThread(worker)
