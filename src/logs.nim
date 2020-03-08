# Copyright (c) 2019 zenywallet

var debugMode = false

proc debugEnable*() =
  debugMode = true

proc debugDisable*() =
  debugMode = false

template debug*(x: varargs[string, `$`]) =
  if debugMode:
    for s in x:
      stdout.write s
    stdout.writeLine ""

when isMainModule:
  var a: int = 12345
  debug "test", $a
