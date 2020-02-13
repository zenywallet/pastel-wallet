# Copyright (c) 2019 zenywallet

import ../deps/"websocket.nim"/websocket, asynchttpserver, asyncnet, asyncdispatch
import nimcrypto, ed25519, sequtils, os, threadpool, tables, locks, strutils
import json, algorithm, hashes, times
import ../deps/zip/zip/zlib
import unicode
import ../src/ctrmode
import db, events, yespower, logs, blockstor

type
  WalletId* = uint64
  WalletIds* = seq[WalletId]
  WalletXpub* = string
  WalletXPubs* = seq[WalletXpub]

type ClientData* = ref object
  ws: AsyncWebSocket
  kp: KeyPair
  ctr: ctrmode.CTR
  salt: array[64, byte]
  wallets*: WalletIds
  xpubs*: WalletXPubs

proc hash*(xs: WalletIds): Hash =
  var s: string
  for x in xs:
    s.add("#" & $x)
  result = s.hash

type WalletMapData = ref object
  fd: int
  salt: array[64, byte]

type UnspentsData* = object
  sequence: uint64
  txid: string
  n: uint32
  address: string
  value: uint64
  change: uint32
  index: uint32
  xpub_idx: int

type StreamCommand* {.pure.} = enum
  Abort
  Unconfs
  Balance
  Addresses
  Unused
  BsStream
  BsStreamInit

type
  StreamData* = ref object of RootObj
  StreamDataUnconfs* = ref object of StreamData
    wallets*: WalletIds
  StreamDataBalance* = ref object of StreamData
    wallets*: WalletIds
  StreamDataAddresses* = ref object of StreamData
    wallets*: WalletIds
  StreamDataUnused* = ref object of StreamData
    wallet_id*: WalletId
  StreamDataBsStream* = ref object of StreamData
    data*: JsonNode

var sendMesChannel: Channel[tuple[wallet_id: uint64, data: string]]
sendMesChannel.open()

proc send*(wallet_id: uint64, data: string) =
  sendMesChannel.send((wallet_id, data))

var cmdChannel*: Channel[tuple[cmd: StreamCommand, data: StreamData]]
cmdChannel.open()

proc send*(cmd: StreamCommand, data: StreamData = nil) =
  cmdChannel.send((cmd, data))

type
  BallCommand* {.pure.} = enum
    Abort
    AddClient
    DelClient
    MemPool
    Unspents
    Unused
    Change
    Height
    Rollback
    Rollbacked
    BsStream

  BallData* = ref object of RootObj
  BallDataAddClient* = ref object of BallData
    client*: ClientData
  BallDataDelClient* = ref object of BallData
    client*: ClientData
  BallDataMemPool* = ref object of BallData
    client*: ClientData
  BallDataUnspents* = ref object of BallData
    client*: ClientData
  BallDataUnused* = ref object of BallData
    wallet_id*: WalletId
  BallDataChange* = ref object of BallData
    wallet_id*: WalletId
  BallDataHeight* = ref object of BallData
    wallet_id*: WalletId
  BallDataRollback* = ref object of BallData
    wallet_id*: WalletId
    sequence*: uint64
  BallDataRollbacked* = ref object of BallData
    sequence*: uint64
  BallDataBsStream* = ref object of BallData
    data*: JsonNode

var ballChannel*: Channel[tuple[cmd: BallCommand, data: BallData]]
ballChannel.open()

proc send*(cmd: BallCommand, data: BallData = nil) =
  ballChannel.send((cmd, data))

type
  TxLog = ref object
    sequence: uint64
    txtype: uint8
    address: string
    value: uint64
    txid: string
    height: uint32
    time: uint32
    change: uint32
    index: uint32
    xpub_idx: int
    trans_time: uint64
  TxLogs = seq[Txlog]

proc SequenceCmp[T](x, y: T): int =
  result = cmp(x.sequence, y.sequence)
  if result == 0:
    result = cmp(x.change, y.change)
    if result == 0:
      result = cmp(x.index, y.index)

proc SequenceRevCmp[T](x, y: T): int =
  result = cmp(y.sequence, x.sequence)
  if result == 0:
    result = cmp(y.change, x.change)
    if result == 0:
      result = cmp(y.index, x.index)

proc TxLogCmp[T](x, y: T): int =
  result = cmp(x.height, y.height)
  if result == 0:
    result = cmp(x.time, y.time)
    if result == 0:
      result = cmp(x.trans_time, y.trans_time)
      if result == 0:
        result = cmp(x.change, y.change)
        if result == 0:
          result = cmp(x.index, y.index)
          if result == 0:
            result = cmp(x.xpub_idx, y.xpub_idx)

