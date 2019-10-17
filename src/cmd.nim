# Copyright (c) 2019 zenywallet

import terminal, parseopt, db, blockstor
const blockstor_apikey = "sample-969a6d71-a259-447c-a486-90bac964992b"

proc cmd_main() {.thread.} =
  while true:
    stdout.styledWrite(styleBright, fgCyan, "> ")
    var cmd = stdin.readLine()
    stdout.styledWriteLine(styleBright, fgCyan, "cmd: ", cmd)
    var p = initOptParser(cmd)
    while true:
      p.next()
      case p.kind
      of cmdEnd: break
      of cmdArgument:
        if p.key == "wallets":
          p.next()
          for d in db.getWallets(if p.kind == cmdEnd: "" else: p.key):
            stdout.styledWriteLine(styleBright, fgBlue, $d)
          break
        elif p.key == "delwallets":
          db.delWallets()
          echo blockstor.setMarker(blockstor_apikey, 0)
          break
      else: discard

var cmd_thread: Thread[void]

proc start*(): Thread[void] =
  createThread(cmd_thread, cmd_main)
  system.addQuitProc(resetAttributes)
  cmd_thread
