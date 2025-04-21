# Copyright (c) 2019 zenywallet
# nim js -d:release main.nim

import karax / [karax, karaxdsl, vdom]
import karax / jstrutils #except `&`
import jsffi except `&`
import strutils
import trans
import stor as storMod
import wallet
import zenyjs/jslib
import base58

var pastel {.importc, nodecl.}: JsObject
var Notify {.importc, nodecl.}: JsObject
var qrReader {.importc, nodecl.}: JsObject
var qrReaderModal {.importc, nodecl.}: JsObject
var TradeLogs {.importc, nodecl.}: JsObject
var PhraseLock {.importc, nodecl.}: JsObject

proc goSection(selector: cstring, cb: proc() = proc() = discard) {.importc, nodecl.}
var page_scroll_done {.importc, nodecl.}: proc()
proc reloadViewSafeEnd() {.importc, nodecl.}
var Settings {.importc, nodecl.}: JsObject
proc bip21reader(uri: JsObject): JsObject {.importc, nodecl.}
proc crlftab_to_html(uri: JsObject): JsObject {.importc, nodecl.}
proc showRecvAddress(cb: proc()) {.importc, nodecl.}
proc showRecvAddressAfterEffect() {.importc, nodecl.}
var target_page_scroll {.importc, nodecl.}: cstring
proc reloadViewSafeStart() {.importc, nodecl.}
proc find_js_native(a, b: JsObject): JsObject {.importcpp: "#.find(#)".}
proc find_js_native(a: JsObject, b: cstring): JsObject {.importcpp: "#.find(#)".}
var registerEventList {.importc, nodecl.}: JsObject
proc type_js_native(a: JsObject): JsObject {.importcpp: "#.type".}

var appInst: KaraxInstance
var document {.importc, nodecl.}: JsObject
proc jq(selector: cstring | JsObject): JsObject {.importcpp: "$$(#)".}
template jq(selector: string): JsObject = jq(selector.cstring)

type ImportType {.pure.} = enum
  SeedCard
  Mnemonic

var currentImportType = ImportType.SeedCard

type ProtectType {.pure.} = enum
  KeyCard
  Passphrase

var currentProtectType = ProtectType.KeyCard

type ViewType = enum
  SeedNone
  SeedScanning
  SeedAfterScan
  MnemonicEdit
  MnemonicFulfill
  SetPassphrase
  KeyNone
  KeyScanning
  KeyAfterScan
  KeyCardDone
  PassphraseEdit
  PassphraseDone
  Wallet
  WalletLogs
  WalletSettings

var showScanSeedBtn = true
var showScanning = true
var showCamTools = true
var showScanResult = false

var showScanSeedBtn2 = true
var showScanning2 = true
var showCamTools2 = true
var showScanResult2 = false

var showPage1 = true
var showPage2 = false
var showPage3 = false
var showPage4 = false
var mnemonicFulfill = false
var keyCardFulfill = false
var passphraseFulfill = false
var supressRedraw = false
var showRecvAddressSelector = true
var showRecvAddressModal = true
var showTradeLogs = false
var showSettings = false

proc viewSelector(view: ViewType, no_redraw: bool = false) =
  case view
  of SeedNone:
    showScanSeedBtn = true
    showScanning = true
    showCamTools = true
    showScanResult = false
    showPage2 = false
  of SeedScanning:
    showScanSeedBtn = true
    showScanning = true
    showCamTools = true
    showScanResult = false
    showPage2 = false
  of SeedAfterScan:
    showScanSeedBtn = false
    showScanning = true
    showCamTools = true
    showScanResult = true
    showPage2 = true
  of MnemonicEdit:
    showPage2 = false
  of MnemonicFulfill:
    showPage2 = true
  of SetPassphrase:
    showScanResult = false
    mnemonicFulfill = false
    showScanSeedBtn2 = true
    showScanning2 = true
    showCamTools2 = true
    showScanResult2 = false
    showPage1 = false
    showPage2 = true
  of KeyAfterScan:
    showScanSeedBtn2 = false
    showScanning2 = true
    showCamTools2 = true
    showScanResult2 = true
    showPage3 = false #true
  of KeyCardDone:
    showPage3 = true
  of PassphraseDone:
    showPage3 = true
  of Wallet:
    showScanResult2 = false
    keyCardFulfill = false
    passphraseFulfill = false
    showPage1 = false
    showPage2 = false
    showPage3 = true
    showPage4 = false
  of WalletLogs:
    showPage1 = false
    showPage2 = false
    showPage3 = true
    showPage4 = true
    showSettings = false
    showTradeLogs = true
  of WalletSettings:
    showPage1 = false
    showPage2 = false
    showPage3 = true
    showPage4 = true
    showTradeLogs = false
    showSettings = true
  else:
    discard

  if not no_redraw:
    appInst.redraw()


proc setSupressRedraw(flag: bool) = supressRedraw = flag
proc getSupressRedraw(): bool = supressRedraw

proc viewUpdate() =
  if not supressRedraw:
    appInst.redraw()

{.emit: """
  var jsViewUpdate = `viewUpdate`;
""".}

#proc importTypeButtonClass(importType: ImportType): cstring =
#  if importType == currentImportType:
#    "ui olive button"
#  else:
#    "ui grey button"

proc importSelector(importType: ImportType): proc() =
  result = proc() =
    qrReader.hide()
    currentImportType = importType

    if currentImportType == ImportType.SeedCard:
      showPage2 = showScanResult
    elif currentImportType == ImportType.Mnemonic:
      showPage2 = mnemonicFulfill

    if currentImportType == ImportType.SeedCard:
      jq("#seedselector".cstring).removeClass("grey".cstring).addClass("olive".cstring)
      jq("#mnemonicselector".cstring).removeClass("olive".cstring).addClass("grey".cstring)
    else:
      jq("#mnemonicselector".cstring).removeClass("grey".cstring).addClass("olive".cstring)
      jq("#seedselector".cstring).removeClass("olive".cstring).addClass("grey".cstring)
    viewUpdate()

proc protectSelector(protectType: ProtectType): proc() =
  result = proc() =
    qrReader.hide()
    currentProtectType = protectType
    showPage1 = false
    showPage2 = true

    #if currentProtectType == ProtectType.KeyCard:
    #  showPage2 = showScanResult
    #elif currentProtectType == ProtectType.Passphrase:
    #  showPage2 = mnemonicFulfill

    if currentProtectType == ProtectType.KeyCard:
      jq("#keyselector".cstring).removeClass("grey".cstring).addClass("olive".cstring)
      jq("#passselector".cstring).removeClass("olive".cstring).addClass("grey".cstring)
    else:
      jq("#passselector".cstring).removeClass("grey".cstring).addClass("olive".cstring)
      jq("#keyselector".cstring).removeClass("olive".cstring).addClass("grey".cstring)
    viewUpdate()

type SeedCardInfo = ref object
  seed: cstring
  gen: cstring
  tag: cstring
  orig: cstring
  sv: cstring

var seedCardInfos: seq[SeedCardInfo]

var editingWords: cstring = ""
var inputWords: cstring = ""
var autocompleteWords: seq[cstring] = @[]
var chklist: seq[tuple[idx: int, word: cstring, flag: bool, levs: seq[cstring]]]
var prevCheckWord: cstring = ""
var passPhrase: cstring = ""

var coinlibs {.importc, nodecl.}: JsObject
var bip39 = coinlibs.bip39
var bip39_wordlist = bip39.wordlists.japanese
var wl_japanese = bip39.wordlists.japanese.to(seq[cstring])
var wl_english = bip39.wordlists.english.to(seq[cstring])
var wl_select = wl_japanese
var wl_select_id = 1

proc clearSensitive() =
  seedCardInfos = @[]
  editingWords = ""
  inputWords = ""
  autocompleteWords = @[]
  chklist = @[]
  prevCheckWord = ""
  passPhrase = ""

proc removeSeedCard(idx: int): proc() =
  result = proc() =
    seedCardInfos.delete(idx)
    if seedCardInfos.len == 0:
      viewSelector(SeedScanning)
    else:
      viewUpdate()

proc seedToKeys() =
  var wallet = pastel.wallet
  if currentImportType == ImportType.SeedCard:
    wallet.setSeedCard(seedCardInfos)
  elif currentImportType == ImportType.Mnemonic:
    wallet.setMnemonic(inputWords, wl_select_id)

proc escape_html(s: cstring): cstring {.importc, nodecl.}

