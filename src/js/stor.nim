# Copyright (c) 2019 zenywallet

import std/jsffi
import std/macros
import zenyjs
import zenyjs/core
import zenyjs/seed

macro jsPrototype(obj: typed, field: untyped, body: untyped): untyped =
  var protoStr = "#.prototype." & $field & " = #"
  var protoHelper = ident($obj & "_proto_" & $field)
  quote do:
    proc `protoHelper`(obj, body: auto) {.importjs: `protoStr`.}
    `protoHelper`(`obj`, `body`)

var Stor* {.exportc.} = proc() = discard

var localStorage {.importc, nodecl.}: JsObject
var db = if localStorage.isDefined(): localStorage else: JsObject{}
template hex2buf(str: cstring or JsObject): Uint8Array = hexToUint8Array(str.to(cstring))
template buf2hex(uint8Array: Uint8Array or JsObject): cstring = uint8ArrayToHex(uint8Array)

Stor.jsPrototype(add_xpub):
  proc(xpub: JsObject) =
    var xpubs = db["xpubs"]
    if xpubs.to(bool):
      xpubs = JSON.parse(xpubs)
    else:
      xpubs = [].toJs
    if not xpubs.includes(xpub).to(bool):
      xpubs.push(xpub)
      db["xpubs"] = JSON.stringify(xpubs)

Stor.jsPrototype(set_xpubs):
  proc(xpubs: JsObject) =
    db["xpubs"] = JSON.stringify(xpubs)

Stor.jsPrototype(get_xpubs):
  proc(): JsObject =
    var xpubs = db["xpubs"]
    if xpubs.to(bool):
      xpubs = JSON.parse(xpubs)
    else:
      xpubs = [].toJs
    return xpubs

Stor.jsPrototype(del_xpub):
  proc(xpub: JsObject) =
    var xpubs = db["xpubs"]
    if xpubs.to(bool):
      xpubs = JSON.parse(xpubs)
      var idx = xpubs.indexOf(xpub)
      if idx.to(int) >= 0:
        xpubs.splice(idx, 1)
        db["xpubs"] = JSON.stringify(xpubs)
    else:
      xpubs = [].toJs
    if xpubs.length == 0.toJs:
      db.removeItem("xpubs")

Stor.jsPrototype(del_xpubs):
  proc() = db.removeItem("xpubs")

Stor.jsPrototype(del_all):
  proc() = db.clear()

Stor.jsPrototype(get_salt):
  proc(create_no_exists: bool): JsObject =
    var salt = db["salt"]
    if salt.to(bool):
      return hex2buf(salt)

    if create_no_exists:
      var buf = cryptSeedUint8Array(32)
      db["salt"] = buf2hex(buf)

      salt = db["salt"]
      if salt.to(bool):
        return hex2buf(salt)
      return jsNull
    else:
      return jsNull

Stor.jsPrototype(set_shield):
  proc(data: JsObject) =
    db["shield"] = buf2hex(data)

Stor.jsPrototype(get_shield):
  proc(): JsObject =
    return hex2buf(db["shield"])

Stor.jsPrototype(set_lock_type):
  proc(lock_type: JsObject) =
    db["locktype"] = lock_type

Stor.jsPrototype(get_lock_type):
  proc(): JsObject =
    return db["locktype"]

Stor.jsPrototype(set_lang):
  proc(lang: JsObject) =
    db["lang"] = lang

Stor.jsPrototype(get_lang):
  proc(): JsObject =
    return db["lang"]
