# Copyright (c) 2019 zenywallet

import jester, json
import templates/layout_base

type Page* {.pure.} = enum
  Release
  Maintenance
  Debug

var page*: Page = Page.Release

proc main() {.thread.} =
  routes:
    get "/":
      case page
      of Page.Release:
        resp layout_release()
      of Page.Maintenance:
        resp Http503, layout_maintenance()
      of Page.Debug:
        resp layout_debug()

    get "/api/pub/@pubkey":
      var data = %*{"pub": @"pubkey"}
      resp $data, "application/json"

    error Http404:
      resp Http404, "Not found"

    error Exception:
      resp Http500, "Server error"

var thread: Thread[void]

proc start*(): Thread[void] =
  createThread(thread, main)
  thread


when isMainModule:
  main()
