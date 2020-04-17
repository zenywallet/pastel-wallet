# Copyright (c) 2019 zenywallet

import terminal, parseopt, db, blockstor, logs, strutils, server
import config

proc usage() =
  stdout.styledWriteLine(styleBright, fgCyan, """
usage:
  debug [ { 1 | 0 } | { all | common | connection ... } { 1 | 0 } ]
    1 - enable, 0 - disable
  wallet [ xpub | wallet_id | * ]
    * - all
  delwallet { xpub | wallet_id | * }
    * - all
  addrvals { wallet_id }
  addrlogs { wallet_id }
  unspents { wallet_id }
  page [ release | maintenance | debug ]
""")

proc debug_status() =
  var maxlen = 0
  for d in Debug.low..Debug.high:
    var l = ($d).len
    if l > maxlen:
      maxlen = l
  for d in Debug.low..Debug.high:
    var l = ($d).len
    echo "  ", ($d).toLowerAscii(), " ".repeat(maxlen - l + 1), d.check()

proc cmd_main() {.thread.} =
  while true:
    stdout.styledWrite(styleBright, fgCyan, "> ")
    var cmd = stdin.readLine()
    if cmd.len == 0:
      continue
    stdout.styledWriteLine(styleBright, fgCyan, "cmd: ", cmd)
    var p = initOptParser(cmd)
    p.next()
    if p.kind == cmdArgument:
      if p.key == "wallet":
        p.next()
        if p.kind == cmdArgument:
          if p.key == "all" or p.key == "*":
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
                usage()
        elif p.kind == cmdEnd:
          for d in db.getWallets(""):
            stdout.styledWriteLine(styleBright, fgBlue, $d)
      elif p.key == "delwallet":
        p.next()
        if p.kind == cmdArgument:
          if p.key == "all" or p.key == "*":
            stdout.styledWriteLine(styleBright, fgBlue, "delete table: " & $Prefix.wallets & " " & $db.delTable(Prefix.wallets))
            stdout.styledWriteLine(styleBright, fgBlue, "delete table: " & $Prefix.xpubs & " " & $db.delTable(Prefix.xpubs))
            stdout.styledWriteLine(styleBright, fgBlue, "reset marker err=" & $(blockstor.setMarker(blockstor_apikey, 0)["err"]))
          else:
            stdout.styledWriteLine(styleBright, fgMagenta, "unsupported")
        else:
          usage()
      elif p.key == "debug":
        p.next()
        if p.kind == cmdArgument:
          var find = false
          var pk = p.key.toLowerAscii()
          for d in Debug.low..Debug.high:
            if pk == ($d).toLowerAscii():
              p.next()
              if p.kind == cmdEnd or p.key == "1" or p.key == "true":
                d.enable()
              elif p.key == "0" or p.key == "false":
                d.disable()
              debug_status()
              find = true
              break
          if not find:
            if p.key == "1" or p.key == "true":
              debugEnable()
              debug_status()
            elif p.key == "0" or p.key == "false":
              debugDisable()
              debug_status()
            else:
              usage()
        elif p.kind == cmdEnd:
          debug_status()
      elif p.key == "addrvals":
        p.next()
        if p.kind == cmdArgument:
          try:
            var wallet_id = parseUInt(p.key)
            for g in db.getAddrvals(wallet_id):
              stdout.styledWriteLine(styleBright, fgBlue, $g)
          except:
            usage()
        else:
          usage()
      elif p.key == "addrlogs":
        p.next()
        if p.kind == cmdArgument:
          try:
            var wallet_id = parseUInt(p.key)
            for g in db.getAddrlogs(wallet_id):
              stdout.styledWriteLine(styleBright, fgBlue, $g)
          except:
            usage()
        else:
          usage()
      elif p.key == "unspents":
        p.next()
        if p.kind == cmdArgument:
          try:
            var wallet_id = parseUInt(p.key)
            for g in db.getUnspents(wallet_id):
              stdout.styledWriteLine(styleBright, fgBlue, $g)
          except:
            usage()
        else:
          usage()
      elif p.key == "page":
        p.next()
        if p.kind == cmdArgument:
          if p.key.toLowerAscii() == "release":
            page = Page.Release
          elif p.key.toLowerAscii() == "maintenance":
            page = Page.Maintenance
          elif p.key.toLowerAscii() == "debug":
            page = Page.Debug
          else:
            usage()
        elif p.kind == cmdEnd:
          stdout.styledWriteLine(styleBright, fgBlue, $page)
      else:
        usage()

var cmd_thread: Thread[void]

proc start*(): Thread[void] =
  createThread(cmd_thread, cmd_main)
  system.addQuitProc(resetAttributes)
  cmd_thread
