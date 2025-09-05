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
import ed25519
import yespower
import ../deps/zip/zip/zlib
import logs as patelog except debug
import db
import blockstor except send
import stream
import config

const USE_LZ4 = true
when USE_LZ4:
  import lz4
  const LZ4_DICT_SIZE = 64 * 1024

config:
  sigTermQuit = false

type Page* {.pure.} = enum
  Release
  Maintenance
  Debug

var page*: Page = Page.Release

when USE_LZ4:
  const DECODE_BUF_SIZE = 1048576
  type
    ServerThreadCtxExt {.serverThreadCtxExt.} = object
      decBuf: ptr UncheckedArray[byte]
      decBufSize: int
else:
  const deflateSentinel = [byte 0x00, 0x00, 0x00, 0xff, 0xff, 0x01, 0x00, 0x00, 0xff, 0xff]

server(ssl = true, ip = "0.0.0.0", port = config.HttpsPort):
  when USE_LZ4:
    ctx.decBuf = cast[ptr UncheckedArray[byte]](allocShared0(DECODE_BUF_SIZE))
    ctx.decBufSize = DECODE_BUF_SIZE
    defer:
      ctx.decBufSize = 0
      ctx.decBuf.deallocShared()

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
        client.streamOpen()
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