proc cbSeedQrDone(err: int, data: cstring) =
  if err != 0:
    Notify.show(tr("Error".cstring), tr("Camera error. Please connect the camera and reload the page.".cstring), Notify.msgtype.error)
    qrReader.hide()
  else:
    var escape_data = escape_html(data)
    var sdata = $escape_data
    var ds = sdata.split(',')
    var seedCardInfo: SeedCardInfo = new SeedCardInfo
    for d in ds:
      if d.startsWith("seed:"):
        seedCardInfo.seed = d[5..^1].cstring
      elif d.startsWith("tag:"):
        seedCardInfo.tag = d[4..^1].cstring
      elif d.startsWith("gen:"):
        seedCardInfo.gen = d[4..^1].cstring
    seedCardInfo.orig = data

    var seed_valid = false
    if seedCardInfo.seed.toJs.to(bool):
      var dec = base58.dec(seedCardInfo.seed)
      if dec.to(bool) and dec.length == 32.toJs:
        seed_valid = true
    if not seed_valid:
      Notify.show(tr("Warning".cstring), tr("Unsupported seed card was scanned.".cstring), Notify.msgtype.warning)

    var dupcheck = false
    for s in seedCardInfos:
      if s.seed.isNil and seedCardInfo.seed.isNil:
        if s.orig == seedCardInfo.orig:
          dupcheck = true
          break
      elif s.seed == seedCardInfo.seed or s.tag == seedCardInfo.tag:
        dupcheck = true
        break

    if dupcheck:
      Notify.show(tr("Error".cstring), tr("The seed card has already been scanned.".cstring), Notify.msgtype.error)
    else:
      seedCardInfos.add(seedCardInfo)

    qrReader.hide()
    viewSelector(SeedAfterScan)

var keyCardVal: cstring = "".cstring

proc cbKeyQrDone(err: int, data: cstring) =
  if err != 0:
    Notify.show(tr("Error".cstring), tr("Camera error. Please connect the camera and reload the page.".cstring), Notify.msgtype.error)
    qrReader.hide()
  else:
    keyCardVal = data
    qrReader.hide()
    viewSelector(KeyAfterScan)

proc showSeedQr(): proc() =
  result = proc() =
    qrReader.show(cbSeedQrDone)

proc showKeyQr(): proc() =
  result = proc() =
    keyCardFulfill = false
    showPage3 = false
    qrReader.show(cbKeyQrDone)

proc confirmKeyCard(ev: Event; n: VNode) =
  var ret_lock: bool = false
  var wallet = pastel.wallet
  ret_lock = wallet.lockShieldedKeys(keyCardVal, 1, true).to(bool)
  if ret_lock:
    keyCardFulfill = true
    showPage3 = true
    viewUpdate()
  else:
    Notify.show(tr("Error".cstring), tr("Failed to lock your wallet with the key card.".cstring), Notify.msgtype.error)

proc camChange(): proc() =
  result = proc() =
    jq(".camtools button".cstring).blur()
    qrReader.next()

proc camClose(): proc() =
  result = proc() =
    qrReader.hide()

import zenyjs/jslevenshtein

proc levens(word, wordlist: JsObject): JsObject =
  if word.length == 0.toJs:
    return jsNull
  var data = JsObject{}
  for wl in wordlist:
    var maxlen = Math.max(word.length, wl.length)
    var lev = levenshtein(word.to(cstring), wl.to(cstring))
    var score = (lev / maxlen.to(int)).toJs.to(cstring)
    if data[score].to(bool):
      data[score].push(wl)
    else:
      data[score] = [wl].toJs
  var similars = [].toJs
  var ret = [].toJs
  var svals = Object.keys(data).sort()
  for i in 0..<svals.length.to(int):
    var score = svals[i].to(cstring)
    similars.push(data[score])
    if (ret.length > 0.toJs).to(bool) and score > 0.5.toJs.to(cstring):
      break
    if (ret.length.to(int) == 0 and data[score].length.to(int) <= 30) or (ret.length.to(int) + data[score].length.to(int)) <= 7:
      ret = ret.concat(data[score])
  return ret

proc levens_one(word, wordlist: JsObject): JsObject =
  if word.length == 0.toJs:
    return jsNull

  var data = JsObject{}
  for wl in wordlist:
    var maxlen = Math.max(word.length, wl.length)
    var lev = levenshtein(word.to(cstring), wl.to(cstring))
    if lev != 1:
      continue
    var score = (lev / maxlen.to(int)).toJs.to(cstring)
    if data[score].to(bool):
      data[score].push(wl)
    else:
      data[score] = [wl].toJs
  var ret = [].toJs
  var svals = Object.keys(data).sort()
  for i in 0..<svals.length.to(int):
    var score = svals[i].to(cstring)
    ret = ret.concat(data[score])
  return ret

proc replace*(s, a, b: cstring): cstring {.importcpp, nodecl.}
proc join*(s: cstring): cstring {.importcpp, nodecl.}
proc includes*(s: seq[cstring], a: cstring): bool {.importcpp, nodecl.}

#proc levens(word, wordlist: JsObject): JsObject {.importc, nodecl.}
#proc levens_one(word, wordlist: JsObject): JsObject {.importc, nodecl.}

proc check_mnemonic_replace(s: cstring): JsObject {.importcpp: "#.replace(/[ 　\\n\\r]+/g, ' ')".} # /[ \u3000\n\r]+/g

proc checkMnemonic(ev: Event; n: VNode) =
  var s = n.value
  if s != prevCheckWord:
    chklist = @[]
  prevCheckWord = s
  if not s.isNil and s.len > 0:
    if mnemonicFulfill and editingWords != s:
      mnemonicFulfill = false
      viewSelector(MnemonicEdit)
    editingWords = s;
    var cur = document.getElementById(n.id).selectionStart
    s = s.toJs.substr(0.toJs, cur).to(cstring).check_mnemonic_replace().split(" ".cstring).slice(-1)[0].to(cstring)
    if not s.isNil and s.len > 0:
      var tmplist: seq[cstring] = @[]
      for word in bip39_wordlist:
        let w = cast[cstring](word)
        if w.startsWith(s):
          tmplist.add(w)
      autocompleteWords = tmplist
    else:
      autocompleteWords = @[]
  else:
    autocompleteWords = @[]
  viewUpdate()

proc selectWord(input_id: cstring, word: cstring, whole_replace: bool = true): proc() =
  result = proc() =
    let x = getVNodeById(input_id)
    var s = x.value
    if not s.isNil and s.len > 0:
      var input_elm = document.getElementById(input_id)
      var cur = input_elm.selectionStart
      var newcur = cur
      if whole_replace:
        var t = s.toJs.substr(0.toJs, cur).to(cstring).check_mnemonic_replace().split(" ".cstring).slice(-1)[0].to(cstring)
        if t.toJs.is(bool) and (t.toJs.length > 0.toJs).to(bool):
          s = (s.toJs.substr(0.toJs, cur - t.toJs.length) + word.toJs).to(cstring)
          newcur = s.toJs.length
        x.setInputText(s)
        editingWords = s
        input_elm.focus()
        input_elm.selectionStart = newcur
        input_elm.selectionEnd = newcur
      else:
        var t = s.toJs.substr(0.toJs, cur).to(cstring).check_mnemonic_replace().split(" ".cstring).slice(-1)[0].to(cstring)
        if t.toJs.is(bool) and (t.toJs.length > 0.toJs).to(bool):
          var tail = s.toJs.substr(cur) or "".toJs
          s = (s.toJs.substr(0.toJs, cur - t.toJs.length) + word.toJs + tail).to(cstring)
          newcur = s.toJs.length - tail.length
        x.setInputText(s)
        editingWords = s
        input_elm.focus()
        input_elm.selectionEnd = newcur
    autocompleteWords = @[]
    viewUpdate()

var confirm_mnemonic_advanced = false
proc confirmMnemonic(input_id: cstring, advance: bool): proc() =
  result = proc() =
    confirm_mnemonic_advanced = advance
    let x = getVNodeById(input_id)
    var s = x.value
    if not s.isNil and s.len > 0:
      var words: seq[cstring]
      inputWords = s.cstring.check_mnemonic_replace().trim().to(cstring)
      words = inputWords.toJs.split(" ".cstring).to(seq[cstring])
      chklist = @[]
      var idx: int = 0
      var allvalid = true
      for word in words:
        if wl_select.includes(cast[cstring](word)):
          if advance:
            let levs = cast[seq[cstring]](levens_one(word.toJs, bip39_wordlist))
            chklist.add (idx, word, true, levs)
          else:
            chklist.add (idx, word, true, @[])
        else:
          let levs = cast[seq[cstring]](levens(word.toJs, bip39_wordlist))
          chklist.add (idx, word, false, levs)
          allvalid = false
        inc(idx)
      if allvalid and idx >= 12 and idx mod 3 == 0:
        var bip39 = coinlibs.bip39
        if bip39.validateMnemonic(inputWords.toJs, bip39_wordlist).to(bool):
          mnemonicFulfill = true
        else:
          Notify.show(tr("Warning".cstring), tr("There are no misspellings, but some words seem to be wrong.".cstring).toJs + (if advance: "".cstring else: " ".cstring).toJs + tr("Try to use [Advanced Check]".cstring).toJs, Notify.msgtype.warning)
        if mnemonicFulfill:
          viewSelector(MnemonicFulfill)
    else:
      chklist = @[]
    autocompleteWords = @[]
    viewUpdate()

