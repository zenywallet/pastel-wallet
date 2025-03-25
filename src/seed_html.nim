# Copyright (c) 2019 zenywallet

import caprese/contents

const SeedScript = staticScript:
  import std/jsffi
  import caprese/jslib
  import js/base58 as base58js

  type
    SeedCtyptoError = object of CatchableError

  proc jq(selector: cstring): JsObject {.importcpp: "$$(#)".}
  var base58 {.importc, nodecl.}: JsObject
  var base58_chars {.importc, nodecl.}: JsObject

  var crypto = window.crypto or window.msCrypto
  if crypto.to(bool) and crypto.getRandomValues.to(bool):
    var priv = newUint8Array(32)
    crypto.getRandomValues(priv)
    var priv_base58 = base58.enc(priv)
    var priv_dec = priv_base58.dec()
    var enc_err = 0
    if priv.length != priv_dec.length:
      enc_err = 1
    else:
      for i in 0..<priv.length.to(int):
        if priv[i] != priv_dec[i]:
          enc_err = 1
          break
    if enc_err != 0:
      raise newException(SeedCtyptoError, "base58 encode failed.")

    var tags = newUint8Array(6)
    crypto.getRandomValues(tags)
    var tag = "".toJs
    for i in 0..<tags.length.to(int):
      tag += base58_chars[(tags[i].to(int) mod 58)]
    var seedstr = "seed:".toJs + priv_base58 + ",tag:".toJs + tag + ",gen:pastel-v0.1".toJs
    document.getElementById("seed").innerHTML = seedstr
    var s = 400
    jq("#qrcode").qrcode(JsObject{
      render: "canvas".cstring,
      ecLevel: "Q".cstring,
      radius: 0.39,
      text: seedstr,
      size: s,
      mode: 2,
      label: "seed".cstring,
      fontname: "sans".cstring,
      fontcolor: "#393939".cstring
    })
  else:
    raise newException(SeedCtyptoError, "Secure random number generation is not supported by this browser.")

const extern = """
var base58 = {
  enc: function() {},
  dec: function() {}
};
var jq = {
  qrcode: function() {},
  qrcode_data: {
    render: 0,
    ecLevel: 0,
    radius: 0,
    text: 0,
    size: 0,
    mode: 0,
    label: 0,
    fontname: 0,
    fontcolor: 0
  }
};
"""

const SeedMinScript = scriptMinifier(code = SeedScript, extern = extern)

const SeedHtml* = staticHtmlDocument:
  buildHtml(html):
    head:
      meta(charset="utf-8")
      script(type="text/javascript", src="/js/jquery-3.4.1.slim.min.js")
      script(type="text/javascript", src="/js/jquery-qrcode.min.js")
      title: text "Seed Maker"
    body:
      tdiv(id="qrcode")
      tdiv(id="seed")
      script: verbatim SeedMinScript
