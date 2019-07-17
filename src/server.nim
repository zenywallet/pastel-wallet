# Copyright (c) 2019 zenywallet

import jester, json

proc main() {.thread.} =
  routes:
    get "/":
      redirect "index.html"

    get "/api/pub/@pubkey":
      var data = %*{"pub": @"pubkey"}
      resp $data, "application/json"

var thread: Thread[void]

proc start*(): Thread[void] =
  createThread(thread, main)
  thread


when isMainModule:
  main()