proc fix_word_test(c: JsObject): JsObject {.importcpp: "/[ 　\\n\\r]/.test(#)".} # /[ \u3000\n\r]/

proc fixWord(input_id: cstring, idx: int, word: cstring): proc() =
  result = proc() =
    let x = getVNodeById(input_id)
    var s = x.value
    if not s.isNil and s.len > 0:
      var ret = "".toJs
      var count = 0
      var find = false
      var skip = false
      for c in s.toJs:
        if fix_word_test(c).to(bool):
          ret += c
          if find:
            inc(count)
          find = false
          skip = false
        else:
          find = true
          if idx == count and skip == false:
            ret += word.toJs
            skip = true
          else:
            if not skip:
              ret += c
      x.setInputText(ret.to(cstring))
      editingWords = ret.to(cstring)
      confirmMnemonic(input_id, confirm_mnemonic_advanced)()

proc changeLanguage(ev: Event; n: VNode) =
  var langId = cast[int](n.value)
  if langId == 0:
    bip39_wordlist = bip39.wordlists.english
    wl_select = wl_english
    wl_select_id = 0
  elif langId == 1:
    bip39_wordlist = bip39.wordlists.japanese
    wl_select = wl_japanese
    wl_select_id = 1
  autocompleteWords = @[]
  chklist = @[]
  viewUpdate()

proc mnemonicEditor(): VNode =
  let input_id: cstring = "minput"
  result = buildHtml(tdiv):
    tdiv(class="ui clearing segment medit-seg"):
      tdiv(class="ui form"):
        tdiv(class="field"):
          label:
            text trans"Select mnemonic language"
          tdiv(class="ui selection dropdown"):
            input(type="hidden", name="mnemonic-language", value="1", onchange=changeLanguage)
            italic(class="dropdown icon")
            tdiv(class="default text"):
              text trans"Mnemonic Language"
            tdiv(class="menu"):
              tdiv(class="item", data-value="1"):
                text trans"Japanese"
              tdiv(class="item", data-value="0"):
                text trans"English"
        tdiv(class="field minput-field"):
          label:
            text trans"Import your mnemonic you already have"
          textarea(id=input_id, value=editingWords, onkeyup=checkMnemonic, onmouseup=checkMnemonic, spellcheck="false")
      button(class="ui right floated primary button", onclick=confirmMnemonic(input_id, false)):
        text trans"Check"
      button(class="ui right floated default button", onclick=confirmMnemonic(input_id, true)):
        text trans"Advanced Check"
    tdiv(class="medit-autocomp"):
      for word in autocompleteWords:
        button(class="ui mini teal label", onclick=selectWord(input_id, word)):
          text word
      for i in chklist.low..chklist.high:
        if chklist[i].flag:
          button(class="ui mini green label"):
            italic(class="check circle icon"):
              text " " & chklist[i].word
            for lev in chklist[i].levs:
              if chklist[i].word != lev:
                button(class="ui mini blue basic label", onclick=fixWord(input_id, chklist[i].idx, lev)):
                  text lev
        else:
          button(class="ui mini pink label"):
            italic(class="x icon"):
              text " " & chklist[i].word
            for lev in chklist[i].levs:
              button(class="ui mini blue basic label", onclick=fixWord(input_id, chklist[i].idx, lev)):
                text lev

proc seedCard(cardInfo: SeedCardInfo, idx: int): VNode =
  result = buildHtml(tdiv(class="ui card seed-card")):
    tdiv(class="image"):
      tdiv(class="seed-qrcode", data-orig=cardInfo.orig):
        canvas(width="188", height="188")
    tdiv(class="content"):
      if not cardInfo.tag.isNil:
        tdiv(class="ui tag label mini tag"): text cardInfo.tag
      tdiv(class="header"): text trans"Seed"
      tdiv(class="meta"):
        span(class="date"): text if not cardInfo.gen.isNil: cardInfo.gen else: trans"unknown"
      var clen = cardInfo.seed.len
      if clen > 0:
        var half = toInt(clen / 2)
        var seed = $cardInfo.seed
        var seed_upper = seed[0..<half]
        var seed_lower = seed[half..^1]
        seed_upper = seed_upper[0..3] & " " & seed_upper[4..7] & " " & seed_upper[8..11] & " " & seed_upper[12..15] & " " & seed_upper[16..19] & " " & seed_upper[20..^1]
        seed_lower = seed_lower[0..3] & " " & seed_lower[4..7] & " " & seed_lower[8..11] & " " & seed_lower[12..15] & " " & seed_lower[16..19] & " " & seed_lower[20..^1]
        tdiv(class="seed-body"):
          tdiv(class="seed"): text seed_upper
          tdiv(class="seed"): text seed_lower
      else:
        tdiv(class="seed-body"):
          clen = cardInfo.orig.len
          if clen > 20:
            var half = toInt(clen / 2)
            var orig = $cardInfo.orig
            tdiv(class="seed"): text orig[0..<half]
            tdiv(class="seed"): text orig[half..^1]
          else:
            tdiv(class="seed"): text cardInfo.orig
    tdiv(class="extra content"):
      tdiv(class="inline field"):
        tdiv(class="vector-label"): text trans"Seed Vector:"
        tdiv(class="ui mini input vector-input"):
          input(type="text", placeholder=trans"Type your seed vector", spellcheck="false"):
            proc onkeyup(ev: Event; n: Vnode) =
              seedCardInfos[idx].sv = n.value
    tdiv(class="bt-seed-del"):
      button(class="circular ui icon mini button", onclick=removeSeedCard(idx)):
        italic(class="close icon")

proc changePassphrase(ev: Event; n: VNode) =
  if passPhrase != n.value:
    passphraseFulfill = false
    showPage3 = false
    passPhrase = n.value
    viewUpdate()

proc confirmPassphrase(ev: Event; n: VNode) =
  var ret_lock: bool = false
  var passlen = 0
  var val = jq("""input[name="input-passphrase"]""".cstring).val()
  if val.to(bool):
    passlen = val.length.to(int)
    jq("""input[name="input-passphrase"]""".cstring).blur()
    var wallet = pastel.wallet
    ret_lock = wallet.lockShieldedKeys(jq("""input[name="input-passphrase"]""".cstring).val(), 2.toJs, true).to(bool)
  if passlen > 0:
    if ret_lock:
      passphraseFulfill = true
      showPage3 = true
      viewUpdate()
    else:
      Notify.show(tr("Error".cstring),tr("Failed to lock your wallet with the passphrase.".cstring), Notify.msgtype.error)

proc passphraseEditor(): VNode =
  result = buildHtml(tdiv):
    tdiv(class="ui clearing segment passphrase-seg"):
      tdiv(class="ui inverted segment"):
        h4(class="ui grey inverted header center"): text trans"Input passphrase"
        tdiv(class="ui form"):
          tdiv(class="field"):
            input(class="center", type="password", name="input-passphrase", value=passPhrase,
                  placeholder=trans"Passphrase", onkeyup=changePassphrase,
                  onkeyupenter=confirmPassphrase, spellcheck="false")
      button(class="ui right floated olive button", onclick=confirmPassphrase):
        text trans"Apply"

proc goSettings(): proc() =
  result = proc() =
    if not showPage4:
      viewSelector(WalletSettings, false)
      supressRedraw = true
      jq("#section4".cstring).show()
    else:
      TradeLogs.stop()
      jq(".backpage".cstring).visibility(JsObject{silent: true})
      jq("#tradeunconfs".cstring).empty()
      jq("#tradelogs".cstring).empty()
      viewSelector(WalletSettings, false)
      goSection("#section4".cstring)

proc goLogs(): proc() =
  result = proc() =
    if not showPage4:
      viewSelector(WalletLogs, false)
      supressRedraw = true
      jq("#section4".cstring).show()
    else:
      TradeLogs.stop()
      jq(".backpage".cstring).visibility(JsObject{silent: true})
      jq("#tradeunconfs".cstring).empty()
      jq("#tradelogs".cstring).empty()
      viewSelector(WalletLogs, false)
      goSection("#section4".cstring)

proc backWallet(): proc() =
  result = proc() =
    viewSelector(Wallet, true)
    goSection("#section3".cstring, page_scroll_done)

var send_balls_count = 0.toJs
var cur_calc_send_utxo = jsNull

proc conv_coin_replace(s: JsObject): JsObject {.importcpp: "#.replace(/0+$$/, '')".}

