# Copyright (c) 2022 zenywallet

import std/nativesockets
import std/posix
import std/os
when defined(linux):
  import std/epoll
else:
  {.error: "Not yet implemented on platforms other than Linux".}
import std/strutils
import std/options
import std/macros
import std/locks
import std/base64
import checksums/sha1
import zenyjs
import zenyjs/core
import zenyjs/seed
import cmp
import events

const ENABLE_KEEPALIVE = false
const ENABLE_TCP_NODELAY = true
const WSCLIENT_EVENTS_SIZE = 10
const RECONNECT_WAIT = 3000

type
  AppId = enum
    AppNone
    AppConnect
    AppReconnect
    AppUpgrade
    AppSend
    AppRecv
    AppClose

  WsClientObj* = object
    sock*: SocketHandle
    sockUpperReserved: cint
    appId*: AppId
    appNextId*: AppId
    sendBuf*: ptr UncheckedArray[byte]
    sendBufSize*: int
    sendDataSize*: int
    aiList*: ptr AddrInfo
    lock*: Lock
    connectId*: int
    recvEvent: Event
    recvData: Array[byte]
    path: Array[byte]
    protocol: Array[byte]
    base64Key: Array[byte]
    sockClose: SocketHandle
    onOpen: proc(client: WsClient) {.gcsafe.}
    onReady: proc(client: WsClient) {.gcsafe.}
    onMessage: proc(client: WsClient, data: ptr UncheckedArray[byte], size: int) {.gcsafe.}
    onClose: proc(client: WsClient) {.gcsafe.}
    onError: proc(client: WsClient) {.gcsafe.}

  WsClient* = ptr WsClientObj

  WsClientError* = object of CatchableError

  WebSocketOpCode* = enum
    Continue = 0x0
    Text = 0x1
    Binary = 0x2
    Close = 0x8
    Ping = 0x9
    Pong = 0xa

template debugBlock(body: untyped) =
  when defined(DEBUG_LOG):
    body

template debug(x: varargs[string, `$`]) =
  debugBlock:
    echo join(x)

template error(x: varargs[string, `$`]) = echo join(x)

template errorException(x: varargs[string, `$`]) =
  var msg = join(x)
  echo msg
  raise newException(WsClientError, msg)

template ev(epollEvents: int, wsClient: WsClient): ptr EpollEvent =
  var ev = EpollEvent(events: epollEvents, data: EpollData(u64: cast[uint64](wsClient)))
  addr ev

proc newSocket(wsClient: WsClient) =
  if wsClient.aiList.isNil:
    wsClient.sock = createNativeSocket()
  else:
    let domain = wsClient.aiList.ai_family.toKnownDomain.get
    wsClient.sock = createNativeSocket(domain)
  if wsClient.sock == osInvalidSocket: raise
  when ENABLE_KEEPALIVE:
    wsClient.sock.setSockOptInt(SOL_SOCKET, SO_KEEPALIVE, 1)
  when ENABLE_TCP_NODELAY:
    wsClient.sock.setSockOptInt(Protocol.IPPROTO_TCP.int, TCP_NODELAY, 1)
  wsClient.sock.setSockOptInt(SOL_SOCKET, SO_REUSEADDR, 1) # local only
  # bind
  wsClient.sock.setBlocking(false)

proc newWsClient*(): WsClient =
  var p = cast[WsClient](allocShared0(sizeof(WsClientObj)))
  initLock(p.lock)
  p.recvEvent = createEvent()
  p.newSocket()
  result = p

proc set*(wsClient: WsClient, hostname: string, port: Port, protocol: string = "") =
  try:
    wsClient.aiList = getAddrInfo(hostname, port, Domain.AF_UNSPEC)
  except:
    errorException "error: getaddrinfo hostname=", hostname, " port=", port, " errno=", errno
  wsClient.protocol = protocol.toBytes

proc newWsClient*(hostname: string, port: Port, protocol: string = ""): WsClient =
  var p = newWsClient()
  p.set(hostname, port, protocol)
  result = p

signal(SIGPIPE, SIG_IGN)

var evfd: cint = epoll_create1(O_CLOEXEC)
var abortClient = newWsClient()
abortClient.appId = AppNone
var recvBufSize*: int = abortClient.sock.getSockOptInt(SOL_SOCKET, SO_RCVBUF)
const ReservedRecvPad = 15

