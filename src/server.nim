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

      onMessage:
        debug "onMessage"
        if not client.exchange:
          if size == 64:
            var clientPublicKey: Ed25519PublicKey
            copyMem(addr clientPublicKey, data, clientPublicKey.len)
            copyMem(addr client.salt[32], addr data[32], 32)
            var shared: Ed25519SharedSecret
            keyExchange(shared, clientPublicKey, client.kp.prvkey)
            let shared_sha256 = sha256s(shared)
            let shared_key = yespower(shared_sha256)
            let seed_srv = cast[ptr array[32, byte]](addr client.salt[0])
            let seed_cli = cast[ptr array[32, byte]](addr client.salt[32])
            let iv_srv_sha256 = sha256s(shared_key xor seed_srv)
            let iv_cli_sha256 = sha256s(shared_key xor seed_cli)
            let iv_srv = yespower(iv_srv_sha256)
            let iv_cli = yespower(iv_cli_sha256)
            debug "shared=", shared_key
            debug "iv_srv=", iv_srv
            debug "iv_cli=", iv_cli
            client.ctr.init(shared_key, iv_srv, iv_cli)
            client.exchange = true
            when USE_LZ4:
              client.streamComp = LZ4_createStream()
              if client.streamComp.isNil: raise newException(StreamCriticalErr, "lz4 create stream")
              let p = cast[ptr UncheckedArray[byte]](allocShared0(LZ4_DICT_SIZE * 2))
              client.encDict = cast[ptr UncheckedArray[byte]](addr p[0])
              client.decDict = cast[ptr UncheckedArray[byte]](addr p[LZ4_DICT_SIZE])
            SendResult.Pending
          else:
            SendResult.None
        else:
          debug "data=", content.toBytes
          when USE_LZ4:
            var rdata = newSeq[byte](size)
          else:
            var rdata = newSeq[byte](size + deflateSentinel.len)
          var pos = 0
          var next_pos = 16
          while next_pos < size:
            client.ctr.decrypt(cast[ptr UncheckedArray[byte]](addr data[pos]),
                              cast[ptr UncheckedArray[byte]](addr rdata[pos]))
            pos = next_pos
            next_pos = next_pos + 16
          if pos < size:
            var src: array[16, byte]
            var dec: array[16, byte]
            var plen = size - pos
            src.fill(cast[byte](plen))
            copyMem(addr src[0], addr data[pos], plen)
            client.ctr.decrypt(cast[ptr UncheckedArray[byte]](addr src[0]),
                              cast[ptr UncheckedArray[byte]](addr dec[0]))
            copyMem(addr rdata[pos], addr dec[0], plen)
          when USE_LZ4:
            var outsize: int = LZ4_decompress_safe_usingDict(cast[cstring](addr rdata[0]),
                    cast[cstring](addr ctx.decBuf[0]), size.cint,
                    ctx.decBufSize.cint, cast[cstring](addr client.decDict[0]), LZ4_DICT_SIZE.cint)
            if outsize > LZ4_DICT_SIZE:
              copyMem(addr client.decDict[0], addr ctx.decBuf[outsize - LZ4_DICT_SIZE], LZ4_DICT_SIZE)
            elif outsize > 0:
              let left = LZ4_DICT_SIZE - outsize
              copyMem(addr client.decDict[0], addr client.decDict[outsize], left)
              copyMem(addr client.decDict[left], addr ctx.decBuf[0], outsize)
            else:
              raise newException(StreamCriticalErr, "lz4 decompress")
            wsReqs.pending(PendingData(msg: ctx.decBuf.toString(outsize)))
          else:
            copyMem(addr rdata[size], addr deflateSentinel[0], deflateSentinel.len)
            let uncomp = uncompress((cast[ptr char](addr rdata[0])).cstring, rdata.len, stream = RAW_DEFLATE)
            wsReqs.pending(PendingData(msg: uncomp))

      onClose:
        debug "onClose"
        let clientId = client.markPending()
        withLock workerClientsLock:
          for wid in client.wallets:
            var hdata = walletmap.get(wid)
            if not hdata.isNil:
              var wmdatas = hdata.val
              wmdatas.keepIf(proc (x: WalletMapData): bool = x.clientId != clientId)
              if wmdatas.len > 0:
                walletmap.set(wid, wmdatas)
              else:
                walletmap.del(wid)
                var hdata2 = walletmap.get(wid)
        BallCommand.DelClient.send(BallDataDelClient(client: clientId))
        client.xpubs = @[]
        when USE_LZ4:
          if not client.streamComp.isNil:
            deallocShared(client.encDict)
            discard client.streamComp.LZ4_freeStream()
            client.streamComp = nil

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