proc conv_coin(uint64_val: JsObject): JsObject =
  var strval = uint64_val.toString()
  var val = Number.parseInt(strval, 10.toJs)
  if (val > Number.MAX_SAFE_INTEGER).to(bool):
    var d = strval.slice(-8).conv_coin_replace()
    var n = strval.substr(0, strval.length - 8.toJs)
    if (d.length > 0.toJs).to(bool):
      return n + ".".toJs + d
    else:
      return n
  return val / 100000000.toJs

proc resetSendBallCount() =
  send_balls_count = 0.toJs
  cur_calc_send_utxo = jsNull
  jq("#btn-utxo-count".cstring).text("...".cstring)
  pastel.utxoballs.setSend(0)

proc setSendUtxo(value: JsObject) =
  var ret = pastel.wallet.calcSendUtxo(value)
  cur_calc_send_utxo = ret
  var amount_elm = jq("""#send-coins input[name="amount"]""".cstring)
  if ret.err.to(bool):
    if (ret.all > ret.max).to(bool):
      jq("#btn-utxo-count".cstring).text(">".toJs + String(ret.max) + " max".toJs)
      pastel.utxoballs.setSend(ret.max)
      send_balls_count = ret.max
    else:
      jq("#btn-utxo-count".cstring).text(">".toJs + String(ret.all) + " all".toJs)
      pastel.utxoballs.setSend(ret.all)
      send_balls_count = ret.all
    amount_elm.closest(".field".cstring).removeClass("warning".cstring)
    amount_elm.closest(".field".cstring).addClass("error".cstring)
  else:
    if (ret.count > ret.max).to(bool):
      jq("#btn-utxo-count".cstring).text(">".toJs + String(ret.max) + " max".toJs)
      pastel.utxoballs.setSend(ret.max)
      send_balls_count = ret.max
      amount_elm.closest(".field".cstring).removeClass("warning".cstring)
      amount_elm.closest(".field".cstring).addClass("error".cstring)
    else:
      amount_elm.closest(".field".cstring).removeClass("error".cstring)
      if not ret.conf.isNull() and (ret.count > ret.conf).to(bool) and (ret.count > 0.toJs).to(bool):
        amount_elm.closest(".field".cstring).addClass("warning".cstring)
      else:
        amount_elm.closest(".field".cstring).removeClass("warning".cstring)
      jq("#btn-utxo-count".cstring).text((if ret.sign == 0.toJs: "".toJs else: "≤".toJs) + String(ret.count) + (if ret.count == ret.all: " all".toJs else: "".toJs))
      pastel.utxoballs.setSend(ret.count)
      send_balls_count = ret.count

proc check_amount_elm_replace(s: JsObject): JsObject {.importcpp: "#.replace(/,/g, '')".}
proc check_amount_elm_match(s: JsObject): JsObject {.importcpp: "#.match(/^\\d+(\\.\\d{1,8})?$$/)".}

proc check_amount_elm() =
  var amount_elm = jq("""#send-coins input[name="amount"]""".cstring)
  var amount = amount_elm.val().trim()
  if (amount.length > 0.toJs).to(bool):
    amount = amount.check_amount_elm_replace()
    var amounts = amount.split(".".cstring)
    if amount.check_amount_elm_match().to(bool):
      amount_elm.closest(".field".cstring).removeClass("error warning".cstring)
      var value = "".toJs
      if amounts.length == 1.toJs:
        if amounts[0] != '0'.toJs:
          value = amounts[0] + "00000000".toJs
        else:
          value = amounts[0]
      elif amounts.length == 2.toJs:
        value = amounts[0] + (amounts[1] + "00000000".toJs).slice(0, 8)
      if (value.length > 0.toJs).to(bool):
        setSendUtxo(value)
      else:
        resetSendBallCount()
    else:
      amount_elm.closest(".field".cstring).addClass("error".cstring)
  else:
    amount_elm.closest(".field".cstring).removeClass("error warning".cstring)
    resetSendBallCount()

var sendrecv_switch = 0

proc updateBallCount() =
  if sendrecv_switch == 1:
    check_amount_elm()

pastel.utxoballs.updateSend(updateBallCount)

var uriOptions = [].toJs
var sendrecv_switch_sendafter: proc() = proc() = discard

proc initSendForm_amount_replace(s: JsObject): JsObject {.importcpp: "#.replace(/,/g, '')".}
proc initSendForm_match(s: JsObject): JsObject {.importcpp: "#.match(/^\\d+(\\.\\d{1,8})?$$/)".}

