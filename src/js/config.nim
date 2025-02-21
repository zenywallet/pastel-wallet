import std/os
import ../config

const srcDir = currentSourcePath().parentDir()

writeFile(srcDir / "../../public/js/config.js", """
var pastel = pastel || {};
pastel.config = pastel.config || {
  ws_url: '""" & WebSocketUrl & """',
  ws_protocol: 'pastel-v0.1',
  network: 'bitzeny'
};
""")
