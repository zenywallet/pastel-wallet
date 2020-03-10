# Copyright (c) 2019 zenywallet

import terminal, parseopt, db, blockstor, logs, strutils, server
const blockstor_apikey = "sample-969a6d71-a259-447c-a486-90bac964992b"

proc usage() =
  stdout.styledWriteLine(styleBright, fgCyan, """
usage:
  debug { 1 | 0 }
    1 - enable, 0 - disable
  debug { all | common | connection } { 1 | 0 }
    1 - enable, 0 - disable
  wallets [ xpub | wallet_id ]
  delwallets
  addrvals { wallet_id }
  addrlogs { wallet_id }
  unspents { wallet_id }
  page { release | maintenance | debug }
""");

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
    block cmd_while:
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
            if p.kind == cmdEnd:
              debug_status()
            else:
              var pk = p.key.toLowerAscii();
              for d in Debug.low..Debug.high:
                if pk == ($d).toLowerAscii():
                  p.next()
                  if p.kind == cmdEnd or p.key == "1" or p.key == "true":
                    d.enable()
                  elif p.key == "0" or p.key == "false":
                    d.disable()
                  debug_status()
                  break cmd_while
              if p.key == "1" or p.key == "true":
                debugEnable()
                debug_status()
              elif p.key == "0" or p.key == "false":
                debugDisable()
                debug_status()
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
          elif p.key == "page":
            p.next()
            try:
              if p.key == "release":
                page = Page.Release
              elif p.key == "maintenance":
                page = Page.Maintenance
              elif p.key == "debug":
                page = Page.Debug
              else:
                usage()
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