proc initSendForm() =
  jq("#btn-send-clear".cstring).off("click".cstring).click(proc() =
    if not showPage4:
      jq("""#send-coins input[name="address"]""".cstring).val("".cstring)
      jq("""#send-coins input[name="amount"]""".cstring).val("".cstring)
      jq("""#send-coins input[name="address"]""".cstring).closest(".field".cstring).removeClass("error".cstring)
      jq("""#send-coins input[name="amount"]""".cstring).closest(".field".cstring).removeClass("error".cstring)
      resetSendBallCount()
      uriOptions = [].toJs
      viewSelector(Wallet)
    jq(this).blur()
  )
  jq("#btn-send-qrcode".cstring).off("click".cstring).click(proc(evt: JsObject) =
    if not showPage4:
      qrReaderModal.show(proc(err, uri: JsObject) =
        if not err.to(bool):
          var data = bip21reader(uri)
          jq("""#send-coins input[name="address"]""".cstring).val(data.address or "".toJs)
          if not data.amount.isNull:
            jq("""#send-coins input[name="amount"]""".cstring).val(data.amount or "".toJs)
          uriOptions = [].toJs
          for k, p in data:
            if k == "address".cstring or k == "amount".cstring:
              continue
            var key = crlftab_to_html(k.toJs)
            key = key.charAt(0).toUpperCase() + key.slice(1)
            uriOptions.push(JsObject{key: key, value: crlftab_to_html(p)})
          check_amount_elm()
          viewSelector(Wallet)
        else:
          Notify.show(tr("Error".cstring), tr("Camera error. Please connect the camera and reload the page.".cstring), Notify.msgtype.error)
      )
    jq(this).blur()
  )
  jq("#btn-send-lock".cstring).off("click".cstring).click(proc() =
    var elm = jq(this)
    var icon = elm.find_js_native("i".toJs)
    if icon.hasClass("open".toJs).to(bool):
      if pastel.wallet.to(bool) and pastel.wallet.lockShieldedKeys().to(bool):
        icon.removeClass("open".cstring)
        elm.attr("title".cstring, "Locked".cstring)
        PhraseLock.notify_locked()
        PhraseLock.disableInactivity()
      discard setTimeout(proc() =
        elm.focus()
      , 1000)
    else:
      Notify.hide_all()
      PhraseLock.showPhraseInput(proc(status: JsObject) =
        if status == PhraseLock.PLOCK_SUCCESS:
          icon.addClass("open".cstring)
          elm.attr("title".cstring, tr("Unlocked".cstring))
          PhraseLock.notify_unlocked()
          var locked_flag = false
          PhraseLock.enableInactivity(proc() =
            if icon.hasClass("open".cstring).to(bool):
              if pastel.wallet.to(bool) and pastel.wallet.lockShieldedKeys().to(bool):
                locked_flag = true
          , proc() =
            if icon.hasClass("open".cstring).to(bool) and locked_flag:
              icon.removeClass("open".cstring)
              elm.attr("title".cstring, "Locked".cstring)
              if sendrecv_switch == 1:
                PhraseLock.notify_locked()
              else:
                sendrecv_switch_sendafter = proc() =
                  PhraseLock.notify_locked()
              PhraseLock.disableInactivity()
          )
        elif status == PhraseLock.PLOCK_FAILED_QR:
          Notify.show(tr("Error".cstring), tr("Failed to unlock. Wrong key card was scanned.".cstring), Notify.msgtype.error)
        elif status == PhraseLock.PLOCK_FAILED_PHRASE:
          Notify.show(tr("Error".cstring), tr("Failed to unlock. Passphrase is incorrect.".cstring), Notify.msgtype.error)
        elif status == PhraseLock.PLOCK_FAILED_CAMERA:
          Notify.show(tr("Error".cstring), tr("Failed to unlock. Camera error. Please connect the camera and reload the page.".cstring), Notify.msgtype.error)
        setTimeout(proc() =
          elm.focus()
        , 1000)
      )
  )
  pastel.utxoballs.setSend(send_balls_count)

  jq("#btn-utxo-plus".cstring).off("click".cstring).click(proc() =
    jq("""#send-coins input[name="amount"]""".cstring).closest(".field".cstring).removeClass("error".cstring)
    var cur = cur_calc_send_utxo
    if cur.to(bool):
      if cur.err.to(bool):
        cur.count = Math.min(cur.all, cur.max)
        cur.sign = 0
        cur.err = 0
      else:
        if cur.sign == 0.toJs:
         discard  ++(cur.count)
        else:
          cur.sign = 0
    else:
      cur = JsObject{err: 0, count: 1, sign: 0}
      cur_calc_send_utxo = cur
    var sendval = pastel.wallet.calcSendValue(cur.count)
    cur.all = sendval.all
    cur.max = sendval.max
    cur.count = sendval.count
    send_balls_count = cur.count
    pastel.utxoballs.setSend(send_balls_count)
    jq("""#send-coins input[name="amount"]""".cstring).val(conv_coin(sendval.value))
    if not sendval.conf.isNull and (cur.count > sendval.conf).to(bool) and (cur.count > 0.toJs).to(bool):
      jq("""#send-coins input[name="amount"]""".cstring).closest(".field".cstring).addClass("warning".cstring)
    else:
      jq("""#send-coins input[name="amount"]""".cstring).closest(".field".cstring).removeClass("warning".cstring)
    var exinfo = "".toJs
    if sendval.count == sendval.all:
      exinfo = " all".toJs
    elif sendval.count == sendval.max:
      exinfo = " max".toJs
    jq("#btn-utxo-count").text(String(sendval.count) + exinfo)
    jq(this).blur()
  )
  jq("#btn-utxo-minus".cstring).off("click".cstring).click(proc() =
    jq("""#send-coins input[name="amount"]""".cstring).closest(".field".cstring).removeClass("error".cstring)
    var cur = cur_calc_send_utxo
    if cur.to(bool):
      if cur.err.to(bool):
        cur.count = Math.min(cur.all, cur.max)
        cur.sign = 0
        cur.err = 0
      else:
        if (cur.sign <= 0.toJs).to(bool):
          if (cur.count > 0.toJs).to(bool):
            discard --(cur.count)
        cur.sign = 0
    else:
      cur = JsObject{err: 0, count: 0, sign: 0}
      cur_calc_send_utxo = cur
    var sendval = pastel.wallet.calcSendValue(cur.count)
    cur.all = sendval.all
    cur.max = sendval.max
    cur.count = sendval.count
    send_balls_count = cur.count
    pastel.utxoballs.setSend(send_balls_count)
    jq("""#send-coins input[name="amount"]""".cstring).val(conv_coin(sendval.value))
    if not sendval.conf.isNull and (cur.count > sendval.conf).to(bool) and (cur.count > 0.toJs).to(bool):
      jq("""#send-coins input[name="amount"]""".cstring).closest(".field".cstring).addClass("warning".cstring)
    else:
      jq("""#send-coins input[name="amount"]""".cstring).closest(".field".cstring).removeClass("warning".cstring)
    var exinfo = "".toJs
    if sendval.count == sendval.all:
      exinfo = " all".toJs
    elif sendval.count == sendval.max:
      exinfo = " max".toJs
    jq("#btn-utxo-count".cstring).text(String(sendval.count) + exinfo)
    jq(this).blur()
  )
  var send_busy = false
  jq("#btn-tx-send".cstring).off("click".cstring).click(proc() =
    if send_busy:
      return
    send_busy = true
    var locked = PhraseLock.notify_if_need_unlock()
    if not locked.to(bool) and pastel.wallet.to(bool):
      var address = String(jq("""#send-coins input[name="address"]""".cstring).val()).trim()
      var amount = String(jq("""#send-coins input[name="amount"]""".cstring).val()).trim()
      if address.length == 0.toJs or amount.length == 0.toJs:
        var address_elm = jq("""#send-coins input[name="address"]""".cstring).closest(".field".cstring)
        var amount_elm = jq("""#send-coins input[name="amount"]""".cstring).closest(".field".cstring)
        var flag = true
        var alert_count = 0
        proc alert_worker() =
          if address.length == 0.toJs:
            if flag:
              address_elm.addClass("error".cstring)
            else:
              address_elm.removeClass("error".cstring)
          if amount.length == 0.toJs:
            if flag:
              amount_elm.addClass("error".cstring)
            else:
              amount_elm.removeClass("error".cstring)
          inc(alert_count)
          if alert_count < 4:
            flag = not flag
            setTimeout(alert_worker, 100)
        alert_worker()
        return
      amount = amount.initSendForm_amount_replace()
      var amounts = amount.split(".".cstring)
      if amount.initSendForm_match().to(bool):
        var value = "".toJs
        if amounts.length == 1.toJs:
          if amounts[0] != '0'.toJs:
            value = amounts[0] + "00000000".toJs
          else:
            value = amounts[0]
        elif amounts.length == 2.toJs:
          value = amounts[0] + (amounts[1] + "00000000".toJs).slice(0, 8)
        Notify.hide_all()
        var self = jq(this)
        jq("#btn-tx-send".cstring).addClass("loading".cstring)
        pastel.wallet.send(address, value, proc(result: JsObject) =
          var ErrSend = pastel.wallet.ERR_SEND
          if result.err == ErrSend.SUCCESS:
            Notify.show("".cstring, tr("Coins sent successfully.".cstring), Notify.msgtype.info)
            pastel.unspents_after_actions.push(proc() =
              if sendrecv_switch == 1:
                setSendUtxo(value)
            )
          elif result.err == ErrSend.FAILED:
            Notify.show(tr("Error".cstring), tr("Failed to send coins.".cstring), Notify.msgtype.error)
          elif result.err == ErrSend.INVALID_ADDRESS:
            Notify.show(tr("Error".cstring), tr("Address is invalid.".cstring), Notify.msgtype.error)
          elif result.err == ErrSend.INSUFFICIENT_BALANCE:
            Notify.show(tr("Error".cstring), tr("Balance is insufficient.".cstring), Notify.msgtype.error)
          elif result.err == ErrSend.DUST_VALUE:
            if value == "0".toJs:
              Notify.show(tr("Error".cstring), tr("Amount is zero.".cstring), Notify.msgtype.error)
            else:
              Notify.show(tr("Error".cstring), tr("Amount is too small.".cstring), Notify.msgtype.error)
          elif result.err == ErrSend.BUSY:
            Notify.show(tr("Error".cstring), tr("Failed to send coins. Busy.".cstring), Notify.msgtype.error)
          elif result.err == ErrSend.TX_FAILED:
            var msg = "".toJs
            if result.res.to(bool) and result.res.message.to(bool):
              msg = "<br> [".toJs + result.res.message + "]".toJs
            Notify.show(tr("Error".cstring), tr("Failed to send coins.".cstring).toJs + msg, Notify.msgtype.error)
          elif result.err == ErrSend.TX_TIMEOUT:
            Notify.show(tr("Warning".cstring), tr("Server is not responding. Coins may have been sent.".cstring), Notify.msgtype.warning)
          elif result.err == ErrSend.SERVER_ERROR:
            Notify.show(tr("Error".cstring), tr("Failed to send coins. Server error.".cstring), Notify.msgtype.error)
          elif result.err == ErrSend.SERVER_TIMEOUT:
            Notify.show(tr("Error".cstring), tr("Failed to send coins. Server is not responding.".cstring), Notify.msgtype.error)
          else:
            Notify.show(tr("Error".cstring), tr("Failed to send coins.".cstring), Notify.msgtype.error)
          jq("#btn-tx-send".cstring).removeClass("loading".cstring)
          self.blur()
          send_busy = false
        )
      else:
        if (amounts.length > 1.toJs).to(bool) and (amounts[1].length > 8.toJs).to(bool):
          Notify.show(tr("Error".cstring), tr("Amount is invalid. The decimal places is too long. Please set it 8 or less.".cstring), Notify.msgtype.error)
        else:
          Notify.show(tr("Error".cstring), tr("Amount is invalid.".cstring), Notify.msgtype.error)
        send_busy = false
        jq(this).blur()
    else:
      jq("#btn-send-lock".cstring).focus()
      send_busy = false
  )

#var sendrecv_switch = 0
var sendrecv_switch_busy = false
var sendrecv_switch_tval: int
var sendrecv_last = -1
var sendrecv_wait = 0
#var sendrecv_switch_sendafter = function() {}
proc send_switch() =
  sendrecv_switch_busy = true
  if sendrecv_last == 2:
    jq("#receive-address".cstring).transition(JsObject{
      animation: "fade down".cstring,
      onComplete : proc() =
        jq("#send-coins".cstring).transition(JsObject{
          animation: "fade down".cstring,
          onComplete : proc() =
            sendrecv_last = 1
            sendrecv_switch_busy = false
            sendrecv_switch_sendafter()
        })
        initSendForm()
    })
  else:
    jq("#send-coins".cstring).transition(JsObject{
      animation: "fade down".cstring,
      onComplete : proc() =
        sendrecv_last = 1
        sendrecv_switch_busy = false
        sendrecv_switch_sendafter()
    })
    initSendForm()
