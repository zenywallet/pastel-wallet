# Copyright (c) 2019 zenywallet

import std/json
import std/algorithm
import caprese
import caprese/bearssl/hash
import templates/layout_base
import ctrmode
import ed25519
import yespower
import ../deps/zip/zip/zlib

type Page* {.pure.} = enum
  Release
  Maintenance
  Debug

var page*: Page = Page.Release

type
  ClientExt {.clientExt.} = object
    kp: tuple[pubkey: Ed25519PublicKey, prvkey: Ed25519PrivateKey]
    ctr: ctrmode.CTR
    salt: array[64, byte]
    exchange: bool

type
  PendingData = object
    msg: string

var wsReqs: Pendings[PendingData]
wsReqs.newPending(limit = 1000000)

proc sha256s(data: openarray[byte]): array[32, byte] =
  var sha256Context: br_sha256_context
  br_sha256_init(addr sha256Context)
  br_sha256_update(addr sha256Context, addr data[0], data.len.csize_t)
  br_sha256_out(addr sha256Context, addr result)

proc `xor`(a: array[32, byte], b: array[32, byte]): array[32, byte] =
  for i in a.low..a.high:
    result[i] = a[i] xor b[i]

proc `xor`(a: array[32, byte], b: ptr array[32, byte]): array[32, byte] =
  for i in a.low..a.high:
    result[i] = a[i] xor b[i]

proc yespower(a: array[32, byte]): array[32, byte] {.inline.} =
  discard yespower_hash(cast[ptr UncheckedArray[byte]](unsafeAddr a[0]), 32, cast[ptr UncheckedArray[byte]](addr result))

worker(1):
  wsReqs.recvLoop(req):
    try:
      let json_cmd = parseJson(req.data.msg)
      echo json_cmd
    except:
      let e = getCurrentException()
      echo e.name, ": ", e.msg

const deflateSentinel = [byte 0x00, 0x00, 0x00, 0xff, 0xff, 0x01, 0x00, 0x00, 0xff, 0xff]

server(ip = "0.0.0.0", port = 5000):
  routes:
    get "/":
      case page
      of Page.Release:
        layout_release.addHeader.send
      of Page.Maintenance:
        layout_maintenance.addHeader(Status503).send
      of Page.Debug:
        layout_debug.addHeader.send

    public(importPath = "../public")

    stream(path = "/ws", protocol = "pastel-v0.1"):
      onOpen:
        echo "onOpen"
        var kpSeed: array[32, byte]
        var retSeed = cryptSeed(cast[ptr UncheckedArray[byte]](addr kpSeed), 32.cint)
        if retSeed != 0: raise
        createKeypair(client.kp.pubkey, client.kp.prvkey, kpSeed)
        retSeed = cryptSeed(cast[ptr UncheckedArray[byte]](addr client.salt), 64.cint)
        if retSeed != 0: raise
        client.exchange = false
        wsSend((client.kp.pubkey, client.salt).toBytes)

      onMessage:
        echo "onMessage"
        if not client.exchange:
          if size == 32:
            var clientPublicKey: Ed25519PublicKey
            copyMem(addr clientPublicKey, data, clientPublicKey.len)
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
            echo "shared=", shared_key
            echo "iv_srv=", iv_srv
            echo "iv_cli=", iv_cli
            client.ctr.init(shared_key, iv_srv, iv_cli)
            client.exchange = true
            SendResult.Pending
          else:
            SendResult.None
        else:
          echo "data=", content.toBytes
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
          copyMem(addr rdata[size], addr deflateSentinel[0], deflateSentinel.len)
          let uncomp = uncompress((cast[ptr char](addr rdata[0])).cstring, rdata.len, stream = RAW_DEFLATE)
          wsReqs.pending(PendingData(msg: uncomp))

      onClose:
        echo "onClose"

    get "/api/pub/:pubkey":
      var data = %*{"pub": sanitizeHtml(pubkey)}
      ($data).addHeader("json").send

    "Not found".addHeader(Status404).send

serverStart(wait = false)

proc main() {.thread.} =
  serverWait()

proc start*(): ref Thread[void] =
  var thread = new Thread[void]
  createThread(thread[], main)
  thread


when isMainModule:
  main()
