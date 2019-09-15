import ../deps/"websocket.nim"/websocket, asynchttpserver, asyncnet, asyncdispatch
import nimcrypto, ed25519, sequtils, os, threadpool, tables, locks, strutils, json, algorithm
import ../deps/zip/zip/zlib
import unicode
import ../src/ctrmode

type ClientData* = ref object
  req: Request
  ws: AsyncWebSocket
  kp: KeyPair
  ctr: ctrmode.CTR
  salt: array[64, byte]

proc stream_main() {.thread.} =
  let server = newAsyncHttpServer()
  var channel: Channel[tuple[req: Request, ws: AsyncWebSocket]]

  var clients: Table[int, ClientData]
  var closedclients: seq[int]
  var pingclients = initTable[int, bool]()
  var clientsLock: Lock
  initLock(clientsLock)
  var clientsdirty = false

  proc clientDelete(fd: int) =
    acquire(clientsLock)
    if not closedclients.contains(fd):
      closedclients.add(fd)
    let client_count = clients.len - closedclients.len
    release(clientsLock)
    echo "client count=", client_count

  proc toStr(oa: openarray[byte]): string =
    result = newString(oa.len)
    if oa.len > 0:
      copyMem(addr result[0], unsafeAddr oa[0], result.len)

  proc `xor`(a: array[32, byte], b: array[32, byte]): array[32, byte] =
    for i in a.low..a.high:
      result[i] = a[i] xor b[i]

  proc recvdata(fd: int, ws: AsyncWebSocket) {.async.} =
    var shared_key: MDigest[256]
    var exchange = false
    while true:
      try:
        let (opcode, data) = await ws.readData()
        echo "(opcode: ", opcode, ", data length: ", data.len, ")"
        case opcode
        of Opcode.Text:
          echo data
        of Opcode.Binary:
          if not exchange:
            if not data.len == 32:
              echo "error: client data len=", data.len
              break
            var client = clients[fd]
            var clientPublicKey: PublicKey
            copyMem(addr clientPublicKey[0], unsafeAddr data[0], clientPublicKey.len)
            echo "client publicKey=", clientPublicKey
            let shared = keyExchange(clientPublicKey, client.kp.privateKey)
            echo "shared=", shared
            shared_key = sha256.digest(shared)
            echo "shared key=", shared_key
            echo "shared key=", shared_key.data
            var seed_srv: array[32, byte]
            var seed_cli: array[32, byte]
            copyMem(addr seed_srv[0], addr client.salt[0], 32)
            copyMem(addr seed_cli[0], addr client.salt[32], 32)
            let iv_srv = sha256.digest(shared_key.data xor seed_srv)
            let iv_cli = sha256.digest(shared_key.data xor seed_cli)
            echo "shared_key.data=", shared_key.data
            echo "iv_srv=", iv_srv
            echo "iv_cli=", iv_cli
            client.ctr.init(shared_key.data, iv_srv.data, iv_cli.data)
            exchange = true

          else:
            var client = clients[fd] # key not found
            echo "data=", data.toHex
            var rdata = newSeq[byte](data.len)
            var pos = 0
            var next_pos = 16
            var dec: array[16, byte]
            while next_pos < data.len:
              client.ctr.decrypt(cast[ptr UncheckedArray[byte]](unsafeAddr data[pos]),
                                cast[ptr UncheckedArray[byte]](addr dec[0]));
              copyMem(addr rdata[pos], addr dec[0], 16)
              pos = next_pos;
              next_pos = next_pos + 16;
            if pos < data.len:
              var src: array[16, byte]
              var plen = data.len - pos
              src.fill(cast[byte](plen))
              copyMem(addr src[0], unsafeAddr data[pos], plen)
              client.ctr.decrypt(cast[ptr UncheckedArray[byte]](addr src[0]),
                                cast[ptr UncheckedArray[byte]](addr dec[0]));
              copyMem(addr rdata[pos], addr dec[0], plen)
            let uncomp = uncompress(rdata.toStr, stream = RAW_DEFLATE)
            echo "uncomp=", uncomp
            echo runeLen(uncomp)
            echo uncomp.toRunes
            let json = parseJson(uncomp)
            echo json

            block test:
              var json = %*{"test": "日本語", "test1": 1234, "test2": 5678901234,
                          "test3": 1234, "test4": 123, "test5": 123, "test6": 123}
              echo "json=", $json
              let comp = compress($json, stream = RAW_DEFLATE)
              echo cast[seq[byte]](comp.toSeq), ' ', comp.len
              var sdata = newSeq[byte](comp.len)
              var pos = 0
              var next_pos = 16
              var enc: array[16, byte]
              while next_pos < comp.len:
                client.ctr.encrypt(cast[ptr UncheckedArray[byte]](unsafeAddr comp[pos]),
                                  cast[ptr UncheckedArray[byte]](addr enc[0]));
                copyMem(addr sdata[pos], addr enc[0], 16)
                pos = next_pos;
                next_pos = next_pos + 16;
              if pos < comp.len:
                var src: array[16, byte]
                var plen = comp.len - pos
                src.fill(cast[byte](plen))
                copyMem(addr src[0], unsafeAddr comp[pos], plen)
                client.ctr.encrypt(cast[ptr UncheckedArray[byte]](addr src[0]),
                                  cast[ptr UncheckedArray[byte]](addr enc[0]));
                copyMem(addr sdata[pos], addr enc[0], plen)
              echo sdata, " ", sdata.len
              asyncCheck client.ws.sendBinary(sdata.toStr)

        of Opcode.Pong:
          if fd in pingclients:
            pingclients[fd] = false
            echo "pong fd=", fd

        of Opcode.Close:
          echo "del=", fd
          let (closeCode, reason) = extractCloseData(data)
          echo "socket went away, close code: ", closeCode, ", reason: ", reason
          break

        else: discard
      except:
        clientsdirty = true
        let e = getCurrentException()
        echo e.name, ": ", e.msg
        break

    try:
      clientDelete(fd)
      waitFor ws.close()
    except:
      echo "close error"
      discard

  proc deleteClosedClient() =
    acquire(clientsLock)
    for fd in closedclients:
      clients.del(fd)
    closedclients = @[]
    release(clientsLock)

  proc activecheck() {.async.} =
    while true:
      try:
        deleteClosedClient()
        for fd, client in clients:
          echo "fd=", fd
          if fd in pingclients and pingclients[fd]:
            clientDelete(fd)
            waitFor client.ws.close()
        clear(pingclients)
        deleteClosedClient()
        for fd, client in clients:
          echo "fd=", fd
          pingclients.add(fd, true)
          await client.ws.sendPing()
      except:
        let e = getCurrentException()
        echo e.name, ": ", e.msg
      await sleepAsync(10000)
      echo "clients.len=", clients.len


  proc senddata() {.async.} =
    while true:
      try:
        deleteClosedClient()
        for fd, client in clients:
          echo "fd=", fd
          if not client.req.client.isClosed:
            asyncCheck client.ws.sendText("test")
      except:
        let e = getCurrentException()
        echo e.name, ": ", e.msg
      await sleepAsync(2000)
      echo "clients.len=", clients.len

  proc clientManager() {.async.} =
   while true:
    if channel.peek() > 0:
      var ch = channel.recv()
      let kp = createKeyPair(seed())
      var fd = cast[int](ch.req.client.getFd)
      var ctr: ctrmode.CTR
      var salt: array[64, byte]
      salt[0..31] = seed()
      salt[32..63] = seed()
      echo "salt=", salt
      clients[fd] = ClientData(req: ch.req, ws: ch.ws, kp: kp, ctr: ctr, salt: salt)
      echo "client count=", clients.len
      echo "server publicKey=", kp.publicKey
      asyncCheck ch.ws.sendBinary(kp.publicKey.toStr & salt.toStr)
      asyncCheck recvdata(fd, ch.ws)
    else:
      await sleepAsync(500)

  channel.open()
  asyncCheck clientManager()
  asyncCheck activecheck()
  asyncCheck senddata()

  proc cb(req: Request) {.async, gcsafe.} =
    let (ws, error) = await verifyWebsocketRequest(req, "pastel-v0.1")
    if ws.isNil:
      echo "WS negotiation failed: ", error
      await req.respond(Http400, "Websocket negotiation failed: " & error)
      req.client.close()
      return
    channel.send((req, ws))

  waitFor server.serve(Port(5001), cb)


var stream_thread: Thread[void]

proc start*(): Thread[void] =
  createThread(stream_thread, stream_main)
  stream_thread