proc recv_switch() =
  sendrecv_switch_busy = true
  if sendrecv_last == 1:
    jq("#send-coins".cstring).transition(JsObject{
      animation: "fade down".cstring,
      onComplete : proc() =
        showRecvAddress(proc() =
          jq("#receive-address".cstring).transition(JsObject{
            animation: "fade down".cstring,
            onComplete : proc() =
              showRecvAddressAfterEffect()
              sendrecv_last = 2
              sendrecv_switch_busy = false
          })
        )
    })
  else:
    showRecvAddress(proc() =
      jq("#receive-address".cstring).transition(JsObject{
        animation: "fade down".cstring,
        onComplete : proc() =
          showRecvAddressAfterEffect()
          sendrecv_last = 2
          sendrecv_switch_busy = false
      })
    )
proc reset_switch(switch_id: int = -1) =
  if not jq("#send-coins".cstring).hasClass("hidden".cstring).to(bool) and (switch_id == -1 or switch_id == 1):
    sendrecv_switch_busy = true
    if switch_id == 1:
      pastel.utxoballs.setSend(0)
    jq("#send-coins".cstring).transition(JsObject{
      animation: "fade down".cstring,
      onComplete : proc() =
        sendrecv_last = 0
        sendrecv_switch_busy = false
    })
  if not jq("#receive-address".cstring).hasClass("hidden".cstring).to(bool) and (switch_id == -1 or switch_id == 2):
    sendrecv_switch_busy = true
    jq("#receive-address".cstring).transition(JsObject{
      animation: "fade down".cstring,
      onComplete : proc() =
        sendrecv_last = 0
        sendrecv_switch_busy = false
    })
proc sendrecv_switch_worker() =
  if sendrecv_switch_busy:
    sendrecv_switch_tval = setTimeout(proc() =
      inc(sendrecv_wait)
      if sendrecv_wait < 300:
        sendrecv_switch_worker()
      else:
        sendrecv_switch_busy = false
    , 50)
    return
  sendrecv_wait = 0
  if sendrecv_last == sendrecv_switch:
    return
  if sendrecv_switch == 1:
    send_switch()
  elif sendrecv_switch == 2:
    recv_switch()
  else:
    reset_switch()
proc sendrecv_select(val: int) =
  clearTimeout(sendrecv_switch_tval)
  if sendrecv_switch == 1 and val != 1:
    pastel.utxoballs.setSend(0)
  sendrecv_switch = val
  sendrecv_switch_worker()

proc enable_caret_browsing(elm: JsObject) =
  elm.find_js_native(".tabindex:not(:hidden), button:not(:hidden), a:not(:hidden), textarea:not(:hidden), input:not(:hidden)".toJs).each(proc(idx, val: JsObject) =
    jq(val).attr("tabindex".cstring, jq(val).data("tabindex".cstring) or 0.toJs)
  )
  jq("#selectlang .tabindex, #receive-address .tabindex".cstring).each(proc(idx, val: JsObject) =
    jq(val).attr("tabindex".cstring, jq(val).data("tabindex".cstring) or 0.toJs)
  )
proc disable_caret_browsing(elm: JsObject) =
  elm.find_js_native(".tabindex:not(:hidden), button:not(:hidden), a:not(:hidden), textarea:not(:hidden), input:not(:hidden)".toJs).each(proc(idx, val: JsObject) =
    jq(val).attr("tabindex".cstring, -1)
  )
  jq("#selectlang .tabindex, #receive-address .tabindex".cstring).each(proc(idx, val: JsObject) =
    jq(val).attr("tabindex".cstring, -1)
  )

proc btnSend: proc() =
  result = proc() =
    if not pastel.wallet.to(bool) or  not pastel.utxoballs.to(bool):
      return
    sendrecv_select(if sendrecv_switch == 1: 0 else: 1)
    document.getElementById("btn-send".cstring).blur()

proc btnReceive: proc() =
  result = proc() =
    if not pastel.wallet.to(bool) or not pastel.utxoballs.to(bool):
      return
    sendrecv_select(if sendrecv_switch == 2: 0 else: 2)
    document.getElementById("btn-receive".cstring).blur()

proc btnSendClose: proc() =
  result = proc() =
    clearTimeout(sendrecv_switch_tval)
    sendrecv_switch = 0
    reset_switch(1)

proc btnRecvClose: proc() =
  result = proc() =
    clearTimeout(sendrecv_switch_tval)
    sendrecv_switch = 0
    reset_switch(2)

proc recvAddressSelector(): VNode =
  result = buildHtml(tdiv(id="receive-address", class="ui center aligned segment hidden")):
    tdiv(class="ui top attached label recvaddress"):
      text trans"Receive Address" & " "
      span:
        italic(class="close icon btn-close", onclick=btnRecvClose())
    tdiv(class="ui mini basic icon buttons"):
      button(id="btn-recv-copy", class="ui button", title=trans"Copy"):
        italic(class="paperclip icon")
      button(id="btn-recv-qrcode", class="ui button", title=trans"Create QR Code"):
        italic(class="qrcode icon")
    tdiv(id="address-text", class="address"): text ""
    tdiv(class="balls"):
      tdiv(class="used"):
        tdiv(class="circular ui icon mini button ball"): img(src="")
      tdiv(class="new"):
        tdiv(class="circular ui icon mini button ball"): img(src="")
        tdiv(class="circular ui icon mini button ball"): img(src="")
        tdiv(class="circular ui icon mini button ball"): img(src="")
        tdiv(class="circular ui icon mini button ball"): img(src="")
        tdiv(class="circular ui icon mini button ball"): img(src="")

proc recvAddressModal(): VNode =
  result = buildHtml(tdiv(id="recv-modal", class="ui")):
    italic(class="close icon btn-close-arc")
    tdiv(class="close-arc", tabindex="0")
    tdiv(id="recv-qrcode", class="qrcode", title=""):
      canvas(width="0", height="0")
    tdiv(id="recvaddr-form", class="ui container"):
      tdiv(class="ui form"):
        tdiv(class="field"):
          label: text trans"Receive Address"
          tdiv(class="ui selection dropdown addr-selection", tabindex="0"):
            input(type="hidden", name="address", value="")
            italic(class="dropdown icon")
            tdiv(class="text"):
              img(clsss="ui mini avatar image", src="")
              text ""
            tdiv(class="menu", tabindex="-1", data-tabindex="-1")
        tdiv(class="field"):
          label: text trans"Amount"
          tdiv(class="ui right labeled input"):
            input(class="right", type="text", name="amount", placeholder=trans"Amount", spellcheck="false")
            tdiv(class="ui basic label"): text "ZNY"
        tdiv(class="field"):
          label: text trans"Label"
          input(class="ui input", type="text", name="label", placeholder=trans"Label")
        tdiv(class="field"):
          label: text trans"Message"
          textarea(class="ui textarea", rows="2", name="message", placeholder=trans"Message")

proc check_send_amount_replace(s: JsObject): JsObject {.importcpp: "#.replace(/,/g, '')".}
proc check_send_amount_match(s: JsObject): JsObject {.importcpp: "#.match(/^\\d+(\\.\\d{1,8})?$$/)".}

proc checkSendAmount(ev: Event; n: VNode) =
  var s = n.value
  var amount = String(s.toJs).trim()
  var amount_elm = jq("""#send-coins input[name="amount"]""".cstring)
  if (amount.length > 0.toJs).to(bool):
    amount = amount.check_send_amount_replace()
    var amounts = amount.split(".".cstring)
    if amount.check_send_amount_match().to(bool):
      amount_elm.closest(".field".cstring).removeClass("error warning".cstring)
      var value = "".toJs
      if amounts.length == 1.toJs:
        if amounts[0] != '0'.toJs:
          value = amounts[0] + "00000000".toJs
        else:
          value = amounts[0]
      elif amounts.length == 2.toJs:
        value = amounts[0] + (amounts[1] + "00000000".toJs).slice(0, 8)
      if (value.length > 0.toJs).to(bool):
        setSendUtxo(value)
      else:
        resetSendBallCount()
    else:
      amount_elm.closest(".field".cstring).addClass("error".cstring)
  else:
    amount_elm.closest(".field".cstring).removeClass("error warning".cstring)
    resetSendBallCount()

