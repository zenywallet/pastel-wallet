# Copyright (c) 2019 zenywallet

var debugMode = false

proc debugEnable*() =
  debugMode = true

proc debugDisable*() =
  debugMode = false

proc debug*(x: varargs[string, `$`]) =
  if debugMode:
    for s in x:
      stdout.write s
    stdout.writeLine ""
