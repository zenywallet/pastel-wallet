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

proc enumRangeCheck(enumtype: type, value: int): bool =
  (enumtype.low.ord..enumtype.high.ord).contains(value)

proc main() =
  let marker = blockstor.getMarker(blockstor_apikey)
  if marker.kind == JNull:
    echo "error: getmarker is null"
    return

  let err_int = marker["err"].getInt
  if not BsErrorCode.enumRangeCheck(err_int):
    echo "error: out of range", err_int
    return
  let getmarker_err = BsErrorCode(err_int)
  case getmarker_err
  of BsErrorCode.ROLLBACKING:
    echo "info: blockstor rollbacking"
    return

  of BsErrorCode.UNKNOWN_APIKEY:
    echo "error: invalid apikey"
    return

  of BsErrorCode.SUCCESS:
    let marker_sequence = marker["res"].getUint64
    var max_sequence = marker_sequence

    for d in db.getWallets(""):
      echo "wid=", d.wallet_id, " ", d.xpubkey
      if max_sequence <= d.sequence:
        echo "skip - wid=", d.wallet_id
        continue
      var address_list: seq[tuple[wid: uint64, change: uint32, index: uint32, address: string]]
      var target_list: seq[tuple[wid: uint64, change: uint32, index: uint32, address: string,
                          used: bool, value: uint64, utxo_count: uint32]]
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

      db.setWallet(d.xpubkey, d.wallet_id, max_sequence,
                  new_last_0_index, new_last_1_index)

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

    let smarker = blockstor.setMarker(blockstor_apikey, max_sequence)
    if smarker.kind == JNull:
      echo "error: setmarker is null"
      return
    let s_err_int = smarker["err"].getInt
    if not BsErrorCode.enumRangeCheck(s_err_int):
      echo "error: out of range err=", s_err_int
      return
    let smarker_err = BsErrorCode(s_err_int)
    if smarker_err != BsErrorCode.SUCCESS:
      echo "info: setmarker err=", smarker_err

  of BsErrorCode.ROLLBACKED:
    echo marker
    let rollbacked_sequence = marker["res"].getUint64
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
        echo "error: getaddress len=", addrs.len, " reslen=", balance.resLen
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
                  d.last_0_index, d.last_1_index)

      for a in tbd_addrs:
        db.setAddress(a.address, a.change, a.index, d.wallet_id, rollbacked_sequence)
      delAddrlogs_gt(d.wallet_id, rollbacked_sequence)

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

    let smarker_update = blockstor.setMarker(blockstor_apikey, rollbacked_sequence)
    if smarker_update.kind == JNull:
      echo "error: setmarker in rollback is null"
      return
    let su_err_int = smarker_update["err"].getInt
    if not BsErrorCode.enumRangeCheck(su_err_int):
      echo "error: out of range err=", su_err_int
      return
    let smarker_update_err = BsErrorCode(su_err_int)
    if smarker_update_err != BsErrorCode.SUCCESS:
      echo "info: setmarker err=", smarker_update_err

  else:
    echo "error: getmarker err=", getmarker_err

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
