# Copyright (c) 2019 zenywallet

import std/strutils
import zenyjs
import zenyjs/core
import zenyjs/address

networksDefault()

proc check_address(address: cstring): bool {.exportc.} =
  var s = BitZeny_mainnet.getScript(address)
  if s.len > 0:
    true
  else:
    false

{.emit: replace(staticRead("ui.js"), "`", "``").}