proc abort*() =
  var ret = epoll_ctl(evfd, EPOLL_CTL_ADD, abortClient.sock.cint, ev(EPOLLIN, abortClient))
  if ret < 0:
    errorException "error: EPOLL_CTL_MOD ret=", ret, " errno=", errno

proc evIn(client: WsClient) =
  var ret = epoll_ctl(evfd, EPOLL_CTL_MOD, client.sock.cint, ev(EPOLLIN or EPOLLRDHUP or EPOLLET, client))
  if ret < 0:
    errorException "error: EPOLL_CTL_MOD ret=", ret, " errno=", errno

proc evOut(client: WsClient) =
  var ret = epoll_ctl(evfd, EPOLL_CTL_MOD, client.sock.cint, ev(EPOLLRDHUP or EPOLLET or EPOLLOUT, client))
  if ret < 0:
    errorException "error: EPOLL_CTL_MOD ret=", ret, " errno=", errno

proc evOutAdd(client: WsClient) =
  var ret = epoll_ctl(evfd, EPOLL_CTL_ADD, client.sock.cint, ev(EPOLLOUT or EPOLLERR, client))
  if ret < 0:
    errorException "error: EPOLL_CTL_ADD ret=", ret, " errno=", errno

proc evDel(client: WsClient) =
  var ret = epoll_ctl(evfd, EPOLL_CTL_DEL, client.sock.cint, nil)
  if ret != 0:
    errorException "error: epoll_ctl EPOLL_CTL_DEL ret=", ret, " errno=", errno

proc atomic_compare_exchange_n(p: ptr int, expected: ptr int, desired: int, weak: bool,
                              success_memmodel: int, failure_memmodel: int): bool
                              {.importc: "__atomic_compare_exchange_n", nodecl, discardable.}

proc close*(client: WsClient) =
  var sockInt = cast[ptr int](addr client.sock)[] # sock + sockUpperReserved(-1) = 8 bytes
  if client.sock != osInvalidSocket and
    atomic_compare_exchange_n(cast[ptr int](addr client.sock),
                              cast[ptr int](addr sockInt),
                              osInvalidSocket.int, false, 0, 0):
    client.sockClose = cast[cint](sockInt).SocketHandle # cast lower only
    client.appId = AppId.AppClose
    var retShutdown = client.sockClose.shutdown(SHUT_RD)
    if retShutdown != 0:
      errorException "error: shutdown ret=", retShutdown, " errno=", errno

template reallocClientBuf(buf: ptr UncheckedArray[byte], size: int): ptr UncheckedArray[byte] =
  cast[ptr UncheckedArray[byte]](reallocShared(buf, size))

proc addSendBuf(client: WsClient, data: string) =
  acquire(client.lock)
  let nextSize = client.sendDataSize + data.len
  if nextSize > client.sendBufSize:
    client.sendBuf = reallocClientBuf(client.sendBuf, nextSize)
    client.sendBufSize = nextSize
  copyMem(addr client.sendBuf[client.sendDataSize], unsafeAddr data[0], data.len)
  client.sendDataSize = nextSize
  release(client.lock)

proc getFrame(data: ptr UncheckedArray[byte],
              size: int): tuple[find: bool, fin: bool, opcode: int8,
                                payload: ptr UncheckedArray[byte], payloadSize: int,
                                next: ptr UncheckedArray[byte], size: int] =
  if size < 2:
    return (false, false, -1.int8, nil, 0, data, size)

  var b1 = data[1]
  var mask = ((b1 and 0x80.byte) != 0)
  if mask:
    raise newException(WsClientError, "websocket server mask")
  var b0 = data[0]
  var fin = ((b0 and 0xf0.byte) == 0x80.byte)
  var opcode = (b0 and 0x0f.byte).int8

  var payloadLen = (b1 and 0x7f.byte).int
  var frameHeadSize {.noInit.}: int
  if payloadLen < 126:
    frameHeadSize = 2
  elif payloadLen == 126:
    if size < 4:
      return (false, fin, opcode, nil, 0, data, size)
    payloadLen = bytes.toUint16BE(data[2]).int
    frameHeadSize = 4
  elif payloadLen == 127:
    if size < 10:
      return (false, fin, opcode, nil, 0, data, size)
    payloadLen = bytes.toUint64BE(data[2]).int # exception may occur. value out of range [RangeDefect]
    frameHeadSize = 10
  else:
    return (false, fin, opcode, nil, 0, data, size)

  let frameSize = frameHeadSize + payloadLen
  if size == frameSize:
    let payload = cast[ptr UncheckedArray[byte]](addr data[frameHeadSize])
    return (true, fin, opcode, payload, payloadLen, nil, 0)
  elif size > frameSize:
    let payload = cast[ptr UncheckedArray[byte]](addr data[frameHeadSize])
    return (true, fin, opcode, payload, payloadLen, cast[ptr UncheckedArray[byte]](addr data[frameSize]), size - frameSize)
  else:
    return (false, fin, opcode, nil, 0, data, size)

