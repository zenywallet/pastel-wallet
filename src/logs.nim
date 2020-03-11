# Copyright (c) 2019 zenywallet

import bitops, strutils

type Debug* {.pure.} = enum
  All
  Common
  Connection
  Stream
  CommonError
  ConnectionError
  StreamError
  Critical

var msgflag: uint32

proc enable*(msgtype: Debug) =
  setBit(msgflag, msgtype.ord)

proc disable*(msgtype: Debug) =
  clearBit(msgflag, msgtype.ord)

proc check*(msgtype: Debug): bool =
  testBit(msgflag, msgtype.ord)

proc debugEnable*() =
  Debug.All.enable()

proc debugDisable*() =
  Debug.All.disable()

template debug*(x: varargs[string, `$`]) =
  if testBit(msgflag, Debug.Common.ord) or testBit(msgflag, Debug.All.ord):
    stdout.write "\r"
    for s in x:
      stdout.write s
    stdout.writeLine ""

template write*(msgtype: Debug, x: varargs[string, `$`]) =
  if testBit(msgflag, msgtype.ord) or testBit(msgflag, Debug.All.ord):
    stdout.write "\r"
    for s in x:
      stdout.write s
    stdout.writeLine ""

Debug.CommonError.enable()
Debug.ConnectionError.enable()
Debug.StreamError.enable()
Debug.Critical.enable()

when isMainModule:
  var a: int = 12345
  debug "test", $a

  Debug.Connection.write "hello?"
  Debug.Connection.enable()
  Debug.Connection.write "hello!"
  Debug.Connection.disable()
  Debug.Connection.write "hello?"
  Debug.All.enable()
  Debug.Connection.write "hello!"
