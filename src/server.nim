# Copyright (c) 2019 zenywallet

import std/json
import std/algorithm
import std/locks
import std/sequtils
import std/times
#import std/tables
import caprese
import caprese/bearssl/hash
import caprese/server_types
import caprese/hashtable
import templates/layout_base
import ctrmode
import ed25519
import yespower
import ../deps/zip/zip/zlib
import logs as patelog except debug
import db
import blockstor except send

config:
  sigTermQuit = false

type Page* {.pure.} = enum
  Release
  Maintenance
  Debug

var page*: Page = Page.Release

type
  WalletId* = uint64
  WalletIds* = seq[WalletId]
  WalletXpub* = string
  WalletXPubs* = seq[WalletXpub]

type
  ClientExt {.clientExt.} = object
    kp: tuple[pubkey: Ed25519PublicKey, prvkey: Ed25519PrivateKey]
    ctr: ctrmode.CTR
    salt: array[64, byte]
    exchange: bool
    wallets*: WalletIds
    xpubs*: WalletXPubs

  ClientData* = ClientId

type WalletMapData = ref object
  clientId: ClientId
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
  Balance
  Addresses
  Unused
  RawTx

type
  StreamData* = ref object of RootObj
  StreamDataBalance* = ref object of StreamData
    wallets*: WalletIds
  StreamDataAddresses* = ref object of StreamData
    wallets*: WalletIds
  StreamDataUnused* = ref object of StreamData
    wallet_id*: WalletId
  StreamDataRawTx* = ref object of StreamData
    wallet_id*: WalletId
    rawtx*: string

type
  StreamCriticalErr* = object of CatchableError

var sendMesChannel = queue.newQueue[tuple[wallet_id: uint64, data: string]](0x10000)

proc send*(wallet_id: uint64, data: string) =
  if not sendMesChannel.send((wallet_id, data)):
    Debug.StreamError.write "error: sendMesChannel is full"

var cmdChannel* = queue.newQueue[tuple[cmd: StreamCommand, data: StreamData]](0x10000)

proc send*(cmd: StreamCommand, data: StreamData = nil) =
  if not cmdChannel.send((cmd, data)):
    Debug.StreamError.write "error: cmdChannel is full"

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
    UpdateWallets

  BallData* = ref object of RootObj
  BallDataAddClient* = ref object of BallData
    client*: ClientData
  BallDataDelClient* = ref object of BallData
    client*: ClientData
  BallDataMemPool* = ref object of BallData
    client*: ClientData
  BallDataUnspents* = ref object of BallData
    wallets*: WalletIds
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
  BallDataUpdateWalletsStatus* {.pure.} = enum
    Continue
    Done
  BallDataUpdateWallets* = ref object of BallData
    wallets*: WalletIds
    status*: BallDataUpdateWalletsStatus

var ballChannel* = queue.newQueue[tuple[cmd: BallCommand, data: BallData]](0x10000)

proc send*(cmd: BallCommand, data: BallData = nil) =
  if not ballChannel.send((cmd, data)):
    Debug.StreamError.write "error: ballChannel is full"

type
  TxLog = ref object
    sequence: uint64
    txtype: uint8
    address: string
    value: uint64
    txid: string
    height: uint32
    time: uint32
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
    result = cmp(x.trans_time, y.trans_time)
    if result == 0:
      result = cmp(x.txtype, y.txtype)
      if result == 0:
        result = cmp(x.sequence, y.sequence)

proc TxLogRevCmp[T](x, y: T): int =
  result = cmp(y.height, x.height)
  if result == 0:
    result = cmp(y.trans_time, x.trans_time)
    if result == 0:
      result = cmp(y.txtype, x.txtype)
      if result == 0:
        result = cmp(y.sequence, x.sequence)

type
  TxSequenceType = uint64

proc combineSequenceType(sequence: uint64, txtype: uint8): TxSequenceType =
  result = (sequence shl 8) or txtype

proc separateSequenceType(sectype: TxSequenceType): tuple[sequence: uint64, txtype: uint8] =
  var txtype = cast[uint8](sectype and 0xff)
  var sequence = sectype shr 8
  (sequence, txtype)

proc j_uint64*(val: uint64): JsonNode =
  if val > 9007199254740991'u64:
    newJString($val)
  else:
    newJInt(BiggestInt(val))

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

var workerClientsLock: Lock
initLock(workerClientsLock)

proc empty*(pair: HashTableData): bool =
  when pair.val is Array or pair.val is seq[WalletMapData]:
    pair.val.len == 0
  else:
    pair.val == nil
proc setEmpty*(pair: HashTableData) =
  when pair.val is Array:
    pair.val.empty()
  elif pair.val is seq[WalletMapData]:
    pair.val = @[]
  else:
    pair.val = nil
