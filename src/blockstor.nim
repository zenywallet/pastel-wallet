# Copyright (c) 2019 zenywallet

import httpclient, json, asyncdispatch, strutils
export json

const baseurl = "http://localhost:8000/api/"

type
  BsErrorCode* {.pure.} = enum
    SUCCESS
    ERROR
    SYNCING
    ROLLBACKING
    ROLLBACKED
    UNKNOWN_APIKEY
    BUSY
    TOO_MANY
    TOO_HIGH

var client {.threadvar.}: HttpClient
var clientAsync {.threadvar.}: AsyncHttpClient

proc get(cmdurl: string): JsonNode =
  try:
    if client.isNil:
      client = newHttpClient()
    let url = baseurl & cmdurl
    let res = client.request(url)
    if res.status == Http200:
      parseJson(res.body)
    else:
      echo "blockstor-get: " & res.status & " " & cmdurl
      newJNull()
  except:
    let e = getCurrentException()
    echo e.name, ": ", e.msg
    newJNull()

proc post(cmdurl: string, postdata: JsonNode): JsonNode =
  try:
    if client.isNil:
      client = newHttpClient()
    client.headers = newHttpHeaders({"Content-Type": "application/json"})
    let url = baseurl & cmdurl
    let res = client.request(url, httpMethod = HttpPost, body = $postdata)
    if res.status == Http200:
      parseJson(res.body)
    else:
      echo "blockstor-post: " & res.status & " " & cmdurl
      newJNull()
  except:
    let e = getCurrentException()
    echo e.name, ": ", e.msg
    newJNull()

proc getAsync(cmdurl: string, cb: proc(data: JsonNode)) {.async.} =
  try:
    if clientAsync.isNil:
      clientAsync = newAsyncHttpClient()
    let url = baseurl & cmdurl
    let res = await clientAsync.request(url)
    if res.status == Http200:
      cb(parseJson(await res.body))
    else:
      echo "blockstor-get: " & res.status & " " & cmdurl
      cb(newJNull())
  except:
    let e = getCurrentException()
    echo e.name, ": ", e.msg
    cb(newJNull())

proc postAsync(cmdurl: string, postdata: JsonNode, cb: proc(data: JsonNode)) {.async.} =
  try:
    if clientAsync.isNil:
      clientAsync = newAsyncHttpClient()
    client.headers = newHttpHeaders({"Content-Type": "application/json"})
    let url = baseurl & cmdurl
    let res = await clientAsync.request(url, httpMethod = HttpPost, body = $postdata)
    if res.status == Http200:
      echo res.status
      cb(parseJson(await res.body))
    else:
      echo "blockstor-post: " & res.status & " " & cmdurl
      cb(newJNull())
  except:
    let e = getCurrentException()
    echo e.name, ": ", e.msg
    cb(newJNull())

proc toUrlParam(params: tuple): string =
  result = ""
  var firstparam = true
  for key, value in params.fieldPairs:
    if firstparam:
      result = "?" & key & "=" & $value
      firstparam = false
    else:
      result = result & "&" & key & "=" & $value

proc toUrlParam(params: JsonNode): string =
  result = ""
  var firstparam = true
  for item in params.pairs:
    if firstparam:
      result = "?" & $item.key & "=" & $item.val
      firstparam = false
    else:
      result = result & "&" & $item.key & "=" & $item.val


proc getAddress*(address: string): JsonNode {.inline.} =
  get("addr/" & address)

proc getAddress*(addresses: openarray[string]): JsonNode {.inline.} =
  post("addrs", %*{"addrs": addresses})

proc getUtxo*(address: string): JsonNode {.inline.} =
  get("utxo/" & address)

proc getUtxo*(address: string, params: tuple or JsonNode): JsonNode {.inline.} =
  get("utxo/" & address & params.toUrlParam)

proc getUtxo*(addresses: openarray[string]): JsonNode {.inline.} =
  post("utxos", %*{"addrs": addresses})

proc getUtxo*(addresses: openarray[string], params: tuple or JsonNode): JsonNode {.inline.} =
  post("utxos" & params.toUrlParam, %*{"addrs": addresses})

proc getAddrlog*(address: string): JsonNode {.inline.} =
  get("addrlog/" & address)

proc getAddrlog*(address: string, params: tuple or JsonNode): JsonNode {.inline.} =
  get("addrlog/" & address & params.toUrlParam)

proc getAddrlog*(addresses: openarray[string]): JsonNode {.inline.} =
  post("addrlogs", %*{"addrs": addresses})

proc getAddrlog*(addresses: openarray[string], params: tuple or JsonNode): JsonNode {.inline.} =
  post("addrlogs" & params.toUrlParam, %*{"addrs": addresses})

