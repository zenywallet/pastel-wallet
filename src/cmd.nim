# Copyright (c) 2019 zenywallet

import os, db, blockstor
const blockstor_apikey = "sample-969a6d71-a259-447c-a486-90bac964992b"

proc cmd_main() {.thread.} =
  while true:
    stdout.write "\e[1;36m> \e[00m"
    var cmd = stdin.readLine()
    if cmd.len > 0:
      echo  "\e[1;36mcmd: ", cmd, "\e[00m"
      if cmd == "wallets":
        for d in db.getWallets(""):
          echo "\e[1;34m", d, "\e[00m"
      elif cmd == "delwallets":
        db.delWallets();
        let smarker = blockstor.setMarker(blockstor_apikey, 0);

var cmd_thread: Thread[void]

proc start*(): Thread[void] =
  createThread(cmd_thread, cmd_main)
  cmd_thread
