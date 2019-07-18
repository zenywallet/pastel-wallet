import os, locks, asyncdispatch
import libbtc
import blockstor, db, events

var
  worker: Thread[int]
  event = createEvent()
  active = true
  ready* = true

proc threadWorkerFunc(cb: int) {.thread.} =
  echo "worker start"
  while active:
    ready = false
    echo "do work"
    sleep(1000)
    ready = true
    waitFor event
  echo "worker stop"

proc doWork*() =
  event.setEvent()

proc start*() =
  active = true
  btc_ecc_start()
  createThread(worker, threadWorkerFunc, 0)

proc stop*() =
  active = false
  event.setEvent()
  joinThread(worker)
  echo "after joinThread"
  btc_ecc_stop()

block start:
  echo "watcher start"
  start()

  proc quit() {.noconv.} =
    stop()
    echo "watcher stop"

  addQuitProc(quit)

when isMainModule:
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
