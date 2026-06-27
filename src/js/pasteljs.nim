# Copyright (c) 2019 zenywallet

import zenyjs
import zenyjs/core
import zenyjs/utils

proc sha256s(data: JsObject): Uint8Array {.exportc.} =
  if jsTypeOf(data) == "string".cstring:
    sha256s(data.to(cstring).toBytes)
  elif jsTypeOf(data) == "object".cstring:
    sha256s(data.to(Uint8Array).toBytes)
  else:
    raise

{.emit: staticRead("pastel.js").}