proc wsSendData(data: string | Array[byte], opcode: WebSocketOpCode = WebSocketOpCode.Binary): Array[byte] =
  var dataLen = data.len
  var finOp = 0x80.byte or opcode.byte
  var frame = if dataLen < 126:
    bytes.BytesBE (finOp, dataLen.byte, data)
  elif dataLen <= 0xffff:
    bytes.BytesBE (finOp, 126.byte, dataLen.uint16, data)
  else:
    bytes.BytesBE (finOp, 127.byte, dataLen.uint64, data)
  frame

type
  DispacherParams = object

proc dispacher(params: DispacherParams) {.thread.} =
  var events: array[WSCLIENT_EVENTS_SIZE, EpollEvent]
  var nfd: cint
  var nfdCond: bool
  var evIdx: int = 0
  var recvBuf = cast[ptr UncheckedArray[byte]](allocShared0(recvBufSize + ReservedRecvPad))
  var appId: AppId
  var client: WsClient

  block waitLoop:
    while true:
      nfd = epoll_wait(evfd, addr events[0], WSCLIENT_EVENTS_SIZE, -1.cint)
      nfdCond = likely(nfd > 0)
      if nfdCond:
        block evLoop:
          client = cast[WsClient](events[evIdx].data.u64)
          appId = client.appId

          template nextEv() =
            inc(evIdx)
            if evIdx >= nfd:
              evIdx = 0
              break evLoop
            client = cast[WsClient](events[evIdx].data.u64)
            appId = cast[WsClient](events[evIdx].data.u64).appId

          template reconnect() =
            client.evDel()
            client.appId = AppId.AppReconnect
            client.onClose(client)
            var oldSock = client.sock.cint
            var retClose = oldSock.close()
            if retClose != 0:
              error "error: close ret=", retClose, " errno=", errno

          while true:
            {.computedGoto.}
            case client.appId
            of AppNone:
              client.evDel()
              break waitLoop

            of AppConnect:
              if events[evIdx].events == EPOLLOUT:
                var key: array[16, byte]
                var retSeed = cryptSeed(cast[ptr UncheckedArray[byte]](addr key), sizeof(key).cint)
                if retSeed != 0:
                  errorException "error: crypt seed ret=", retSeed, " errno=", errno
                client.base64Key = base64.encode(key).toBytes
                var data = "GET " & (if client.path.len > 0: client.path.toString() else: "/") & " HTTP/1.1\c\L" &
                  "Host: localhost\c\L" &
                  "Upgrade: websocket\c\L" &
                  "Connection: Upgrade\c\L" &
                  "Sec-WebSocket-Key: " & client.base64Key.toString() & "\c\L" &
                  (if client.protocol.len > 0: "Sec-WebSocket-Protocol: " & client.protocol.toString() & "\c\L" else: "") &
                  "Sec-WebSocket-Version: 13\c\L\c\L"

                client.addSendBuf(data)
                client.appNextId = AppId.AppUpgrade
                client.appId = AppId.AppSend
                client.evOut()
                nextEv()
              else:
                reconnect()
                break

            of AppReconnect:
              proc reconnectThread(client: WsClient) {.thread.} =
                sleep(RECONNECT_WAIT)
                client.newSocket()
                discard client.sock.connect(client.aiList.ai_addr, client.aiList.ai_addrlen.SockLen)
                client.appId = AppId.AppConnect
                client.evOutAdd()
              var thread: Thread[WsClient]
              createThread(thread, reconnectThread, client)
              nextEv()

            of AppSend:
              var pos = 0
              acquire(client.lock)
              if client.sendDataSize > 0:
                while true:
                  let sendRet = client.sock.send(cast[cstring](addr client.sendBuf[pos]), cast[cint](client.sendDataSize), MSG_NOSIGNAL) #, 0'i32)
                  if sendRet == client.sendDataSize:
                    client.sendDataSize = 0
                    client.appId = client.appNextId
                    release(client.lock)
                    client.evIn()
                    nextEv()
                    break

                  elif sendRet < 0:
                    if pos > 0:
                      moveMem(addr client.sendBuf[0], addr client.sendBuf[pos], client.sendDataSize)
                    if errno == EAGAIN or errno == EWOULDBLOCK:
                      release(client.lock)
                      client.evOut()
                      nextEv()
                    elif errno != EINTR:
                      if client.sock == osInvalidSocket:
                        client.appId = AppId.AppClose
                        release(client.lock)
                      else:
                        release(client.lock)
                        reconnect()
                    break
                  elif sendRet == 0:
                    release(client.lock)
                    reconnect()
                    break
                  else:
                    client.sendDataSize = client.sendDataSize - sendRet
                    if client.sendDataSize <= 0:
                      release(client.lock)
                      client.evIn()
                      nextEv()
                      break
                    pos = pos + sendRet
              else:
                release(client.lock)
                nextEv()

            of AppUpgrade:
              client.onOpen(client)

              template acceptKey(key: string): string =
                var sh = sha1.secureHash(key & "258EAFA5-E914-47DA-95CA-C5AB0DC85B11")
                base64.encode(sh.Sha1Digest)

              block upgradeBlock:
                while true:
                  let recvRet = client.sock.recv(addr recvBuf[0], recvBufSize, 0)
                  if recvRet > 0:
                    block findAccept:
                      for i in 0..<recvBufSize - 24:
                        if cmpString(addr recvBuf[i], "\c\LSec-WebSocket-Accept: "):
                          for j in i + 24..<recvBufSize - 2:
                            if cmpString(addr recvBuf[j], "\c\L"):
                              let serverAccept = cast[ptr UncheckedArray[byte]](addr recvBuf[i + 24]).toString(j - (i + 24))
                              if serverAccept == acceptKey(client.base64Key.toString()):
                                break findAccept
                              break
                          break
                      reconnect()
                      break upgradeBlock

                    client.appId = AppId.AppRecv
                    client.onReady(client)
                    nextEv()
                    break
                  elif recvRet == 0:
                    reconnect()
                    break
                  else:
                    if errno == EAGAIN or errno == EWOULDBLOCK:
                      nextEv()
                      break
                    elif errno != EINTR:
                      if client.sock == osInvalidSocket:
                        client.appId = AppId.AppClose
                      else:
                        reconnect()
                      break

            of AppRecv:
              while true:
                let recvRet = client.sock.recv(addr recvBuf[0], recvBufSize, 0)
                if recvRet > 0:
                  client.recvData.add(cast[ptr UncheckedArray[byte]](addr recvBuf[0]).toBytes(recvRet))
                  var (find, fin, opcode, payload, payloadSize, next, size) = getFrame(addr recvBuf[0], recvRet)
                  if fin:
                    if opcode == WebSocketOpCode.Ping.int:
                      client.addSendBuf(wsSendData(payload.toBytes(payloadSize), WebSocketOpCode.Pong).toString())
                      client.recvData.clear()
                      client.appNextId = AppId.AppRecv
                      client.appId = AppId.AppSend
                      client.evOut()
                    else:
                      client.onMessage(client, payload, payloadSize)
                      client.recvData.clear()
                    nextEv()
                    break
                elif recvRet == 0:
                  reconnect()
                  break
                else:
                  if errno == EAGAIN or errno == EWOULDBLOCK:
                    nextEv()
                    appId = cast[WsClient](events[evIdx].data.u64).appId
                  elif errno != EINTR:
                    if client.sock == osInvalidSocket:
                      client.appId = AppId.AppClose
                    else:
                      reconnect()
                    break

            of AppClose:
              var retClose = client.sockClose.cint.close()
              if retClose != 0: raise
              client.sendDataSize = 0
              deallocShared(client.sendBuf)
              client.sendBuf = nil
              `=destroy`(client.recvData)
              `=destroy`(client.base64Key)
              freeaddrinfo(client.aiList)
              #closeEvent(client.recvEvent)
              #deinitLock(client.lock)
              #deallocShared(client)
              nextEv()

      elif errno != EINTR:
        errorException "error: epoll_wait ret=", nfd, " errno=", errno
        break

  deallocShared(recvBuf)


