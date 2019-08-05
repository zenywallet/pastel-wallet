# Copyright (c) 2019 zenywallet

import locks

type
  Event* = object
    cond: Cond
    lock: Lock
    signal: bool

proc createEvent*(): Event =
  var ev: Event
  initCond(ev.cond)
  initLock(ev.lock)
  ev.signal = false

proc closeEvent*(ev: var Event) {.inline.} =
  deinitLock(ev.lock)
  deinitCond(ev.cond)

proc waitFor*(ev: var Event) =
  acquire(ev.lock)
  if not ev.signal:
    wait(ev.cond, ev.lock)
  ev.signal = false
  release(ev.lock)

proc setEvent*(ev: var Event) =
  acquire(ev.lock)
  ev.signal = true
  signal(ev.cond)
  release(ev.lock)