proc TxLogRevCmp[T](x, y: T): int =
  result = cmp(y.height, x.height)
  if result == 0:
    result = cmp(y.time, x.time)
    if result == 0:
      result = cmp(y.trans_time, x.trans_time)
      if result == 0:
        result = cmp(y.change, x.change)
        if result == 0:
          result = cmp(y.index, x.index)
          if result == 0:
            result = cmp(y.xpub_idx, x.xpub_idx)

proc j_uint64*(val: uint64): JsonNode =
  if val > 9007199254740991'u64:
    newJString($val)
  else:
    newJInt(BiggestInt(val))

proc stream_main() {.thread.} =
  let server = newAsyncHttpServer()
  var clients: Table[int, ClientData]
  var walletmap: Table[uint64, seq[WalletMapData]]
  var closedclients: seq[int]
  var pingclients = initTable[int, bool]()
  var clientsLock: Lock
  initLock(clientsLock)

  proc clientDelete(fd: int) =
    withLock clientsLock:
      if not closedclients.contains(fd):
        closedclients.add(fd)
      let client_count = clients.len - closedclients.len
      debug "client count=", client_count

  proc toStr(oa: openarray[byte]): string =
    result = newString(oa.len)
    if oa.len > 0:
      copyMem(addr result[0], unsafeAddr oa[0], result.len)

  proc `xor`(a: array[32, byte], b: array[32, byte]): array[32, byte] =
    for i in a.low..a.high:
      result[i] = a[i] xor b[i]

  proc `xor`(a: array[32, byte], b: ptr array[32, byte]): array[32, byte] =
    for i in a.low..a.high:
      result[i] = a[i] xor b[i]

  proc yespower(a: array[32, byte]): array[32, byte] =
    var b: array[32, byte]
    discard yespower_hash(cast[ptr UncheckedArray[byte]](unsafeAddr a[0]), 32, cast[ptr UncheckedArray[byte]](addr b[0]))
    b

  proc clientKeyExchange(client: ClientData, data: string) =
    var clientPublicKey: PublicKey
    copyMem(addr clientPublicKey[0], unsafeAddr data[0], clientPublicKey.len)
    let shared = keyExchange(clientPublicKey, client.kp.privateKey)
    let shared_sha256 = sha256.digest(shared)
    let shared_key = yespower(shared_sha256.data)
    let seed_srv = cast[ptr array[32, byte]](addr client.salt[0])
    let seed_cli = cast[ptr array[32, byte]](addr client.salt[32])
    let iv_srv_sha256 = sha256.digest(shared_key xor seed_srv)
    let iv_cli_sha256 = sha256.digest(shared_key xor seed_cli)
    let iv_srv = yespower(iv_srv_sha256.data)
    let iv_cli = yespower(iv_cli_sha256.data)
    debug "shared=", shared_key
    debug "iv_srv=", iv_srv
    debug "iv_cli=", iv_cli
    client.ctr.init(shared_key, iv_srv, iv_cli)

  proc sendClient(client: var ClientData, data: string) =
    let comp = compress(data, stream = RAW_DEFLATE)
    var sdata = newSeq[byte](comp.len)
    var pos = 0
    var next_pos = 16
    while next_pos < comp.len:
      client.ctr.encrypt(cast[ptr UncheckedArray[byte]](unsafeAddr comp[pos]),
                        cast[ptr UncheckedArray[byte]](addr sdata[pos]))
      pos = next_pos
      next_pos = next_pos + 16
    if pos < comp.len:
      var src: array[16, byte]
      var enc: array[16, byte]
      var plen = comp.len - pos
      src.fill(cast[byte](plen))
      copyMem(addr src[0], unsafeAddr comp[pos], plen)
      client.ctr.encrypt(cast[ptr UncheckedArray[byte]](addr src[0]),
                        cast[ptr UncheckedArray[byte]](addr enc[0]))
      copyMem(addr sdata[pos], addr enc[0], plen)
    waitFor client.ws.sendBinary(sdata.toStr)

  proc recvdata(fd: int, ws: AsyncWebSocket) {.async.} =
    var exchange = false
    var client = clients[fd]
    while true:
      try:
        let (opcode, data) = await ws.readData()
        debug "opcode=", opcode, " len=", data.len
        case opcode
        of Opcode.Text:
          debug "text: ", data
        of Opcode.Binary:
          if not exchange:
            if not data.len == 32:
              debug "error: invalid data len=", data.len
              break
            clientKeyExchange(client, data)
            exchange = true

          else:
            var rdata = newSeq[byte](data.len)
            var pos = 0
            var next_pos = 16
            while next_pos < data.len:
              client.ctr.decrypt(cast[ptr UncheckedArray[byte]](unsafeAddr data[pos]),
                                cast[ptr UncheckedArray[byte]](addr rdata[pos]))
              pos = next_pos
              next_pos = next_pos + 16
            if pos < data.len:
              var src: array[16, byte]
              var dec: array[16, byte]
              var plen = data.len - pos
              src.fill(cast[byte](plen))
              copyMem(addr src[0], unsafeAddr data[pos], plen)
              client.ctr.decrypt(cast[ptr UncheckedArray[byte]](addr src[0]),
                                cast[ptr UncheckedArray[byte]](addr dec[0]))
              copyMem(addr rdata[pos], addr dec[0], plen)
            let uncomp = uncompress(rdata.toStr, stream = RAW_DEFLATE)
            let json_cmd = parseJson(uncomp)
            debug json_cmd

            # set: xpubs, data
            # get: xpubs
            if json_cmd.hasKey("cmd"):
              let cmd = json_cmd["cmd"].getStr
              if cmd == "xpubs":
                if json_cmd.hasKey("data"):
                  var xpubs = json_cmd["data"]
                  let wmdata = WalletMapData(fd: fd, salt: client.salt)
                  for xpub in xpubs:
                    let xpub_str = xpub.getStr
                    let w = getOrCreateWallet(xpub_str)
                    if client.wallets.find(w.wallet_id) < 0:
                      client.wallets.add(w.wallet_id)
                      client.xpubs.add(xpub_str)
                    withLock clientsLock:
                      if walletmap.hasKeyOrPut(w.wallet_id, @[wmdata]):
                        walletmap[w.wallet_id].add(wmdata)

                var json = %*{"type": "xpubs", "data": client.xpubs}
                BallCommand.AddClient.send(BallDataAddClient(client: client))
                sendClient(client, $json)

              elif cmd == "unused":
                StreamCommand.Unused.send(StreamDataUnused(wallet_id: client.wallets[0]))

              elif cmd == "change":
                BallCommand.Change.send(BallDataChange(wallet_id: client.wallets[0]))

              elif cmd == "unspents":
                BallCommand.Unspents.send(BallDataUnspents(client: client))

              elif cmd == "txlogs":
                var txlogs: TxLogs
                var rev_flag = true
                if json_cmd.hasKey("data"):
                  if json_cmd["data"].hasKey("lt"):
                    var sequence = json_cmd["data"]["lt"].getUint64
                    for i, wid in client.wallets:
                      for l in db.getAddrlogsReverse_lt(wid, sequence):
                        var trans_time: uint64 = 0
                        var txtime = db.getTxtime(l.txid)
                        if txtime.err == DbStatus.Success:
                          trans_time = txtime.res
                        txlogs.add(TxLog(sequence: l.sequence, txtype: l.txtype, address: l.address,
                                        value: l.value, txid: l.txid, height: l.height, time: l.time,
                                        change: l.change, index: l.index, xpub_idx: i, trans_time: trans_time))
                        if txlogs.len >= 50:
                          break
                    txlogs.sort(SequenceRevCmp)
                  elif json_cmd["data"].hasKey("gt"):
                    var sequence = json_cmd["data"]["gt"].getUint64
                    for i, wid in client.wallets:
                      for l in db.getAddrlogs_gt(wid, sequence):
                        var trans_time: uint64 = 0
                        var txtime = db.getTxtime(l.txid)
                        if txtime.err == DbStatus.Success:
                          trans_time = txtime.res
                        txlogs.add(TxLog(sequence: l.sequence, txtype: l.txtype, address: l.address,
                                        value: l.value, txid: l.txid, height: l.height, time: l.time,
                                        change: l.change, index: l.index, xpub_idx: i, trans_time: trans_time))
                        if txlogs.len >= 50:
                          break
                    txlogs.sort(TxLogCmp)
                    rev_flag = false
                else:
                  for i, wid in client.wallets:
                    for l in db.getAddrlogsReverse(wid):
                      var trans_time: uint64 = 0
                      var txtime = db.getTxtime(l.txid)
                      if txtime.err == DbStatus.Success:
                        trans_time = txtime.res
                      txlogs.add(TxLog(sequence: l.sequence, txtype: l.txtype, address: l.address,
                                      value: l.value, txid: l.txid, height: l.height, time: l.time,
                                      change: l.change, index: l.index, xpub_idx: i, trans_time: trans_time))
                      if txlogs.len >= 50:
                        break
                  txlogs.sort(TxLogRevCmp)
                if txlogs.len > 50:
                  txlogs.delete(50, txlogs.high)
                var json = %*{"type": "txlogs", "data": {"txlogs": txlogs, "rev": rev_flag}}
                for j in json["data"]["txlogs"]:
                  j["value"] = j_uint64(j["value"].getUint64)
                  if j["trans_time"].getUint64 == 0:
                    j.delete("trans_time")
                sendClient(client, $json)

              elif cmd == "time":
                var json = %*{"type": "time", "data": j_uint64(cast[uint64](getTime().toUnix))}
                sendClient(client, $json)

              elif cmd == "ready":
                var json = %*{"type": "ready"}
                sendClient(client, $json)

        of Opcode.Pong:
          if fd in pingclients:
            pingclients[fd] = false

        of Opcode.Close:
          let (closeCode, reason) = extractCloseData(data)
          debug "client close code=", closeCode, " reason=", reason
          break

        else: discard
      except:
        let e = getCurrentException()
        debug e.name, ": ", e.msg
        break

    try:
      withLock clientsLock:
        for wid in client.wallets:
          if walletmap.hasKey(wid):
            var wmdatas = walletmap[wid]
            wmdatas.keepIf(proc (x: WalletMapData): bool = x.fd != fd)
            if wmdatas.len > 0:
              walletmap[wid] = wmdatas
            else:
              walletmap.del(wid)
        client.wallets = @[]
        client.xpubs = @[]
      clientDelete(fd)
      waitFor ws.close()
    except:
      debug "close error"
      discard

  proc deleteClosedClient() =
    withLock clientsLock:
      for fd in closedclients:
        let clientdata = clients[fd]
        clients.del(fd)
        BallCommand.DelClient.send(BallDataDelClient(client: clientdata))
      closedclients = @[]

  proc activecheck() {.async.} =
    while true:
      try:
        deleteClosedClient()
        for fd, client in clients:
          debug "fd=", fd
          if fd in pingclients and pingclients[fd]:
            clientDelete(fd)
            waitFor client.ws.close()
        clear(pingclients)
        deleteClosedClient()
        for fd, client in clients:
          debug "fd=", fd
          pingclients.add(fd, true)
          await client.ws.sendPing()
      except:
        let e = getCurrentException()
        debug e.name, ": ", e.msg
      await sleepAsync(10000)
      debug "client count=", clients.len

  proc senddata() {.async.} =
    while true:
      try:
        deleteClosedClient()
        for fd, client in clients:
          debug "fd=", fd
          if not client.ws.sock.isClosed:
            waitFor client.ws.sendText("test")
      except:
        let e = getCurrentException()
        debug e.name, ": ", e.msg
      await sleepAsync(2000)
      debug "client count=", clients.len

  proc sendManager() {.async.} =
    while true:
      while sendMesChannel.peek() > 0:
        let sdata = sendMesChannel.recv()
        debug "sendManager wid=", sdata.wallet_id, " data=", sdata.data
        if walletmap.hasKey(sdata.wallet_id):
          let wmdatas = walletmap[sdata.wallet_id]
          for wmdata in wmdatas:
            if clients.hasKey(wmdata.fd):
              var client = clients[wmdata.fd]
              if not client.ws.sock.isClosed and client.salt == wmdata.salt:
                sendClient(client, sdata.data)
        await sleepAsync(1)
      await sleepAsync(100)

  proc clientStart(ws: AsyncWebSocket) {.async.} =
    let kp = createKeyPair(seed())
    var fd = cast[int](ws.sock.getFd)
    var ctr: ctrmode.CTR
    var salt: array[64, byte]
    salt[0..31] = seed()
    salt[32..63] = seed()
    let clientdata = ClientData(ws: ws, kp: kp, ctr: ctr, salt: salt)
    clients[fd] = clientdata;
    debug "client count=", clients.len
    waitFor ws.sendBinary(kp.publicKey.toStr & salt.toStr)
    asyncCheck recvdata(fd, ws)

  #asyncCheck activecheck()
  #asyncCheck senddata()
  asyncCheck sendManager()

  proc cb(req: Request) {.async, gcsafe.} =
    let (ws, error) = await verifyWebsocketRequest(req, "pastel-v0.1")
    if ws.isNil:
      debug "WS negotiation failed: ", error
      await req.respond(Http400, "Websocket negotiation failed: " & error)
      req.client.close()
      return
    asyncCheck clientStart(ws)

  waitFor server.serve(Port(5001), cb)


var stream_thread: Thread[void]

proc start*(): Thread[void] =
  createThread(stream_thread, stream_main)
  stream_thread
