# Package

version       = "0.1.0"
author        = "zenywallet"
description   = "Pastel Wallet - A sample wallet using Blockstor API"
license       = "MIT"
srcDir        = "src"
binDir        = "bin"
bin           = @["pastel"]



# Dependencies

requires "nim >= 0.20.0"
requires "jester >= 0.4.1"
requires "templates", "nimcrypto", "ed25519", "rocksdb", "libcurl"
requires "byteutils", "karax"