loadHashTableModules()
var walletmap = newHashTable[WalletId, seq[WalletMapData]](0x10000)

worker(1):
  proc sendClient(clientId: ClientId, data: string) =
    let client = getClient(clientId)
    if not client.isNil:
      let comp = compress(data, stream = RAW_DEFLATE)
      var sdata = newSeq[byte](comp.len)
      var pos = 0
      var next_pos = 16
      while next_pos < comp.len:
        client.ctr.encrypt(cast[ptr UncheckedArray[byte]](addr comp[pos]),
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
        clientId.wsSend(sdata)
    else:
      echo "ClientId=", clientId, " is Nil"

  wsReqs.recvLoop(req):
    try:
      let clientId = req.cid
      let client = getClient(clientId)
      if client.isNil: continue

      let json_cmd = parseJson(req.data.msg)
      echo json_cmd

      # set: xpubs, data
      # get: xpubs
      if json_cmd.hasKey("cmd"):
        let cmd = json_cmd["cmd"].getStr
        if cmd == "xpubs":
          if json_cmd.hasKey("data"):
            var xpubs = json_cmd["data"]
            let wmdata = WalletMapData(clientId: clientId, salt: client.salt)
            for xpub in xpubs:
              let xpub_str = xpub.getStr
              let w = getOrCreateWallet(xpub_str)
              if client.wallets.find(w.wallet_id) < 0:
                client.wallets.add(w.wallet_id)
                client.xpubs.add(xpub_str)
              withLock workerClientsLock:
                var hdata = walletmap.get(w.wallet_id)
                if hdata.isNil:
                  walletmap.set(w.wallet_id, @[wmdata])
                else:
                  hdata.val.add(wmdata)

          var json = %*{"type": "xpubs", "data": client.xpubs}
          BallCommand.AddClient.send(BallDataAddClient(client: clientId))
          sendClient(clientId, $json)
          Debug.Connection.write "connect clientId=", clientId, " wid=", client.wallets

        elif cmd == "unused":
          StreamCommand.Unused.send(StreamDataUnused(wallet_id: client.wallets[0]))

        elif cmd == "change":
          BallCommand.Change.send(BallDataChange(wallet_id: client.wallets[0]))

        elif cmd == "unspents":
          BallCommand.Unspents.send(BallDataUnspents(wallets: client.wallets))

        elif cmd == "rawtx":
          var rawtx = "";
          if json_cmd.hasKey("data"):
            rawtx = json_cmd["data"].getStr
          StreamCommand.RawTx.send(StreamDataRawTx(wallet_id: client.wallets[0], rawtx: rawtx))

        elif cmd == "txlogs":
          var txlogs: TxLogs
          var txIns = initTable[string, uint64]()
          var txInsInfo = initTable[string, tuple[sequence: uint64, height: uint32, time: uint32]]()
          var rev_flag = true
          if json_cmd.hasKey("data"):
            if json_cmd["data"].hasKey("lt"):
              var sequence = json_cmd["data"]["lt"].getUint64
              var countTx = initTable[TxSequenceType, int]()
              for i, wid in client.wallets:
                for l in db.getAddrlogsReverse_lt(wid, sequence):
                  if l.txtype == 1 and l.change == 0:
                    var trans_time: uint64 = 0
                    var txtime = db.getTxtime(l.txid)
                    if txtime.err == DbStatus.Success:
                      trans_time = txtime.res
                    txlogs.add(TxLog(sequence: l.sequence, txtype: l.txtype, address: l.address,
                                    value: l.value, txid: l.txid, height: l.height, time: l.time,
                                    trans_time: trans_time))
                    countTx[combineSequenceType(l.sequence, l.txtype)] = 1
                  elif l.txtype == 0:
                    txIns[l.txid] = txIns.getOrDefault(l.txid) + l.value
                    txInsInfo[l.txid] = (sequence: l.sequence, height: l.height, time: l.time)
                    countTx[combineSequenceType(l.sequence, l.txtype)] = 1
                if countTx.len >= 200:
                  break
            elif json_cmd["data"].hasKey("gt"):
              var sequence = json_cmd["data"]["gt"].getUint64
              var countTx = initTable[TxSequenceType, int]()
              for i, wid in client.wallets:
                for l in db.getAddrlogs_gt(wid, sequence):
                  if l.txtype == 1 and l.change == 0:
                    var trans_time: uint64 = 0
                    var txtime = db.getTxtime(l.txid)
                    if txtime.err == DbStatus.Success:
                      trans_time = txtime.res
                    txlogs.add(TxLog(sequence: l.sequence, txtype: l.txtype, address: l.address,
                                    value: l.value, txid: l.txid, height: l.height, time: l.time,
                                    trans_time: trans_time))
                    countTx[combineSequenceType(l.sequence, l.txtype)] = 1
                  elif l.txtype == 0:
                    txIns[l.txid] = txIns.getOrDefault(l.txid) + l.value
                    txInsInfo[l.txid] = (sequence: l.sequence, height: l.height, time: l.time)
                    countTx[combineSequenceType(l.sequence, l.txtype)] = 1
                if countTx.len >= 200:
                  break
              rev_flag = false
          else:
            for i, wid in client.wallets:
              var countTx = initTable[TxSequenceType, int]()
              for l in db.getAddrlogsReverse(wid):
                if l.txtype == 1 and l.change == 0:
                  var trans_time: uint64 = 0
                  var txtime = db.getTxtime(l.txid)
                  if txtime.err == DbStatus.Success:
                    trans_time = txtime.res
                  txlogs.add(TxLog(sequence: l.sequence, txtype: l.txtype, address: l.address,
                                  value: l.value, txid: l.txid, height: l.height, time: l.time,
                                  trans_time: trans_time))
                  countTx[combineSequenceType(l.sequence, l.txtype)] = 1
                elif l.txtype == 0:
                  txIns[l.txid] = txIns.getOrDefault(l.txid) + l.value
                  txInsInfo[l.txid] = (sequence: l.sequence, height: l.height, time: l.time)
                  countTx[combineSequenceType(l.sequence, l.txtype)] = 1
              if countTx.len >= 200:
                break
          var txids: seq[string] = @[]
          for txid in txIns.keys:
            txids.add(txid)
          var txouts = blockstor.getTxout(txids)
          if txouts.hasKey("res"):
            var txouts_res = txouts["res"]
            var idx: int = 0
            for txid, value in txIns:
              var txout = txouts_res[idx]
              inc(idx)
              var change_value: uint64 = 0'u64
              var out_value: uint64 = 0'u64
              var addrs_array: seq[string]
              for t_array in txout:
                var cur_value = t_array["value"].getUint64
                var find = false
                for a in t_array["addresses"]:
                  var a_str = a.getStr
                  for ainfo in db.getAddresses(a_str):
                    if client.wallets.contains(ainfo.wid) and ainfo.change == 1:
                      find = true
                  if find:
                    change_value += cur_value
                  else:
                    addrs_array.add(a_str)
                  break
                out_value += cur_value
              var send_value: uint64
              var fee: uint64 = value - out_value
              if change_value > 0'u64:
                send_value = value - change_value - fee
              else:
                send_value = value - fee
              if addrs_array.len > 0:
                var trans_time: uint64 = 0
                var txtime = db.getTxtime(txid)
                if txtime.err == DbStatus.Success:
                  trans_time = txtime.res
                var info = txInsInfo[txid]
                txlogs.add(TxLog(sequence: info.sequence, txtype: 0, address: addrs_array[0],
                                value: send_value, txid: txid, height: info.height,
                                time: info.time, trans_time: trans_time))
          if rev_flag:
            txlogs.sort(TxLogRevCmp)
          else:
            txlogs.sort(TxLogCmp)
          if txlogs.len > 200:
            txlogs.delete(200..txlogs.high)
          var json = %*{"type": "txlogs", "data": {"txlogs": txlogs, "rev": rev_flag}}
          for j in json["data"]["txlogs"]:
            j["value"] = j_uint64(j["value"].getUint64)
            if j["trans_time"].getUint64 == 0:
              j.delete("trans_time")
          sendClient(clientId, $json)

        elif cmd == "time":
          var json = %*{"type": "time", "data": j_uint64(cast[uint64](getTime().toUnix))}
          sendClient(clientId, $json)

        elif cmd == "ready":
          var json = %*{"type": "ready"}
          sendClient(clientId, $json)

    except:
      let e = getCurrentException()
      echo e.name, ": ", e.msg

worker(1):
  proc sendClient(clientId: ClientId, data: string) =
    let client = getClient(clientId)
    if not client.isNil:
      let comp = compress(data, stream = RAW_DEFLATE)
      var sdata = newSeq[byte](comp.len)
      var pos = 0
      var next_pos = 16
      while next_pos < comp.len:
        client.ctr.encrypt(cast[ptr UncheckedArray[byte]](addr comp[pos]),
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
        clientId.wsSend(sdata)
    else:
      echo "ClientId=", clientId, " is Nil"

  while active:
    while sendMesChannel.count > 0:
      let sdata = sendMesChannel.recv()
      Debug.Stream.write "sendManager wid=", sdata.wallet_id, " data=", sdata.data
      var wmdatas = walletmap.get(sdata.wallet_id)
      if not wmdatas.isNil:
        for wmdata in wmdatas.val:
          wmdata.clientId.sendClient(sdata.data)
      sleep(1)
    sleep(100)

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
        client.wallets = @[]
        client.xpubs = @[]

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