proc sendForm(): VNode =
  result = buildHtml(tdiv(id="send-coins", class="ui center aligned segment hidden")):
    tdiv(class="ui top attached label sendcoins"):
      text trans"Send Coins" & " "
      span:
        italic(class="close icon btn-close", onclick=btnSendClose())
    tdiv(class="ui right floated mini basic icon buttons"):
      button(id="btn-send-lock", class="ui button", title=trans"Locked"):
        italic(class="lock icon")
    tdiv(class="ui mini basic icon buttons btn-send-tools"):
      button(id="btn-send-clear", class="ui button", title=trans"Clear"):
        italic(class="eraser icon")
      button(id="btn-send-qrcode", class="ui button", title=trans"Scan QR Code"):
        italic(class="camera icon")
    tdiv(class="ui form"):
      tdiv(class="field"):
        label: text trans"Send Address"
        tdiv(class="ui small input"):
          input(class="center", type="text", name="address", placeholder=trans"Address", spellcheck="false")
      tdiv(class="field"):
        label: text trans"Amount"
        tdiv(class="ui small input"):
          input(class="center", type="text", name="amount", placeholder=trans"Amount",
                onkeyup=checkSendAmount, spellcheck="false")
          tdiv(class="ui mini basic icon buttons utxoctrl"):
            button(id="btn-utxo-minus", class="ui button", title=trans"-1 Ball"):
              italic(class="minus circle icon")
            button(id="btn-utxo-count", class="ui button sendutxos", tabindex="-1", data-tabindex="-1"):
              text "..."
            button(id="btn-utxo-plus", class="ui button", title=trans"+1 Ball"):
              italic(class="plus circle icon")
      tdiv(class="ui list uri-options"):
        for d in uriOptions:
          tdiv(class="item"):
            tdiv(class="content"):
              tdiv(class="header"): text trans($cast[cstring](d.key))
              tdiv(class="description"): text cast[cstring](d.value)
      tdiv(class="fluid ui buttons"):
        button(id="btn-tx-send", class="ui inverted olive button center btn-tx-send"):
          text trans"Send"

#[
proc qrCodeModal(): Vnode =
  result = buildHtml(tdiv(id="qrcode-modal", class="ui basic modal")):
    italic(class="close icon def-close")
    tdiv(class="ui icon header"): text "Scan QR Code"
    tdiv(class="scrolling content"):
      tdiv(id="qrreader-seg", class="ui center aligned segment"):
        tdiv(class="qr-scanning"):
          tdiv()
          tdiv()
        tdiv(class="ui small basic icon buttons camtools"):
          button(class="ui button btn-camera"):
            italic(class="camera icon")
          button(class="ui button btn-close"):
            italic(class="window close icon")
        canvas(id="qrcanvas-modal", width="0", height="0")
        tdiv(class="ui dimmer qrcamera-loader"):
          tdiv(class="ui indeterminate text loader"):
            text "Preparing Camera"
        tdiv(class="ui dimmer qrcamera-shutter")
    tdiv(class="actions"):
      tdiv(class="ui basic cancel inverted button"):
        italic(class="remove icon")
        text "Cancel"
]#

proc settingsModal(): VNode =
  result = buildHtml(tdiv(id="settings-modal", class="ui basic modal")):
    tdiv(class="ui icon header"):
      italic(class="trash icon")
      text trans"Reset Wallet"
    tdiv(class="content"):
      p: text trans"Are you sure to reset your wallet?"
    tdiv(class="actions"):
      button(class="ui basic cancel inverted button"):
        italic(class="remove icon")
        text trans"Cancel"
      button(class="ui red ok inverted button"):
        italic(class="checkmark icon")
        text trans"Reset"

proc settingsPage(): VNode =
  result = buildHtml(tdiv(id="settings", class="ui container")):
    h3(class="ui dividing header"): text trans"Settings"
    button(id="btn-reset", class="ui inverted red button"): text trans"Reset Wallet"
    tdiv(class="ui pink inverted segment"):
      text trans"""
Delete all your wallet data in your web browser, including your encrypted secret keys.
 If you have coins in your wallet or waiting for receiving coins, make sure you have the seed cards
 or mnemonics before deleting it. Otherwise you may lost your coins forever.
"""
    tdiv(class="ui checkbox"):
      input(type="checkbox", name="confirm")
      label: text trans"I confirmed that I have the seed cards or mnemonics or no coins in my wallet."

proc appMain(data: RouterData): VNode =
  result = buildHtml(tdiv):
    if showPage1:
      section(id="section1", class="section"):
        tdiv(class="intro"):
          tdiv(class="intro-head"):
            tdiv(class="caption"): text "Pastel Wallet"
            tdiv(class="ui container method-selector"):
              tdiv(class="title"): text trans"Scan your seed cards or input your mnemonic to start."
              tdiv(class="ui buttons"):
                button(id="seedselector", class="ui olive button", onclick=importSelector(ImportType.SeedCard)):
                  italic(class="qrcode icon")
                  text trans"Seed card"
                tdiv(class="or")
                button(id="mnemonicselector", class="ui grey button", onclick=importSelector(ImportType.Mnemonic)):
                  italic(class="list alternate icon")
                  text trans"Mnemonic"
          tdiv(class="intro-body"):
            if currentImportType == ImportType.SeedCard:
              tdiv(id="seed-seg", class="ui left aligned segment seed-seg"):
                if showScanResult:
                  tdiv(class="ui link cards seed-card-holder", id="seed-card-holder"):
                    for idx, seedCardInfo in seedCardInfos:
                      seedCard(seedCardInfo, idx)
                    tdiv(class="seed-add-container"):
                      button(class="circular ui icon button bt-add-seed", onclick=showSeedQr()):
                        italic(class="plus icon")
                  a(class="pagenext", href="#section2"):
                    span()
                    text trans"Next"
                if showScanning:
                  tdiv(class="qr-scanning"):
                    tdiv()
                    tdiv()
                if showScanSeedBtn:
                  button(class="ui teal labeled icon button bt-scan-seed", onclick=showSeedQr()):
                    text trans"Scan seed card with camera"
                    italic(class="camera icon")
                if showCamTools:
                  tdiv(class="ui small basic icon buttons camtools"):
                    button(class="ui button", onclick=camChange()):
                      italic(class="camera icon")
                    button(class="ui button", onclick=camClose()):
                      italic(class="window close icon")
                canvas(id="qrcanvas")
                tdiv(class="ui dimmer qrcamera-loader"):
                  tdiv(class="ui indeterminate text loader"):
                    text trans"Preparing Camera"
                tdiv(class="ui dimmer qrcamera-shutter")
            else:
              tdiv(class="ui left aligned segment mnemonic-seg"):
                mnemonicEditor()
                if mnemonicFulfill:
                  a(class="pagenext", href="#section2"):
                      span()
                      text trans"Next"
    if showPage2:
      section(id="section2", class="section"):
        tdiv(class="intro"):
          tdiv(class="intro-head"):
            tdiv(class="caption"): text "Pastel Wallet"
            tdiv(class="ui container method-selector"):
              tdiv(class="title"):
                text trans"""
A key card or passphrase is required to encrypt and save the private key in your browser.
 You will need it before sending your coins.
"""
              tdiv(class="ui buttons"):
                button(id="keyselector", class="ui olive button", onclick=protectSelector(ProtectType.KeyCard)):
                  italic(class="qrcode icon")
                  text trans"Key card"
                tdiv(class="or")
                button(id="passselector", class="ui grey button", onclick=protectSelector(ProtectType.Passphrase)):
                  italic(class="list alternate icon")
                  text trans"Passphrase"
          tdiv(class="intro-body"):
            if currentProtectType == ProtectType.KeyCard:
              tdiv(id="seed-seg", class="ui left aligned segment seed-seg"):
                if showScanResult2:
                  tdiv(class="ui clearing segment keycard-seg"):
                    tdiv(class="ui inverted segment"):
                      h4(class="ui grey inverted header center"): text trans"Scanned key card"
                      p(class="center"): text keyCardVal
                    button(class="ui right floated olive button", onclick=confirmKeyCard):
                      text trans"Apply"
                    button(class="ui right floated grey button", onclick=showKeyQr()):
                      text trans"Rescan"
                if keyCardFulfill:
                  a(class="pagenext", href="#section3"):
                    span()
                    text trans"Next"
                if showScanning2:
                  tdiv(class="qr-scanning"):
                    tdiv()
                    tdiv()
                if showScanSeedBtn2:
                  button(class="ui teal labeled icon button bt-scan-seed", onclick=showKeyQr()):
                    text trans"Scan key card with camera"
                    italic(class="camera icon")
                if showCamTools2:
                  tdiv(class="ui small basic icon buttons camtools"):
                    button(class="ui button", onclick=camChange()):
                      italic(class="camera icon")
                    button(class="ui button", onclick=camClose()):
                      italic(class="window close icon")
                canvas(id="qrcanvas")
                tdiv(class="ui dimmer qrcamera-loader"):
                  tdiv(class="ui indeterminate text loader"):
                    text trans"Preparing Camera"
                tdiv(class="ui dimmer qrcamera-shutter")
            else:
              tdiv(class="ui left aligned segment mnemonic-seg"):
                passphraseEditor()
                if passphraseFulfill:
                  a(class="pagenext", href="#section3"):
                      span()
                      text trans"Next"
    if showPage3:
      section(id="section3", class="section"):
        tdiv(class="intro"):
          tdiv(class="intro-head wallet-head"):
            tdiv(class="caption"): text "Pastel Wallet"
            tdiv(class="ui container wallet-btns"):
              tdiv(class="two ui basic buttons sendrecv"):
                button(id="btn-send", class="ui small button send", onclick=btnSend()):
                  italic(class="counterclockwise rotated sign-out icon send")
                  text " " & trans"Send"
                button(id="btn-receive", class="ui small button receive", onclick=btnReceive()):
                  italic(class="clockwise rotated sign-in icon receive")
                  text " " & trans"Receive"
          tdiv(class="intro-body wallet-body"):
            tdiv(id="wallet-balance", class="ui center aligned segment"):
              tdiv(class="ui top left attached tiny label send"):
                span:
                  text "0"
                text " "
                italic(class="counterclockwise rotated sign-out icon")
              tdiv(class="ui top right attached tiny label receive"):
                italic(class="clockwise rotated sign-in icon")
                span:
                  text "0"
              tdiv(class="balance"):
                text "0"
              tdiv(class="ui bottom right attached tiny label symbol"): text "ZNY"
            if showRecvAddressSelector:
              recvAddressSelector()
            if showRecvAddressModal:
              recvAddressModal()
            sendForm()
            #qrCodeModal()
            tdiv(id="ball-info", class="ui center aligned segment"):
              text ""
              br()
              text ""
            tdiv(id="wallet-seg", class="ui center aligned segment seed-seg"):
              canvas(width="0", height="0")
          tdiv(class="ui two bottom attached buttons settings"):
            button(class="ui button", onclick=goSettings()):
              italic(class="cog icon")
              text trans"Settings"
              span: italic(class="chevron down icon")
            button(class="ui button", onclick=goLogs()):
              italic(class="list alternate outline icon")
              text trans"Logs"
              span: italic(class="chevron down icon")
            tdiv(id="bottom-blink")
        textarea(id="clipboard", rows="1", tabindex="-1", data-tabindex="-1", readOnly="true", spellcheck="false")

    if showPage3 or showPage4:
      section(id="section4", class="tradelogs-section"):
        tdiv(class="ui buttons settings backpage"):
          button(class="ui button backwallet", onclick=backWallet()):
            italic(class="dot circle icon")
            text trans"Back"
            span: italic(class="chevron up icon")
        if showTradeLogs:
          tdiv(class="ui container"):
            tdiv(id="tradeunconfs", class="ui cards tradelogs")
            tdiv(id="tradelogs", class="ui cards tradelogs")
        if showSettings:
          settingsPage()
          settingsModal()

