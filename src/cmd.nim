# Copyright (c) 2019 zenywallet

import terminal, parseopt, db, blockstor, logs, strutils
const blockstor_apikey = "sample-969a6d71-a259-447c-a486-90bac964992b"

proc usage() =
  stdout.styledWriteLine(styleBright, fgCyan, """
usage:
  debug { 1 | 0 }
    1 - enable, 0 - disable
  wallets [ xpub | wallet_id ]
  delwallets
  addrvals { wallet_id }
  addrlogs { wallet_id }
  unspents { wallet_id }
""");

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
          if p.kind == cmdEnd:
            for d in db.getWallets(""):
              stdout.styledWriteLine(styleBright, fgBlue, $d)
          else:
            var find_flag = false
            for d in db.getWallets(p.key):
              stdout.styledWriteLine(styleBright, fgBlue, $d)
              find_flag = true
            if not find_flag:
              try:
                var wallet_id = parseUInt(p.key)
                for d in db.getWallets(""):
                  if d.wallet_id == wallet_id:
                    stdout.styledWriteLine(styleBright, fgBlue, $d)
              except:
                discard
          break
        elif p.key == "delwallets":
          db.delWallets()
          echo blockstor.setMarker(blockstor_apikey, 0)
          break
        elif p.key == "debug":
          p.next()
          if p.key == "1" or p.key == "true":
            debugEnable()
          elif p.key == "0" or p.key == "false":
            debugDisable()
        elif p.key == "addrvals":
          p.next()
          try:
            var wallet_id = parseUInt(p.key)
            for g in db.getAddrvals(wallet_id):
              stdout.styledWriteLine(styleBright, fgBlue, $g)
          except:
            discard
        elif p.key == "addrlogs":
          p.next()
          try:
            var wallet_id = parseUInt(p.key)
            for g in db.getAddrlogs(wallet_id):
              stdout.styledWriteLine(styleBright, fgBlue, $g)
          except:
            discard
        elif p.key == "unspents":
          p.next()
          try:
            var wallet_id = parseUInt(p.key)
            for g in db.getUnspents(wallet_id):
              stdout.styledWriteLine(styleBright, fgBlue, $g)
          except:
            discard
        else:
          usage()
      else: discard

var cmd_thread: Thread[void]

proc start*(): Thread[void] =
  createThread(cmd_thread, cmd_main)
  system.addQuitProc(resetAttributes)
  cmd_thread
