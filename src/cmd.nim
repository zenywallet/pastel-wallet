# Copyright (c) 2019 zenywallet

import terminal, db, blockstor
const blockstor_apikey = "sample-969a6d71-a259-447c-a486-90bac964992b"

proc cmd_main() {.thread.} =
  while true:
    stdout.styledWrite(styleBright, fgCyan, "> ")
    var cmd = stdin.readLine()
    if cmd.len > 0:
      stdout.styledWriteLine(styleBright, fgCyan, "cmd: ", cmd)
      if cmd == "wallets":
        for d in db.getWallets(""):
          stdout.styledWriteLine(styleBright, fgBlue, $d)
      elif cmd == "delwallets":
        db.delWallets();
        let smarker = blockstor.setMarker(blockstor_apikey, 0);

var cmd_thread: Thread[void]

proc start*(): Thread[void] =
  createThread(cmd_thread, cmd_main)
  system.addQuitProc(resetAttributes)
  cmd_thread
