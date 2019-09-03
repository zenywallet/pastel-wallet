# Copyright (c) 2019 zenywallet
# nim js -d:release main.nim

include karax / prelude
import jsffi except `&`
import strutils
import unicode
import sequtils

var document {.importc, nodecl.}: JsObject
#var console {.importc, nodecl.}: JsObject
proc jq(selector: cstring): JsObject {.importcpp: "$$(#)".}
proc replace*(s, a, b: cstring): cstring {.importcpp, nodecl.}
proc join*(s: cstring): cstring {.importcpp, nodecl.}
proc includes*(s: seq[cstring], a: cstring): bool {.importcpp, nodecl.}

type ImportType {.pure.} = enum
  SeedCard
  Mnemonic

var currentImportType = ImportType.SeedCard;

proc importTypeButtonClass(importType: ImportType): cstring =
  if importType == currentImportType:
    "ui olive button"
  else:
    "ui grey button"

proc importSelector(importType: ImportType): proc() =
  result = proc() =
    currentImportType = importType

proc appMain(): VNode =
  result = buildHtml(tdiv):
    section(id="section1", class="section"):
      tdiv(class="intro"):
        tdiv(class="intro-head"):
          tdiv(class="caption"): text "Pastel Wallet"
          tdiv(class="ui container method-selector"):
            tdiv(class="title"): text "Import the master seed to start your wallet."
            tdiv(class="ui buttons"):
              button(class=importTypeButtonClass(ImportType.SeedCard), onclick=importSelector(ImportType.SeedCard)):
                italic(class="qrcode icon")
                text "Seed card"
              tdiv(class="or")
              button(class=importTypeButtonClass(ImportType.Mnemonic), onclick=importSelector(ImportType.Mnemonic)):
                italic(class="list alternate icon")
                text "Mnemonic"
        tdiv(class="intro-body"):
          if currentImportType == ImportType.SeedCard:
            tdiv(class="ui enter aligned segment"):
              tdiv(class="ui teal labeled icon button bt-scan-seed"):
                text "Scan seed card with camera"
                italic(class="camera icon")
          else:
            tdiv(class="ui enter aligned segment")

proc afterScript() =
  jq("#section0").remove()

setRenderer appMain, "main", afterScript