proc afterScript(data: RouterData) =
  jq(".ui.dropdown").dropdown()
  if showScanResult:
    proc seedCardQrUpdate(vivid: bool = false) =
      jq(".seed-qrcode".cstring).each(proc(idx, val: JsObject) =
        jq(val).find_js_native("canvas".cstring).remove()
        var fillcolor: JsObject
        var fillStyleFn = proc(ctx: JsObject): JsObject = discard
        if jq(val).hasClass("active".cstring).to(bool):
          fillcolor = if vivid: "#000".toJs else: "#7f7f7f".toJs
          if not vivid:
            fillStyleFn = proc(ctx: JsObject): JsObject =
              var w = ctx.canvas.width
              var h = ctx.canvas.height
              var grd = ctx.createLinearGradient(0, 0, w, h)
              grd.addColorStop(0, "#666".cstring)
              grd.addColorStop(0.3, "#aaa".cstring)
              grd.addColorStop(1, "#555".cstring)
              return grd
        else:
          fillcolor = "#f8f8f8".toJs
        jq(val).qrcode(JsObject{
          render: "canvas".cstring,
          ecLevel: "Q".cstring,
          radius: 0.39,
          text: jq(val).data("orig".cstring),
          size: 188,
          mode: 2,
          label: "",
          fontname: "sans".cstring,
          fontcolor: "#393939".cstring,
          fill: fillcolor,
          fillStyleFn: fillStyleFn
        })
      )
    if not jq(".seed-qrcode .active".cstring).length.to(bool):
      jq(".seed-qrcode".cstring).last().addClass("active".cstring)
    seedCardQrUpdate()

    jq(".seed-card".cstring).off("click".cstring).on("click".cstring, proc(evt: JsObject) =
      jq(".seed-card".cstring).not(evt.currentTarget).each(proc(idx, val: JsObject) =
        jq(val).find_js_native(".seed-qrcode".cstring).removeClass("active".cstring)
      )
      jq(evt.currentTarget).find_js_native(".seed-qrcode".cstring).addClass("active".cstring)
      seedCardQrUpdate(true)
    )
    jq(".seed-card".cstring).off("mouseleave".cstring).mouseleave(proc() =
      jq(".seed-qrcode".cstring).addClass("active".cstring)
      seedCardQrUpdate()
    )
    var holder = document.getElementById("seed-card-holder".cstring)
    if holder.to(bool):
      holder.scrollLeft = holder.scrollWidth - holder.clientWidth

  if showScanResult or mnemonicFulfill:
    disable_caret_browsing(jq("#section2".cstring))
    target_page_scroll = "#section2".cstring
    page_scroll_done = proc() =
      jq("a.pagenext".cstring).css("visibility".cstring, "hidden".cstring)
      jq("#section1".cstring).hide()
      enable_caret_browsing(jq("#section2".cstring))
      window.scrollTo(0, 0)
      seedToKeys()
      viewSelector(SetPassphrase)
      page_scroll_done = proc() = discard
  if keyCardFulfill or passphraseFulfill:
    disable_caret_browsing(jq("#section3".cstring))
    target_page_scroll = "#section3".cstring
    page_scroll_done = proc() =
      var wallet = pastel.wallet
      var ret = wallet.lockShieldedKeys()
      if not ret.to(bool):
        Notify.show(tr("Error".cstring), tr("Failed to lock keys.".cstring), Notify.msgtype.error)
      clearSensitive()
      jq("a.pagenext".cstring).css("visibility".cstring, "hidden".cstring)
      jq("#section2".cstring).hide()
      enable_caret_browsing(jq("#section3".cstring))
      window.scrollTo(0, 0)
      viewSelector(Wallet)
      if pastel.stream.to(bool) and not pastel.stream.status().to(bool):
        pastel.stream.start()
      page_scroll_done = proc() = discard
  if showScanResult or mnemonicFulfill or keyCardFulfill or passphraseFulfill:
    for ev in registerEventList:
      ev.elm.removeEventListener(ev.type_js_native, ev.cb)
    var elms = document.querySelectorAll("a.pagenext".cstring)
    Array.prototype.forEach.call(elms, proc(elm: JsObject) =
      var href = elm.getAttribute("href".cstring)
      if href.to(bool) and href.startsWith("#".cstring).to(bool):
        var cb = proc(e: JsObject) =
          e.preventDefault()
          var href = this.getAttribute("href".cstring)
          if href == "#section2".toJs:
            goSection(href.to(cstring), page_scroll_done)
          elif href == "#section3".toJs:
            goSection(href.to(cstring), page_scroll_done)
        registerEventList.push(JsObject{elm: elm, type: "click".cstring, cb: cb})
        elm.addEventListener("click".cstring, cb)
    )

  if showPage2 and not passphraseFulfill:
    jq("""input[name="input-passphrase"]""".cstring).focus()

  if showPage4:
    pastel.utxoballs.pause()
    #$.fn.visibility.settings.silent = true
    jq(".backpage".cstring).visibility(JsObject{
      type: "fixed".toJs,
      offset: 0
    })
    if showTradeLogs:
      TradeLogs.start()
    if showSettings:
      Settings.init()
    goSection("#section4".cstring, proc() =
      disable_caret_browsing(jq("#section3".cstring))
      target_page_scroll = "#section3".cstring
      page_scroll_done = proc() =
        TradeLogs.stop()
        jq(".backpage".cstring).visibility(JsObject{silent: true})
        jq("#tradeunconfs".cstring).empty()
        jq("#tradelogs".cstring).empty()
        jq("#section4".cstring).hide()
        enable_caret_browsing(jq("#section3".cstring))
        window.scrollTo(0, 0)
        setSupressRedraw(false)
        reloadViewSafeStart()
        viewSelector(Wallet)
        page_scroll_done = proc() = discard
        pastel.utxoballs.resume()
        showPage4 = false
        jq("#bottom-blink".cstring).fadeIn(100).fadeOut(400)
    )
  else:
    jq("#section4".cstring).hide()

  if showPage3 or showPage4:
    reloadViewSafeEnd()

var walletSetup = false
var stor = newStor()
var xpubs = stor.get_xpubs()
stor = jsNull
if xpubs.length.to(int) > 0:
  walletSetup = true
  proc check_stream_ready() =
    setTimeout(proc() =
      if pastel.stream.to(bool) and not pastel.stream.status().to(bool):
        pastel.stream.start()
      else:
        check_stream_ready()
    , 50)
  check_stream_ready()
if walletSetup:
  viewSelector(Wallet, true)
appInst = setInitializer(appMain, "main", afterScript)
