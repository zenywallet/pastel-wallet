# Copyright (c) 2019 zenywallet

import std/strutils
{.emit: replace(staticRead("ui.js"), "`", "``").}
