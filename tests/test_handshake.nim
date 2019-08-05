import ../deps/"websocket.nim"/websocket, asynchttpserver, asyncnet, asyncdispatch
import nimcrypto, ed25519, sequtils, os, threadpool, tables, locks
import ../deps/zip/zip/zlib
import unicode
import unittest

let server = newAsyncHttpServer()
var channel: Channel[tuple[req: Request, ws: AsyncWebSocket]]
var clients: Table[int, tuple[req: Request, ws: AsyncWebSocket, kp: KeyPair]]
var closedclients: seq[int]
var clientsLock: Lock
initLock(clientsLock)
var clientsdirty = false
var shared_key: MDigest[256]

proc clientDelete(fd: int) =
  acquire(clientsLock)
  closedclients.add(fd)
  let client_count = clients.len - closedclients.len
  release(clientsLock)
  echo "client count=", client_count

proc toString(oa: openarray[byte]): string =
  result = newString(oa.len)
  if oa.len > 0:
    copyMem(addr result[0], unsafeAddr oa[0], result.len)

proc recvdata(fd: int, ws: AsyncWebSocket) {.async.} =
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
            clientDelete(fd)
            waitFor ws.close()
            return
          var client = clients[fd]
          var clientPublicKey: PublicKey
          copyMem(addr clientPublicKey[0], unsafeAddr data[0], clientPublicKey.len)
          echo "client publicKey=", clientPublicKey
          let shared = keyExchange(clientPublicKey, client.kp.privateKey)
          echo "shared=", shared
          let shared_hash = sha256.digest(shared)
          echo "shared hash=", shared_hash
          echo "shared hash=", shared_hash.data
          shared_key = shared_hash
          exchange = true
        else:
          echo shared_key
          let uncomp = uncompress(data, stream=RAW_DEFLATE)
          echo uncomp
          echo runeLen(uncomp)
          echo uncomp.toRunes
          echo uncomp.toSeq
      of Opcode.Close:
        echo "del=", fd
        clientDelete(fd)
        waitFor ws.close()
        let (closeCode, reason) = extractCloseData(data)
        echo "socket went away, close code: ", closeCode, ", reason: ", reason
        return
      else: discard
    except:
      clientsdirty = true
      let e = getCurrentException()
      echo e.name, ": ", e.msg
      return

proc deleteClosedClient() =
  acquire(clientsLock)
  for fd in closedclients:
    clients.del(fd)
  closedclients = @[]
  release(clientsLock)

proc senddata() {.async.} =
  while true:
    try:
      for fd, client in clients:
        asyncCheck client.ws.sendBinary("test")
    except:
      let e = getCurrentException()
      echo e.name, ": ", e.msg
    await sleepAsync(2000)
    deleteClosedClient()

proc clientManager() {.async.} =
 while true:
  if channel.peek() > 0:
    var ch = channel.recv()
    let kp = createKeyPair(seed())
    var fd = cast[int](ch.req.client.getFd);
    clients[fd] = (ch.req, ch.ws, kp)
    echo "client count=", clients.len
    echo "server publicKey=", kp.publicKey
    asyncCheck ch.ws.sendBinary(kp.publicKey.toString())
    asyncCheck recvdata(fd, ch.ws)
    asyncCheck senddata()
  else:
    await sleepAsync(500)

channel.open()
asyncCheck clientManager()

proc cb(req: Request) {.async, gcsafe.} =
  let (ws, error) = await verifyWebsocketRequest(req, "pastel-v0.1")
  if ws.isNil:
    echo "WS negotiation failed: ", error
    await req.respond(Http400, "Websocket negotiation failed: " & error)
    req.client.close()
    return
  channel.send((req, ws))

waitFor server.serve(Port(5001), cb)
