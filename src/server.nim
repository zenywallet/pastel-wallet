# Copyright (c) 2019 zenywallet

import std/json
import std/algorithm
import std/locks
import std/sequtils
import std/times
import std/cpuinfo
import caprese
import caprese/bearssl/hash
import caprese/server_types
import caprese/hashtable
import caprese/bytes
import caprese/arraylib
import templates/layout_base
import base_css
import seed_html
import ctrmode
import zenyjs/ed25519
import zenyjs/yespower
import logs as patelog except debug
import db
import blockstor except send
import stream
import pages
import config

when USE_LZ4:
  import zenyjs/lz4
else:
  import ../deps/zip/zip/zlib
  when not defined(ROCKSDB_DEFAULT_COMPRESSION):
    import zenyjs/lz4

config:
  sigTermQuit = false

server(ssl = true, ip = "0.0.0.0", port = config.HttpsPort):
  streamInit()

  routes(host = config.HttpsHost):
    get "/":
      case page
      of Page.Release:
        layout_release.addHeader.send
      of Page.Maintenance:
        layout_maintenance.addHeader(Status503).send
      of Page.Debug:
        layout_debug.addHeader.send

    public(importPath = "../public")

    get "/css/base.css":
      BaseCss.content("css").response

    stream(path = "/ws", protocol = "pastel-v0.1"):
      onOpen:
        streamOpen()
      streamMain()

    get "/seed":
      SeedHtml.content("html").response

    acme(path = config.AcmePath)

    get "/api/pub/:pubkey":
      var data = %*{"pub": sanitizeHtml(pubkey)}
      ($data).addHeader("json").send

    "Not found".addHeader(Status404).send

server(ip = "0.0.0.0", port = config.HttpPort):
  routes(host = config.HttpHost):
    send(redirect301(config.HttpRedirect & reqUrl))

serverStart(wait = false)

proc main() {.thread.} =
  serverWait()

proc start*(): ref Thread[void] =
  var thread = new Thread[void]
  createThread(thread[], main)
  thread


when isMainModule:
  main()
