# Copyright (c) 2019 zenywallet

import httpclient, json, asyncdispatch
export json

const baseurl = "http://localhost:8000/api/"

proc get(cmdurl: string): JsonNode =
  try:
    let client = newHttpClient()
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
    let client = newHttpClient()
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
    let client = newAsyncHttpClient()
    let url = baseurl & cmdurl
    let res = await client.request(url)
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
    let client = newAsyncHttpClient()
    client.headers = newHttpHeaders({"Content-Type": "application/json"})
    let url = baseurl & cmdurl
    let res = await client.request(url, httpMethod = HttpPost, body = $postdata)
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


template getAddress*(address: string): JsonNode =
  get("addr/" & address)

template getAddress*(addresses: openarray[string]): JsonNode =
  post("addrs", %*{"addrs": addresses})

template getUtxo*(address: string): JsonNode =
  get("utxo/" & address)

template getUtxo*(address: string, params: tuple or JsonNode): JsonNode =
  get("utxo/" & address & params.toUrlParam)

template getUtxo*(addresses: openarray[string]): JsonNode =
  post("utxos", %*{"addrs": addresses})

template getUtxo*(addresses: openarray[string], params: tuple or JsonNode): JsonNode =
  post("utxos" & params.toUrlParam, %*{"addrs": addresses})

template getAddrlog*(address: string): JsonNode =
  get("addrlog/" & address)

template getAddrlog*(address: string, params: tuple or JsonNode): JsonNode =
  get("addrlog/" & address & params.toUrlParam)

template getAddrlog*(addresses: openarray[string]): JsonNode =
  post("addrlogs", %*{"addrs": addresses})

template getAddrlog*(addresses: openarray[string], params: tuple or JsonNode): JsonNode =
  post("addrlogs" & params.toUrlParam, %*{"addrs": addresses})

template getMempool*(): JsonNode =
  get("mempool")

template getMarker*(apikey: string): JsonNode =
  get("marker/" & apikey)

template setMarker*(apikey: string, sequence: uint64): JsonNode =
  post("marker", %*{"apikey": apikey, "sequence": sequence})

template getHeight*(): JsonNode =
  get("height")

template send*(rawtx: string): JsonNode =
  post("addrs", %*{"rawtx": rawtx})

template getTx*(tx: string): JsonNode =
  get("tx/" & tx)

template search*(keyword: string): JsonNode =
  get("search/" & keyword)


template getAddress*(address: string, cb: proc(data: JsonNode)) =
  asyncCheck getAsync("addr/" & address, cb)

template getAddress*(addresses: openarray[string], cb: proc(data: JsonNode)) =
  asyncCheck postAsync("addrs", %*{"addrs": addresses}, cb)

template getUtxo*(address: string, cb: proc(data: JsonNode)) =
  asyncCheck getAsync("utxo/" & address, cb)

template getUtxo*(address: string, params: tuple or JsonNode, cb: proc(data: JsonNode)) =
  asyncCheck getAsync("utxo/" & address & params.toUrlParam, cb)

template getUtxo*(addresses: openarray[string], cb: proc(data: JsonNode)) =
  asyncCheck postAsync("utxos", %*{"addrs": addresses}, cb)

template getUtxo*(addresses: openarray[string], params: tuple or JsonNode, cb: proc(data: JsonNode)) =
  asyncCheck postAsync("utxos" & params.toUrlParam, %*{"addrs": addresses}, cb)

template getAddrlog*(address: string, cb: proc(data: JsonNode)) =
  asyncCheck getAsync("addrlog/" & address, cb)

template getAddrlog*(address: string, params: tuple or JsonNode, cb: proc(data: JsonNode)) =
  asyncCheck getAsync("addrlog/" & address & params.toUrlParam, cb)

template getAddrlog*(addresses: openarray[string], cb: proc(data: JsonNode)) =
  asyncCheck postAsync("addrlogs", %*{"addrs": addresses}, cb)

template getAddrlog*(addresses: openarray[string], params: tuple or JsonNode, cb: proc(data: JsonNode)) =
  asyncCheck postAsync("addrlogs" & params.toUrlParam, %*{"addrs": addresses}, cb)

template getMempool*(cb: proc(data: JsonNode)) =
  asyncCheck getAsync("mempool", cb)

template getMarker*(apikey: string, cb: proc(data: JsonNode)) =
  asyncCheck getAsync("marker/" & apikey, cb)

template setMarker*(apikey: string, sequence: uint64, cb: proc(data: JsonNode)) =
  asyncCheck postAsync("marker", %*{"apikey": apikey, "sequence": sequence}, cb)

template getHeight*(cb: proc(data: JsonNode)) =
  asyncCheck getAsync("height", cb)

template send*(rawtx: string, cb: proc(data: JsonNode)) =
  asyncCheck postAsync("addrs", %*{"rawtx": rawtx}, cb)

template getTx*(tx: string, cb: proc(data: JsonNode)) =
  asyncCheck getAsync("tx/" & tx, cb)

template search*(keyword: string, cb: proc(data: JsonNode)) =
  asyncCheck getAsync("search/" & keyword, cb)


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

  try:
    runForever()
  except ValueError:
    discard
