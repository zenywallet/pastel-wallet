# Copyright (c) 2019 zenywallet

type Page* {.pure.} = enum
  Release
  Maintenance
  Debug

var page*: Page = Page.Release