proc getMempool*(): JsonNode {.inline.} =
  get("mempool")

proc getMarker*(apikey: string): JsonNode {.inline.} =
  get("marker/" & apikey)

proc setMarker*(apikey: string, sequence: uint64): JsonNode {.inline.} =
  post("marker", %*{"apikey": apikey, "sequence": sequence})

proc getHeight*(): JsonNode {.inline.} =
  get("height")

proc send*(rawtx: string): JsonNode {.inline.} =
  post("addrs", %*{"rawtx": rawtx})

proc getTx*(tx: string): JsonNode {.inline.} =
  get("tx/" & tx)

proc search*(keyword: string): JsonNode {.inline.} =
  get("search/" & keyword)


proc getAddress*(address: string, cb: proc(data: JsonNode)) {.inline.} =
  asyncCheck getAsync("addr/" & address, cb)

proc getAddress*(addresses: openarray[string], cb: proc(data: JsonNode)) {.inline.} =
  asyncCheck postAsync("addrs", %*{"addrs": addresses}, cb)

proc getUtxo*(address: string, cb: proc(data: JsonNode)) {.inline.} =
  asyncCheck getAsync("utxo/" & address, cb)

proc getUtxo*(address: string, params: tuple or JsonNode, cb: proc(data: JsonNode)) {.inline.} =
  asyncCheck getAsync("utxo/" & address & params.toUrlParam, cb)

proc getUtxo*(addresses: openarray[string], cb: proc(data: JsonNode)) {.inline.} =
  asyncCheck postAsync("utxos", %*{"addrs": addresses}, cb)

proc getUtxo*(addresses: openarray[string], params: tuple or JsonNode, cb: proc(data: JsonNode)) {.inline.} =
  asyncCheck postAsync("utxos" & params.toUrlParam, %*{"addrs": addresses}, cb)

proc getAddrlog*(address: string, cb: proc(data: JsonNode)) {.inline.} =
  asyncCheck getAsync("addrlog/" & address, cb)

proc getAddrlog*(address: string, params: tuple or JsonNode, cb: proc(data: JsonNode)) {.inline.} =
  asyncCheck getAsync("addrlog/" & address & params.toUrlParam, cb)

proc getAddrlog*(addresses: openarray[string], cb: proc(data: JsonNode)) {.inline.} =
  asyncCheck postAsync("addrlogs", %*{"addrs": addresses}, cb)

proc getAddrlog*(addresses: openarray[string], params: tuple or JsonNode, cb: proc(data: JsonNode)) {.inline.} =
  asyncCheck postAsync("addrlogs" & params.toUrlParam, %*{"addrs": addresses}, cb)

proc getMempool*(cb: proc(data: JsonNode)) {.inline.} =
  asyncCheck getAsync("mempool", cb)

proc getMarker*(apikey: string, cb: proc(data: JsonNode)) {.inline.} =
  asyncCheck getAsync("marker/" & apikey, cb)

proc setMarker*(apikey: string, sequence: uint64, cb: proc(data: JsonNode)) {.inline.} =
  asyncCheck postAsync("marker", %*{"apikey": apikey, "sequence": sequence}, cb)

proc getHeight*(cb: proc(data: JsonNode)) {.inline.} =
  asyncCheck getAsync("height", cb)

proc send*(rawtx: string, cb: proc(data: JsonNode)) {.inline.} =
  asyncCheck postAsync("addrs", %*{"rawtx": rawtx}, cb)

proc getTx*(tx: string, cb: proc(data: JsonNode)) {.inline.} =
  asyncCheck getAsync("tx/" & tx, cb)

proc search*(keyword: string, cb: proc(data: JsonNode)) {.inline.} =
  asyncCheck getAsync("search/" & keyword, cb)

proc getUint64*(data: JsonNode): uint64 =
  result = case data.kind
    of JInt:
      cast[uint64](data.getBiggestInt)
    of Jstring:
      cast[uint64](parseBiggestUInt(data.getStr))
    else:
      raise

proc getUint32*(data: JsonNode): uint32 =
  result = case data.kind
    of JInt:
      cast[uint32](data.getInt)
    of Jstring:
      cast[uint32](parseUInt(data.getStr))
    else:
      raise

proc getUint16*(data: JsonNode): uint16 =
  result = case data.kind
    of JInt:
      cast[uint16](data.getInt)
    of Jstring:
      cast[uint16](parseUInt(data.getStr))
    else:
      raise

proc getUint8*(data: JsonNode): uint8 =
  result = case data.kind
    of JInt:
      cast[uint8](data.getInt)
    of Jstring:
      cast[uint8](parseUInt(data.getStr))
    else:
      raise

