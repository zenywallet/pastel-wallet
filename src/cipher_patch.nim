# Copyright (c) 2025 zenywallet

import std/os
import std/strutils

const curPath = currentSourcePath().parentDir()

var jsOrg = readFile(curPath / "../public/js/cipher.js")

var jsPatch = jsOrg.replace("""class ExitStatus{name="ExitStatus";constructor(status){""",
                          """class ExitStatus{constructor(status){this.name="ExitStatus";""")

writeFile(curPath / "../public/js/cipher.js", jsPatch)