var thread: Thread[DispacherParams]
var params: DispacherParams
proc connectManager*(wait: bool = true): var Thread[DispacherParams] {.discardable.} =
  createThread(thread, dispacher, params)
  if wait:
    joinThread(thread)
  thread

proc waitConnectManager*() = joinThread(thread)

var curClientId {.compileTime.}: int = 0
#{.define: AutoConnectManager.}
when defined(AutoConnectManager):
  let wsConnect {.importc: "WSCONNECT", nodecl.}: cint
  var connectManagerExist* {.compileTime.}: bool = false

macro connect*(wsClient: WsClient, url, protocol: string, body: untyped) =
  inc(curClientId)
  var id = curClientId
  var onOpen = newStmtList()
  var onReady = newStmtList()
  var onMessage = newStmtList()
  var onClose = newStmtList()
  var onError = newStmtList()
  for b in body:
    if b[0].eqIdent("onOpen"):
      onOpen.add(b[1])
    elif b[0].eqIdent("onReady"):
      onReady.add(b[1])
    elif b[0].eqIdent("onMessage") or b[0].eqIdent("onRecv"):
      onMessage.add(b[1])
    elif b[0].eqIdent("onClose"):
      onClose.add(b[1])
    elif b[0].eqIdent("onError"):
      onError.add(b[1])

  var client = ident"client"
  var content = ident"content"
  var data = ident"data"
  var size = ident"size"
  quote do:
    when defined(AutoConnectManager):
      when not declared(findConnectManagerMacro):
        macro findConnectManagerMacro() =
          const info = instantiationInfo(fullPaths = true)
          const src = staticRead(info.filename)
          let n = parseStmt(src)
          proc find(n: NimNode) =
            for i in 0..<n.len:
              if n[i].kind in {nnkCall, nnkCommand}:
                let s = if n[i][0].kind == nnkDotExpr:
                  n[i][0][1].repr
                else:
                  n[i][0].repr
                if s == "connectManager":
                  connectManagerExist = true
                  break
              else:
                find(n[i])
          find(n)
        findConnectManagerMacro()
      when not connectManagerExist:
        {.passC: "-DWSCONNECT=" & $`id`.}

    if not startsWith(`url`, "ws://"):
      errorException "error: invalid scheme url=", `url`
    let urlparam = `url`[5..^1].split("/")
    let hostparam = urlparam[0].split(":")
    let hostname = hostparam[0]
    let port = if hostparam.len == 2: parseInt(hostparam[1]) else: 80
    let path = if urlparam.len == 2: "/" & urlparam[1] else : "/"

    `wsClient`.set(hostname, port.Port, `protocol`)
    `wsClient`.path = path.toBytes
    `wsClient`.connectId = `id`
    `wsClient`.onOpen = proc(`client`: WsClient) = `onOpen`
    `wsClient`.onReady = proc(`client`: WsClient) = `onReady`
    `wsClient`.onMessage = proc(`client`: WsClient, `data`: ptr UncheckedArray[byte], `size`: int) =
      template `content`(): string = `data`.toString(`size`)
      `onMessage`
    `wsClient`.onClose = proc(`client`: WsClient) = `onClose`
    `wsClient`.onError = proc(`client`: WsClient) = `onError`
    discard `wsClient`.sock.connect(`wsClient`.aiList.ai_addr, `wsClient`.aiList.ai_addrlen.SockLen)

    `wsClient`.appId = AppId.AppConnect
    `wsClient`.evOutAdd()

    when defined(AutoConnectManager):
      when not connectManagerExist:
        if `id` == wsConnect:
          connectManager()

macro connect*(wsClient: WsClient, url: string, body: untyped) =
  newCall(bindSym"connect", wsClient, url, newLit(""), body)

macro connect*(wsClient: WsClient, url: string) =
  newCall(bindSym"connect", wsClient, url, newLit(""), newEmptyNode())


when isMainModule:
  var client = newWsClient()
  client.connect("ws://localhost:8001/api", "pastel-v0.1"):
    onOpen:
      echo "onOpen"
    onReady:
      echo "onReady"
    onMessage:
      echo "onMessage"
      echo content
    onClose:
      echo "onClose"

  connectManager()