iterator toApiResIterator*(api_result: JsonNode): JsonNode =
  if api_result.kind != JNull and api_result["err"].getInt == 0 and
    api_result{"res"} != nil and api_result["res"].kind == JArray:
    for d in api_result["res"]:
      yield d

proc resLen*(api_result: JsonNode): int =
  if api_result{"res"} != nil and api_result["res"].kind == JArray:
    result = api_result["res"].len
  else:
    result = 0

when isMainModule:
  echo get("addr/ZdzzJGbxRLSiim9cWvVHetJVxzPW72n6eP")
  echo post("addrs", %*{"addrs": ["ZdzzJGbxRLSiim9cWvVHetJVxzPW72n6eP"]})

  echo getAddress("ZdzzJGbxRLSiim9cWvVHetJVxzPW72n6eP")
  echo getAddress(["ZdzzJGbxRLSiim9cWvVHetJVxzPW72n6eP", "ZdzzJGbxRLSiim9cWvVHetJVxzPW72n6eP"])

  echo getUtxo("ZdzzJGbxRLSiim9cWvVHetJVxzPW72n6eP")
  echo getUtxo("ZdzzJGbxRLSiim9cWvVHetJVxzPW72n6eP", (limit: 2))
  echo "reverse 1"
  echo getUtxo("ZdzzJGbxRLSiim9cWvVHetJVxzPW72n6eP", (limit: 2, reverse: 1))
  echo "reverse 0"
  echo getUtxo("ZdzzJGbxRLSiim9cWvVHetJVxzPW72n6eP", (limit: 2, reverse: 0))
  echo getUtxo("ZdzzJGbxRLSiim9cWvVHetJVxzPW72n6eP", %*{"limit": 2})
  echo getUtxo(["ZdzzJGbxRLSiim9cWvVHetJVxzPW72n6eP", "ZdzzJGbxRLSiim9cWvVHetJVxzPW72n6eP"], (limit: 2))

  echo getAddrlog("ZdzzJGbxRLSiim9cWvVHetJVxzPW72n6eP", (limit: 2))
  echo getAddrlog(["ZdzzJGbxRLSiim9cWvVHetJVxzPW72n6eP", "ZdzzJGbxRLSiim9cWvVHetJVxzPW72n6eP"], (limit: 2))

  echo getMempool()
  echo getHeight()
  echo getTx("0ed899236a58a802b64373ab9e440d550e324f80ab331be52d7dbc2a69df3c91")
  echo search("0ed899236a58a8")
  echo search("ZdzzJGbxRLSii")

  asyncCheck getAsync("addr/ZdzzJGbxRLSiim9cWvVHetJVxzPW72n6eP", proc(data: JsonNode) = echo data)
  echo "skip"
  asyncCheck getAsync("addr/ZdzzJGbxRLSiim9cWvVHetJVxzPW72n6eP", proc(data: JsonNode) = echo data)
  echo "skip"
  asyncCheck getAsync("addr/ZdzzJGbxRLSiim9cWvVHetJVxzPW72n6eP", proc(data: JsonNode) = echo data)
  echo "skip"
  asyncCheck getAsync("addr/ZdzzJGbxRLSiim9cWvVHetJVxzPW72n6eP", proc(data: JsonNode) = echo data)
  echo "skip"
  asyncCheck getAsync("addr/ZdzzJGbxRLSiim9cWvVHetJVxzPW72n6eP", proc(data: JsonNode) = echo data)
  echo "skip"
  waitFor getAsync("addr/ZdzzJGbxRLSiim9cWvVHetJVxzPW72n6eP", proc(data: JsonNode) = echo data)

  getAddress("ZdzzJGbxRLSiim9cWvVHetJVxzPW72n6eP", proc(data: JsonNode) = echo data)
  getAddress(["ZdzzJGbxRLSiim9cWvVHetJVxzPW72n6eP", "ZdzzJGbxRLSiim9cWvVHetJVxzPW72n6eP"], proc(data: JsonNode) = echo data)

  let j1 = parseJson("""{"key": 4294967295}""")
  echo j1["key"].getUint32

  let j2 = parseJson("""{"key": -1}""")
  echo j2["key"].getUint32

  let j3 = parseJson("""{"key": 9007199254740991}""")
  echo j3["key"].getUint64

  let j4 = parseJson("""{"key": 9007199254740992}""")
  echo j4["key"].getUint64

  let j5 = parseJson("""{"key": "9007199254740991"}""")
  echo j5["key"].getUint64

  let j6 = parseJson("""{"key": "9007199254740992"}""")
  echo j6["key"].getUint64

  let j7 = parseJson("""{"key": -1}""")
  echo j7["key"].getUint64

  try:
    runForever()
  except ValueError:
    discard
