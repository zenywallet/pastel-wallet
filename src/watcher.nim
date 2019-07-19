# Copyright (c) 2019 zenywallet

import os, locks, asyncdispatch, sequtils
import libbtc
import blockstor, db, events

const gaplimit: uint32 = 20

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
  for d in db.getWallets(""):
    echo "wid=", d.wallet_id, " ", d.xpubkey
    var address_list: seq[tuple[wid: uint64, change: uint32, index: uint32, address: string]]
    var prev_list: seq[tuple[wid: uint64, change: uint32, index: uint32, address: string]]
    var addrs: seq[string]
    var new_last_0_index, new_last_1_index: uint32
    var base_index: uint32 = 0
    var find_0 = true
    var find_1 = true
    new_last_0_index = d.last_0_index
    new_last_1_index = d.last_1_index

    var try_limit = 10
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
        if balance["err"].getInt == 0:
          var pos = 0
          for b in balance["res"]:
            if b.hasKey("balance"):
              if address_list[pos].change == 0:
                new_last_0_index = address_list[pos].index + 1
                find_0 = true
              elif  address_list[pos].change == 1:
                new_last_1_index = address_list[pos].index + 1
                find_1 = true
            inc(pos)
        prev_list = prev_list.concat(address_list)

      dec(try_limit)
      if try_limit <= 0:
        break

    echo prev_list
    if find_0 or find_1:
      echo "postpone ", find_0, " ", find_1, " ", new_last_0_index, " ", new_last_1_index, " wid=", d.wallet_id, " ", d.xpubkey

    for d in prev_list:
      if d.change == 0:
        if d.index < new_last_0_index + gap_limit:
          echo d.change, " ", d.index
      elif d.change == 1:
        if d.index < new_last_1_index + gap_limit:
          echo d.change, " ", d.index

    echo "new_last_0_index=", new_last_0_index
    echo "new_last_1_index=", new_last_1_index

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
