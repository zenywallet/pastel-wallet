# Copyright (c) 2019 zenywallet
# nim js -d:release main.nim

include karax / prelude
import jsffi except `&`
import strutils
import unicode
import sequtils

var appInst: KaraxInstance
var document {.importc, nodecl.}: JsObject
#var console {.importc, nodecl.}: JsObject
proc jq(selector: cstring): JsObject {.importcpp: "$$(#)".}
#var camDevice {.importc, nodecl.}: JsObject

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
  echo "view", view
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


{.emit: """
var jsViewSelector = function() {}
""".}
var jsViewSelector {.importc, nodecl.}: JsObject
asm """
  jsViewSelector = `viewSelector`;
  function setSupressRedraw(flag) {
    `supressRedraw` = flag;
  }
  function getSupressRedraw() {
    return `supressRedraw`;
  }
"""

proc viewUpdate() =
  if not supressRedraw:
    appInst.redraw()

#proc importTypeButtonClass(importType: ImportType): cstring =
#  if importType == currentImportType:
#    "ui olive button"
#  else:
#    "ui grey button"

proc importSelector(importType: ImportType): proc() =
  result = proc() =
    asm """
      qrReader.hide();
    """
    currentImportType = importType

    if currentImportType == ImportType.SeedCard:
      showPage2 = showScanResult
    elif currentImportType == ImportType.Mnemonic:
      showPage2 = mnemonicFulfill

    if currentImportType == ImportType.SeedCard:
      asm """
        $('#seedselector').removeClass('grey').addClass('olive');
        $('#mnemonicselector').removeClass('olive').addClass('grey');
      """
    else:
      asm """
        $('#mnemonicselector').removeClass('grey').addClass('olive');
        $('#seedselector').removeClass('olive').addClass('grey');
      """
    viewUpdate()

proc protectSelector(protectType: ProtectType): proc() =
  result = proc() =
    asm """
      qrReader.hide();
    """
    currentProtectType = protectType
    showPage1 = false
    showPage2 = true

    #if currentProtectType == ProtectType.KeyCard:
    #  showPage2 = showScanResult
    #elif currentProtectType == ProtectType.Passphrase:
    #  showPage2 = mnemonicFulfill

    if currentProtectType == ProtectType.KeyCard:
      asm """
        $('#keyselector').removeClass('grey').addClass('olive');
        $('#passselector').removeClass('olive').addClass('grey');
      """
    else:
      asm """
        $('#passselector').removeClass('grey').addClass('olive');
        $('#keyselector').removeClass('olive').addClass('grey');
      """
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
var wl_japanese = cast[seq[cstring]](bip39.wordlists.japanese.map(proc(x: JsObject): cstring = cast[cstring](x)))
var wl_english = cast[seq[cstring]](bip39.wordlists.english.map(proc(x: JsObject): cstring = cast[cstring](x)))
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
  asm """
    var wallet = pastel.wallet;
  """
  if currentImportType == ImportType.SeedCard:
    asm """
      wallet.setSeedCard(`seedCardInfos`);
    """
  elif currentImportType == ImportType.Mnemonic:
    asm """
      wallet.setMnemonic(`inputWords`, `wl_select_id`);
    """

asm """
  jsSeedToKeys = `seedToKeys`;
  jsClearSensitive = `clearSensitive`;
"""

proc escape_html(s: cstring): cstring {.importc, nodecl.}

proc cbSeedQrDone(data: cstring) =
  echo "cbQrDone:", data
  var escape_data = escape_html(data)
  var sdata = $escape_data
  var ds = sdata.split(',')
  var seedCardInfo: SeedCardInfo = new SeedCardInfo
  for d in ds:
    if d.startsWith("seed:"):
      seedCardInfo.seed = d[5..^1]
      echo seedCardInfo.seed
    elif d.startsWith("tag:"):
      seedCardInfo.tag = d[4..^1]
      echo seedCardInfo.tag
    elif d.startsWith("gen:"):
      seedCardInfo.gen = d[4..^1]
      echo seedCardInfo.gen
  seedCardInfo.orig = data
  echo repr(seedCardInfo)

  asm """
    var seed_valid = false;
    if(`seedCardInfo`.seed) {
      var dec = base58.dec(`seedCardInfo`.seed);
      if(dec && dec.length == 32) {
        seed_valid = true;
      }
    }
    if(!seed_valid) {
      Notify.show("Warning", "Unsupported seed card was scanned.", Notify.msgtype.warning);
    }

  """

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
    asm """
      Notify.show("Error", "The seed card has already been scanned.", Notify.msgtype.error);
    """
  else:
    seedCardInfos.add(seedCardInfo)

  asm """
    qrReader.hide();
  """
  viewSelector(SeedAfterScan)

var keyCardVal: cstring = ""

proc cbKeyQrDone(data: cstring) =
  echo "cbQrDone:", data
  keyCardVal = data
  asm """
    qrReader.hide();
  """
  viewSelector(KeyAfterScan)

proc showSeedQr(): proc() =
  result = proc() =
    asm """
      qrReader.show(`cbSeedQrDone`);
    """

proc showKeyQr(): proc() =
  result = proc() =
    keyCardFulfill = false
    showPage3 = false
    asm """
      qrReader.show(`cbKeyQrDone`);
    """

proc confirmKeyCard(ev: Event; n: VNode) =
  var ret_lock: bool = false
  asm """
    var wallet = pastel.wallet;
    `ret_lock` = wallet.lockShieldedKeys(`keyCardVal`, 1, true);
  """
  if ret_lock:
    keyCardFulfill = true
    showPage3 = true
    viewUpdate()
  else:
    asm """
      Notify.show("Error", "Failed to lock your wallet with the key card.", Notify.msgtype.error);
    """

proc camChange(): proc() =
  result = proc() =
    asm """
      $('.camtools button').blur();
      qrReader.next();
    """

proc camClose(): proc() =
  result = proc() =
    asm """
      qrReader.hide();
    """

const levenshtein_js = staticRead("levenshtein.js")
{.emit: levenshtein_js.}
{.emit: """
function levens(word, wordlist) {
  if(word.length == 0) {
    return;
  }
  var data = {}
  for(var i in wordlist) {
    var wl = wordlist[i];
    var maxlen = Math.max(word.length, wl.length);
    var lev = levenshtein(word, wl);
    var score = lev / maxlen;
    if(data[score]) {
      data[score].push(wl);
    } else {
      data[score] = [wl];
    }
  }
  var similars = [];
  var result = [];
  var svals = Object.keys(data).sort();
  for(var i in svals) {
    var score = svals[i];
    similars.push(data[score]);
    if(result.length > 0 && score > 0.5) {
      break;
    }
    if((result.length == 0 && data[score].length <= 30) || (result.length + data[score].length) <= 7) {
      result = result.concat(data[score]);
    }
  }
  return result;
}
function levens_one(word, wordlist) {
  if(word.length == 0) {
    return;
  }
  var data = {}
  for(var i in wordlist) {
    var wl = wordlist[i];
    var maxlen = Math.max(word.length, wl.length);
    var lev = levenshtein(word, wl);
    if(lev != 1) {
      continue;
    }
    var score = lev / maxlen;
    if(data[score]) {
      data[score].push(wl);
    } else {
      data[score] = [wl];
    }
  }
  var result = [];
  var svals = Object.keys(data).sort();
  for(var i in svals) {
    var score = svals[i];
    result = result.concat(data[score]);
  }
  return result;
}
""".}

proc replace*(s, a, b: cstring): cstring {.importcpp, nodecl.}
proc join*(s: cstring): cstring {.importcpp, nodecl.}
proc includes*(s: seq[cstring], a: cstring): bool {.importcpp, nodecl.}

#proc levenshtein(a, b: JsObject): JsObject {.importc, nodecl.}
proc levens(word, wordlist: JsObject): JsObject {.importc, nodecl.}
proc levens_one(word, wordlist: JsObject): JsObject {.importc, nodecl.}

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
    asm """
      `s` = `s`.substr(0, `cur`).replace(/[ 　\n\r]+/g, ' ').split(' ').slice(-1)[0];
    """
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
        asm """
          var t = `s`.substr(0, `cur`).replace(/[ 　\n\r]+/g, ' ').split(' ').slice(-1)[0];
          if(t && t.length > 0) {
            `s` = `s`.substr(0, `cur` - t.length) + `word`;
            `newcur` = `s`.length;
          }
        """
        x.setInputText(s)
        editingWords = s
        input_elm.focus()
        input_elm.selectionStart = newcur
        input_elm.selectionEnd = newcur
      else:
        asm """
          var t = `s`.substr(0, `cur`).replace(/[ 　\n\r]+/g, ' ').split(' ').slice(-1)[0];
          if(t && t.length > 0) {
            var tail = `s`.substr(`cur`) || '';
            `s` = `s`.substr(0, `cur` - t.length) + `word` + tail;
            `newcur` = `s`.length - tail.length;
          }
        """
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
      asm """
        `inputWords` = `s`.replace(/[ 　\n\r]+/g, ' ').trim();
        `words` = `inputWords`.split(' ');
      """
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
        asm """
          var bip39 = coinlibs.bip39;
          if(bip39.validateMnemonic(`inputWords`, `bip39_wordlist`)) {
            `mnemonicFulfill` = true
          } else {
            Notify.show('Warning', 'There are no misspellings, but some words seem to be wrong.' + (`advance` ? '' : ' Try to use [Advanced Check]'), Notify.msgtype.warning);
          }
        """
        if mnemonicFulfill:
          viewSelector(MnemonicFulfill)
    else:
      chklist = @[]
    autocompleteWords = @[]
    viewUpdate()

proc fixWord(input_id: cstring, idx: int, word: cstring): proc() =
  result = proc() =
    let x = getVNodeById(input_id)
    var s = x.value
    if not s.isNil and s.len > 0:
      var ret: cstring
      asm """
        `ret` = "";
        var count = 0;
        var find = false;
        var skip = false;
        for(var t in `s`) {
          if(/[ 　\n\r]/.test(`s`[t])) {
            `ret` += `s`[t];
            if(find) {
              count++;
            }
            find = false;
            skip = false;
          } else {
            find = true;
            if(`idx` == count && skip == false) {
              `ret` += `word`;
              skip = true;
            } else {
              if(!skip) {
                `ret` += `s`[t];
              }
            }
          }
        }
      """
      x.setInputText(ret)
      editingWords = ret
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
            text "Select mnemonic language"
          tdiv(class="ui selection dropdown"):
            input(type="hidden", name="mnemonic-language", value="1", onchange=changeLanguage)
            italic(class="dropdown icon")
            tdiv(class="default text"):
              text "Mnemonic Language"
            tdiv(class="menu"):
              tdiv(class="item", data-value="1"):
                text "Japanese"
              tdiv(class="item", data-value="0"):
                text "English"
        tdiv(class="field minput-field"):
          label:
            text "Import your mnemonic you already have"
          textarea(id=input_id, value=editingWords, onkeyup=checkMnemonic, onmouseup=checkMnemonic, spellcheck="false")
      button(class="ui right floated primary button", onclick=confirmMnemonic(input_id, false)):
        text "Check"
      button(class="ui right floated default button", onclick=confirmMnemonic(input_id, true)):
        text "Advanced Check"
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
      tdiv(class="header"): text "Seed"
      tdiv(class="meta"):
        span(class="date"): text if not cardInfo.gen.isNil: cardInfo.gen else: "unknown"
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
        tdiv(class="vector-label"): text "Seed Vector:"
        tdiv(class="ui mini input vector-input"):
          input(type="text", placeholder="Type your seed vector"):
            proc onkeyup(ev: Event; n: Vnode) =
              seedCardInfos[idx].sv = n.value
    tdiv(class="bt-seed-del"):
      button(class="circular ui icon mini button", onclick=removeSeedCard(idx)):
        italic(class="cut icon")

proc changePassphrase(ev: Event; n: VNode) =
  passphraseFulfill = false
  showPage3 = false
  passPhrase = n.value
  viewUpdate()
  discard

proc confirmPassphrase(ev: Event; n: VNode) =
  var ret_lock: bool = false
  asm """
    $('input[name="input-passphrase"]').blur();
    var wallet = pastel.wallet;
    `ret_lock` = wallet.lockShieldedKeys($('input[name="input-passphrase"]').val(), 2, true);
  """
  if ret_lock:
    passphraseFulfill = true
    showPage3 = true
    viewUpdate()
  else:
    asm """
      Notify.show("Error", "Failed to lock your wallet with the passphrase.", Notify.msgtype.error);
    """

proc passphraseEditor(): VNode =
  result = buildHtml(tdiv):
    tdiv(class="ui clearing segment passphrase-seg"):
      tdiv(class="ui inverted segment"):
        h4(class="ui grey inverted header center"): text "Input passphrase"
        tdiv(class="ui form"):
          tdiv(class="field"):
            input(class="center", type="text", name="input-passphrase", value=passPhrase, placeholder="Passphrase", onkeyup=changePassphrase, onkeyupenter=confirmPassphrase)
      button(class="ui right floated olive button", onclick=confirmPassphrase):
        text "Apply"

proc goSettings(): proc() =
  result = proc() =
    echo showPage4
    if not showPage4:
      viewSelector(WalletSettings, false)
      supressRedraw = true
      asm """
        $('#section4').show();
      """
    else:
      asm """
        TradeLogs.stop();
        $('.backpage').visibility({silent: true});
        $('#tradeunconfs').empty();
        $('#tradelogs').empty();
      """
      viewSelector(WalletSettings, false)
      asm """
        goSection('#section4');
      """

proc goLogs(): proc() =
  result = proc() =
    if not showPage4:
      viewSelector(WalletLogs, false)
      supressRedraw = true
      asm """
        $('#section4').show();
      """
    else:
      asm """
        TradeLogs.stop();
        $('.backpage').visibility({silent: true});
        $('#tradeunconfs').empty();
        $('#tradelogs').empty();
      """
      viewSelector(WalletLogs, false)
      asm """
        goSection('#section4');
      """

proc backWallet(): proc() =
  result = proc() =
    viewSelector(Wallet, true)
    asm """
      goSection('#section3', page_scroll_done);
    """

asm """
  var send_ball_count = 0;
  var send_ball_count_less = false;
  var send_ball_count_over = false;

  function conv_coin(uint64_val) {
    strval = uint64_val.toString();
    val = parseInt(strval);
    if(val > Number.MAX_SAFE_INTEGER) {
      var d = strval.slice(-8).replace(/0+$/, '');
      var n = strval.substr(0, strval.length - 8);
      if(d.length > 0) {
        return n + '.' + d;
      } else {
        return n;
      }
    }
    return val / 100000000;
  }

  function resetSendBallCount() {
    send_ball_count = 0;
    send_ball_count_less = false;
    send_ball_count_over = false;
    $('#btn-utxo-count').text('...');
    pastel.utxoballs.setsend(0);
    send_ball_count = 0;
  }

  function setSendUtxo(value) {
    var ret = pastel.wallet.calcSendUtxo(value);
    var amount_elm = $('#send-coins input[name="amount"]');
    if(ret.err) {
      send_ball_count_over = true;
      $('#btn-utxo-count').text('>' + String(ret.safe_count) + ' max');
      pastel.utxoballs.setsend(ret.safe_count);
      send_ball_count = ret.safe_count;
      amount_elm.closest('.field').addClass('error');
    } else {
      send_ball_count_less = !ret.eq;
      if(ret.utxo_count > ret.safe_count) {
        send_ball_count_over = true;
        $('#btn-utxo-count').text('>' + String(ret.safe_count) + ' max');
        pastel.utxoballs.setsend(ret.safe_count);
        send_ball_count = ret.safe_count;
        amount_elm.closest('.field').addClass('error');
      } else {
        amount_elm.closest('.field').removeClass('error');
        send_ball_count_over = false;
        $('#btn-utxo-count').text((ret.eq ? '' : '≤') + String(ret.utxo_count) + (ret.utxo_count == ret.safe_count ? ' max' : ''));
        pastel.utxoballs.setsend(ret.utxo_count);
        send_ball_count = ret.utxo_count;
      }
    }
  }

  function initSendForm() {
    $('#btn-send-clear').off('click').click(function() {
      $('#send-coins input[name="address"]').val('');
      $('#send-coins input[name="amount"]').val('');
      $('#send-coins input[name="address"]').closest('.field').removeClass('error');
      $('#send-coins input[name="amount"]').closest('.field').removeClass('error');
      resetSendBallCount();
      uriOptions = [];
      jsViewSelector(12);
      $(this).blur();
    });
    $('#btn-send-qrcode').off('click').click(function() {
      qrReaderModal.show(function(uri) {
        var data = bip21reader(uri);
        $('#send-coins input[name="address"]').val(data.address || '');
        $('#send-coins input[name="amount"]').val(data.amount || '');
        uriOptions = [];
        for(var k in data) {
          var p = data[k];
          if(k == 'address' || k == 'amount') {
            continue;
          }
          var key = crlftab_to_html(k);
          key = key.charAt(0).toUpperCase() + key.slice(1);
          uriOptions.push({key: key, value: crlftab_to_html(p)});
        }
        jsViewSelector(12);
      });
      $(this).blur();
    });
    $('#btn-send-lock').off('click').click(function() {
      var elm = $(this);
      var icon = elm.find('i');
      if(icon.hasClass('open')) {
        if(pastel.wallet && pastel.wallet.lockShieldedKeys()) {
          icon.removeClass('open');
          elm.attr('title', 'Locked');
          PhraseLock.notify_locked();
        }
      } else {
        Notify.hide_all();
        PhraseLock.showPhraseInput(function(status) {
          if(status == PhraseLock.PLOCK_SUCCESS) {
            icon.addClass('open');
            elm.attr('title', 'Unlocked');
            PhraseLock.notify_unlocked();
          } else if(status == PhraseLock.PLOCK_FAILED_QR) {
            Notify.show("Error", "Failed to unlock. Wrong key card was scanned.", Notify.msgtype.error);
          } else if(status == PhraseLock.PLOCK_FAILED_PHRASE) {
            Notify.show("Error", "Failed to unlock. Passphrase is incorrect.", Notify.msgtype.error);
          }
        });
      }
      elm.blur();
    });
    pastel.utxoballs.setsend(send_ball_count);

    $('#btn-utxo-plus').off('click').click(function() {
      $('#send-coins input[name="amount"]').closest('.field').removeClass('error');
      if(send_ball_count_less) {
        send_ball_count_less = false;
      } else {
        send_ball_count++;
      }
      if(send_ball_count >= 1000) {
        send_ball_count = 999;
      }
      var safe_count = pastel.wallet.getSafeCount();
      if(send_ball_count > safe_count) {
        send_ball_count = safe_count;
      }
      var sendval = pastel.wallet.calcSendValue(send_ball_count);
      pastel.utxoballs.setsend(send_ball_count);
      $('#send-coins input[name="amount"]').val(conv_coin(sendval.value));
      $('#btn-utxo-count').text(String(sendval.count) + (sendval.count == safe_count ? ' max' : ''));
      $(this).blur();
    });
    $('#btn-utxo-minus').off('click').click(function() {
      $('#send-coins input[name="amount"]').closest('.field').removeClass('error');
      var safe_count = pastel.wallet.getSafeCount();
      if(send_ball_count_over) {
        send_ball_count_over = false;
        send_ball_count = safe_count;
      } else {
        send_ball_count--;
      }
      send_ball_count_less = false;
      if(send_ball_count < 0) {
        send_ball_count = 0;
      }
      pastel.utxoballs.setsend(send_ball_count);
      var sendval = pastel.wallet.calcSendValue(send_ball_count);
      $('#send-coins input[name="amount"]').val(conv_coin(sendval.value));
      $('#btn-utxo-count').text(String(sendval.count) + (sendval.count == safe_count ? ' max' : ''));
      $(this).blur();
    });
    $('#btn-tx-send').off('click').click(function() {
      var locked = PhraseLock.notify_if_need_unlock();
      if(!locked && pastel.wallet) {
        var address = String($('#send-coins input[name="address"]').val()).trim();
        var amount = String($('#send-coins input[name="amount"]').val()).trim();
        if(address.length == 0 || amount.length == 0) {
          var address_elm = $('#send-coins input[name="address"]').closest('.field');
          var amount_elm = $('#send-coins input[name="amount"]').closest('.field');
          var flag = true;
          var alert_count = 0;
          function alert_worker() {
            if(address.length == 0) {
              if(flag) {
                address_elm.addClass('error');
              } else {
                address_elm.removeClass('error');
              }
            }
            if(amount.length == 0) {
              if(flag) {
                amount_elm.addClass('error');
              } else {
                amount_elm.removeClass('error');
              }
            }
            alert_count++;
            if(alert_count < 4) {
              flag = !flag;
              setTimeout(alert_worker, 100);
            }
          }
          alert_worker();
          return;
        }
        amount = amount.replace(/,/g, '');
        var amounts = amount.split('.');
        if(amount.match(/^\d+(\.\d{1,8})?$/)) {
          var value = '';
          if(amounts.length == 1) {
            value = amounts[0] + '00000000';
          } else if(amounts.length == 2) {
            value = amounts[0] + (amounts[1] + '00000000').slice(0, 8);
          }
          Notify.hide_all();
          pastel.wallet.send(address, value, function(result) {
            console.log('send result', result);
            var ErrSend = pastel.wallet.ERR_SEND;
            switch(result.err) {
            case ErrSend.SUCCESS:
              Notify.show('', 'Coins sent successfully.', Notify.msgtype.info);
              break;
            case ErrSend.FAILED:
              Notify.show('Error', 'Failed to send coins.', Notify.msgtype.error);
              break;
            case ErrSend.INVALID_ADDRESS:
              Notify.show('Error', 'Address is invalid.', Notify.msgtype.error);
              break;
            case ErrSend.INSUFFICIENT_BALANCE:
              Notify.show('Error', 'Balance is insufficient.', Notify.msgtype.error);
              break;
            case ErrSend.DUST_VALUE:
              Notify.show('Error', 'Amount is too small.', Notify.msgtype.error);
              break;
            case ErrSend.BUSY:
              Notify.show('Error', 'Failed to send coins. Busy.', Notify.msgtype.error);
              break;
            case ErrSend.TX_FAILED:
              var msg = '';
              if(result.res && result.res.message) {
                msg = '<br> [' + result.res.message + ']';
              }
              Notify.show('Error', 'Failed to send coins.' + msg, Notify.msgtype.error);
              break;
            case ErrSend.TX_TIMEOUT:
              Notify.show('Error', 'Server is not responding. Coins may have been sent.', Notify.msgtype.warning);
              break;
            case ErrSend.SERVER_ERROR:
              Notify.show('Error', 'Failed to send coins. Server error.', Notify.msgtype.error);
              break;
            case ErrSend.SERVER_TIMEOUT:
              Notify.show('Error', 'Failed to send coins. Server is not responding.', Notify.msgtype.error);
              break;
            default:
              Notify.show('Error', 'Failed to send coins.', Notify.msgtype.error);
            }
          });
        } else {
          if(amounts.length > 1 && amounts[1].length > 8) {
            Notify.show('Error', 'Amount is invalid. The decimal places is too long. Please set it 8 or less.', Notify.msgtype.error);
          } else {
            Notify.show('Error', 'Amount is invalid.', Notify.msgtype.error);
          }
        }
        $(this).blur();
      } else {
        $('#btn-send-lock').focus();
      }
    });
  }

  var sendrecv_switch = 0;
  var sendrecv_switch_busy = false;
  var sendrecv_switch_tval;
  var sendrecv_last = null;
  var sendrecv_wait = 0;
  function send_switch() {
    sendrecv_switch_busy = true;
    if(sendrecv_last == 2) {
      $('#receive-address').transition({
        animation: 'fade down',
        onComplete : function() {
          $('#send-coins').transition({
            animation: 'fade down',
            onComplete : function() {
              sendrecv_last = 1;
              sendrecv_switch_busy = false;
            }
          });
          initSendForm();
        }
      });
    } else {
      $('#send-coins').transition({
        animation: 'fade down',
        onComplete : function() {
          sendrecv_last = 1;
          sendrecv_switch_busy = false;
        }
      });
      initSendForm();
    }
  }
  function recv_switch() {
    sendrecv_switch_busy = true;
    if(sendrecv_last == 1) {
      $('#send-coins').transition({
        animation: 'fade down',
        onComplete : function() {
          showRecvAddress(function() {
            $('#receive-address').transition({
              animation: 'fade down',
              onComplete : function() {
                showRecvAddressAfterEffect();
                sendrecv_last = 2;
                sendrecv_switch_busy = false;
              }
            });
          });
        }
      });
    } else {
      showRecvAddress(function() {
        $('#receive-address').transition({
          animation: 'fade down',
          onComplete : function() {
            showRecvAddressAfterEffect();
            sendrecv_last = 2;
            sendrecv_switch_busy = false;
          }
        });
      });
    }
  }
  function reset_switch(switch_id) {
    if(!$('#send-coins').hasClass('hidden') && (switch_id == null || switch_id == 1)) {
      sendrecv_switch_busy = true;
      if(switch_id == 1) {
        pastel.utxoballs.setsend(0);
      }
      $('#send-coins').transition({
        animation: 'fade down',
        onComplete : function() {
          sendrecv_last = 0;
          sendrecv_switch_busy = false;
        }
      });
    }
    if(!$('#receive-address').hasClass('hidden') && (switch_id == null || switch_id == 2)) {
      sendrecv_switch_busy = true;
      $('#receive-address').transition({
        animation: 'fade down',
        onComplete : function() {
          sendrecv_last = 0;
          sendrecv_switch_busy = false;
        }
      });
    }
  }
  function sendrecv_switch_worker() {
    if(sendrecv_switch_busy) {
      sendrecv_switch_tval = setTimeout(function() {
        sendrecv_wait++;
        if(sendrecv_wait < 300) {
          sendrecv_switch_worker();
        } else {
          sendrecv_switch_busy = false;
        }
      }, 50);
      return;
    }
    sendrecv_wait = 0;
    if(sendrecv_last == sendrecv_switch) {
      return;
    }
    if(sendrecv_switch == 1) {
      send_switch();
    } else if(sendrecv_switch == 2) {
      recv_switch();
    } else {
      reset_switch();
    }
  }
  function sendrecv_select(val) {
    clearTimeout(sendrecv_switch_tval);
    if(val != 1) {
      pastel.utxoballs.setsend(0);
    }
    sendrecv_switch = val;
    sendrecv_switch_worker();
  }
"""

proc btnSend: proc() =
  result = proc() =
    asm """
      if(!pastel.wallet || !pastel.utxoballs) {
        return;
      }
      sendrecv_select((sendrecv_switch == 1) ? 0 : 1);
      document.getElementById('btn-send').blur();
    """

proc btnReceive: proc() =
  result = proc() =
    asm """
      if(!pastel.wallet || !pastel.utxoballs) {
        return;
      }
      sendrecv_select((sendrecv_switch == 2) ? 0 : 2);
      document.getElementById('btn-receive').blur();
    """

proc btnSendClose: proc() =
  result = proc() =
    asm """
      clearTimeout(sendrecv_switch_tval);
      sendrecv_switch = 0;
      reset_switch(1);
    """

proc btnRecvClose: proc() =
  result = proc() =
    asm """
      clearTimeout(sendrecv_switch_tval);
      sendrecv_switch = 0;
      reset_switch(2);
    """

proc recvAddressSelector(): VNode =
  result = buildHtml(tdiv(id="receive-address", class="ui center aligned segment hidden")):
    tdiv(class="ui top attached label recvaddress"):
      text "Receive Address "
      span:
        italic(class="close icon btn-close", onclick=btnRecvClose())
    tdiv(class="ui mini basic icon buttons"):
      button(id="btn-recv-copy", class="ui button", title="Copy"):
        italic(class="paperclip icon")
      button(id="btn-recv-qrcode", class="ui button", title="QR Code"):
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
    tdiv(class="close-arc")
    tdiv(id="recv-qrcode", class="qrcode", title=""):
      canvas(width="0", height="0")
    tdiv(id="recvaddr-form", class="ui container"):
      tdiv(class="ui form"):
        tdiv(class="two fields"):
          tdiv(class="field"):
            label: text "Receive Address"
            tdiv(class="ui selection dropdown addr-selection", tabindex="0"):
              input(type="hidden", name="address", value="")
              italic(class="dropdown icon")
              tdiv(class="text"):
                img(clsss="ui mini avatar image", src="")
                text ""
              tdiv(class="menu", tabindex="-1")
          tdiv(class="field"):
            label: text "Amount"
            tdiv(class="ui right labeled input"):
              input(class="right", type="text", name="amount", placeholder="Amount")
              tdiv(class="ui basic label"): text "ZNY"
        tdiv(class="two fields"):
          tdiv(class="field"):
            label: text "Label"
            input(class="ui input", type="text", name="label", placeholder="Label")
          tdiv(class="field"):
            label: text "Message"
            textarea(class="ui textarea", rows="2", name="message", placeholder="Message")

proc checkSendAmount(ev: Event; n: VNode) =
  var s = n.value
  asm """
    var amount = String(`s`).trim();
    var amount_elm = $('#send-coins input[name="amount"]');
    if(amount.length > 0) {
      amount = amount.replace(/,/g, '');
      var amounts = amount.split('.');
      if(amount.match(/^\d+(\.\d{1,8})?$/)) {
        amount_elm.closest('.field').removeClass('error');
        var value = '';
        if(amounts.length == 1) {
          value = amounts[0] + '00000000';
        } else if(amounts.length == 2) {
          value = amounts[0] + (amounts[1] + '00000000').slice(0, 8);
        }
        if(value.length > 0) {
          setSendUtxo(value);
        } else {
          resetSendBallCount();
        }
      } else {
        amount_elm.closest('.field').addClass('error');
      }
    } else {
      amount_elm.closest('.field').removeClass('error');
      resetSendBallCount();
    }
  """

asm """
  var uriOptions = [];
"""
var uriOptions {.importc, nodecl.}: JsObject
proc sendForm(): VNode =
  result = buildHtml(tdiv(id="send-coins", class="ui center aligned segment hidden")):
    tdiv(class="ui top attached label sendcoins"):
      text "Send Coins "
      span:
        italic(class="close icon btn-close", onclick=btnSendClose())
    tdiv(class="ui right floated mini basic icon buttons"):
      button(id="btn-send-lock", class="ui button", title="Locked"):
        italic(class="lock icon")
    tdiv(class="ui mini basic icon buttons btn-send-tools"):
      button(id="btn-send-clear", class="ui button", title="Clear"):
        italic(class="eraser icon")
      button(id="btn-send-qrcode", class="ui button", title="Scan QR Code"):
        italic(class="camera icon")
    tdiv(class="ui form"):
      tdiv(class="field"):
        label: text "Send Address"
        tdiv(class="ui small input"):
          input(class="center", type="text", name="address", placeholder="Address")
      tdiv(class="field"):
        label: text "Amount"
        tdiv(class="ui small input"):
          input(class="center", type="text", name="amount", placeholder="Amount", onkeyup=checkSendAmount)
          tdiv(class="ui mini basic icon buttons utxoctrl"):
            button(id="btn-utxo-minus", class="ui button", title="-1 Ball"):
              italic(class="minus circle icon")
            button(id="btn-utxo-count", class="ui button sendutxos"):
              text "..."
            button(id="btn-utxo-plus", class="ui button", title="+1 Ball"):
              italic(class="plus circle icon")
      tdiv(class="ui list uri-options"):
        for d in uriOptions:
          tdiv(class="item"):
            tdiv(class="content"):
              tdiv(class="header"): text cast[cstring](d.key)
              tdiv(class="description"): text cast[cstring](d.value)
      tdiv(class="fluid ui buttons"):
        button(id="btn-tx-send", class="ui inverted olive button center btn-tx-send"):
          text "Send"

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
      text "Reset Wallet"
    tdiv(class="content"):
      p: text "Are you sure to reset your wallet?"
    tdiv(class="actions"):
      tdiv(class="ui basic cancel inverted button"):
        italic(class="remove icon")
        text "Cancel"
      tdiv(class="ui red ok inverted button"):
        italic(class="checkmark icon")
        text "Reset"

proc settingsPage(): VNode =
  result = buildHtml(tdiv(id="settings", class="ui container")):
    h3(class="ui dividing header"): text "Settings"
    button(id="btn-reset", class="ui inverted red button"): text "Reset Wallet"
    tdiv(class="ui pink inverted segment"):
      text """
        Delete all your wallet data in your web browser, including your encrypted secret keys.
         If you have coins in your wallet or waiting for receiving coins, make sure you have the seed cards
         or mnemonics before deleting it. Otherwise you may lost your coins forever.
      """
    tdiv(class="ui checkbox"):
      input(type="checkbox", name="confirm")
      label: text "I confirmed that I have the seed cards or mnemonics or no coins in my wallet."

proc appMain(data: RouterData): VNode =
  result = buildHtml(tdiv):
    if showPage1:
      section(id="section1", class="section"):
        tdiv(class="intro"):
          tdiv(class="intro-head"):
            tdiv(class="caption"): text "Pastel Wallet"
            tdiv(class="ui container method-selector"):
              tdiv(class="title"): text "Scan your seed cards or mnemonic to start."
              tdiv(class="ui buttons"):
                button(id="seedselector", class="ui olive button", onclick=importSelector(ImportType.SeedCard)):
                  italic(class="qrcode icon")
                  text "Seed card"
                tdiv(class="or")
                button(id="mnemonicselector", class="ui grey button", onclick=importSelector(ImportType.Mnemonic)):
                  italic(class="list alternate icon")
                  text "Mnemonic"
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
                    text "Next"
                if showScanning:
                  tdiv(class="qr-scanning"):
                    tdiv()
                    tdiv()
                if showScanSeedBtn:
                  tdiv(class="ui teal labeled icon button bt-scan-seed", onclick=showSeedQr()):
                    text "Scan seed card with camera"
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
                    text "Preparing Camera"
                tdiv(class="ui dimmer qrcamera-shutter")
            else:
              tdiv(class="ui left aligned segment mnemonic-seg"):
                mnemonicEditor()
                if mnemonicFulfill:
                  a(class="pagenext", href="#section2"):
                      span()
                      text "Next"
    if showPage2:
      section(id="section2", class="section"):
        tdiv(class="intro"):
          tdiv(class="intro-head"):
            tdiv(class="caption"): text "Pastel Wallet"
            tdiv(class="ui container method-selector"):
              tdiv(class="title"):
                text """
                  A key card or passphrase is required to encrypt and save the private key in your browser.
                   You will need it before sending your coins.
                """
              tdiv(class="ui buttons"):
                button(id="keyselector", class="ui olive button", onclick=protectSelector(ProtectType.KeyCard)):
                  italic(class="qrcode icon")
                  text "Key card"
                tdiv(class="or")
                button(id="passselector", class="ui grey button", onclick=protectSelector(ProtectType.Passphrase)):
                  italic(class="list alternate icon")
                  text "Passphrase"
          tdiv(class="intro-body"):
            if currentProtectType == ProtectType.KeyCard:
              tdiv(id="seed-seg", class="ui left aligned segment seed-seg"):
                if showScanResult2:
                  tdiv(class="ui clearing segment keycard-seg"):
                    tdiv(class="ui inverted segment"):
                      h4(class="ui grey inverted header center"): text "Scanned key card"
                      p(class="center"): text keyCardVal
                    button(class="ui right floated olive button", onclick=confirmKeyCard):
                      text "Apply"
                    button(class="ui right floated grey button", onclick=showKeyQr()):
                      text "Rescan"
                if keyCardFulfill:
                  a(class="pagenext", href="#section3"):
                    span()
                    text "Next"
                if showScanning2:
                  tdiv(class="qr-scanning"):
                    tdiv()
                    tdiv()
                if showScanSeedBtn2:
                  tdiv(class="ui teal labeled icon button bt-scan-seed", onclick=showKeyQr()):
                    text "Scan key card with camera"
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
                    text "Preparing Camera"
                tdiv(class="ui dimmer qrcamera-shutter")
            else:
              tdiv(class="ui left aligned segment mnemonic-seg"):
                passphraseEditor()
                if passphraseFulfill:
                  a(class="pagenext", href="#section3"):
                      span()
                      text "Next"
    if showPage3:
      section(id="section3", class="section"):
        tdiv(class="intro"):
          tdiv(class="intro-head  wallet-head"):
            tdiv(class="caption"): text "Pastel Wallet"
            tdiv(class="ui container wallet-btns"):
              tdiv(class="two ui basic buttons sendrecv"):
                button(id="btn-send", class="ui small button send", onclick=btnSend()):
                  italic(class="counterclockwise rotated sign-out icon send")
                  text " Send"
                button(id="btn-receive", class="ui small button receive", onclick=btnReceive()):
                  italic(class="clockwise rotated sign-in icon receive")
                  text " Receive"
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
            tdiv(class="ui button", onclick=goSettings()):
              italic(class="cog icon")
              text "Settings"
              span: italic(class="chevron down icon")
            tdiv(class="ui button", onclick=goLogs()):
              italic(class="list alternate outline icon")
              text "Logs"
              span: italic(class="chevron down icon")
            tdiv(id="bottom-blink")
        textarea(id="clipboard", rows="1", tabindex="-1")

    if showPage3 or showPage4:
      section(id="section4", class="tradelogs-section"):
        tdiv(class="ui buttons settings backpage"):
          tdiv(class="ui button backwallet", onclick=backWallet()):
            italic(class="dot circle icon")
            text "Back"
            span: italic(class="chevron up icon")
        if showTradeLogs:
          tdiv(class="ui container"):
            tdiv(id="tradeunconfs", class="ui cards tradelogs")
            tdiv(id="tradelogs", class="ui cards tradelogs")
        if showSettings:
          settingsPage()
          settingsModal()

proc afterScript(data: RouterData) =
  jq("#section0").remove()
  jq(".ui.dropdown").dropdown()
  if showScanResult:
    asm """
      function seedCardQrUpdate(vivid) {
        $('.seed-qrcode').each(function() {
          $(this).find('canvas').remove();
          var fillcolor;
          var fillStyleFn;
          if($(this).hasClass('active')) {
            fillcolor = vivid ? '#000' : '#7f7f7f';
            if(!vivid) {
              fillStyleFn = function(ctx) {
                var w = ctx.canvas.width;
                var h = ctx.canvas.height;
                var grd = ctx.createLinearGradient(0, 0, w, h);
                grd.addColorStop(0, "#666");
                grd.addColorStop(0.3, "#aaa");
                grd.addColorStop(1, "#555");
                return grd;
              }
            }
          } else {
            fillcolor = '#f8f8f8';
          }
          $(this).qrcode({
            render: 'canvas',
            ecLevel: 'Q',
            radius: 0.39,
            text: $(this).data('orig'),
            size: 188,
            mode: 2,
            label: '',
            fontname: 'sans',
            fontcolor: '#393939',
            fill: fillcolor,
            fillStyleFn: fillStyleFn
          });
        });
      }
      if(!$('.seed-qrcode .active').length) {
        $('.seed-qrcode').last().addClass('active');
      }
      seedCardQrUpdate();

      $('.seed-card').off('click').on('click', function() {
        $('.seed-card').not(this).each(function() {
          $(this).find('.seed-qrcode').removeClass('active');
        });
        $(this).find('.seed-qrcode').addClass('active');
        seedCardQrUpdate(true);
      });
      $('.seed-card').off('mouseleave').mouseleave(function() {
        $('.seed-qrcode').addClass('active');
        seedCardQrUpdate();
      });
      var holder = document.getElementById('seed-card-holder');
      if(holder) {
        holder.scrollLeft = holder.scrollWidth - holder.clientWidth;
      }
    """

  if showScanResult or mnemonicFulfill:
    asm """
      target_page_scroll = '#section2';
      page_scroll_done = function() {
        $('a.pagenext').css('visibility', 'hidden');
        $('#section1').hide();
        window.scrollTo(0, 0);
        jsSeedToKeys();
        jsViewSelector(5);
        page_scroll_done = function() {};
      }
    """
  if keyCardFulfill or passphraseFulfill:
    asm """
      target_page_scroll = '#section3';
      page_scroll_done = function() {
        var wallet = pastel.wallet;
        var ret = wallet.lockShieldedKeys();
        if(!ret) {
          Notify.show("Error", "Failed to lock keys.", Notify.msgtype.error);
        }
        jsClearSensitive();
        $('a.pagenext').css('visibility', 'hidden');
        $('#section2').hide();
        window.scrollTo(0, 0);
        jsViewSelector(9);
        if(pastel.stream && !pastel.stream.status()) {
          pastel.stream.start();
        }
        page_scroll_done = function() {};
      }
    """
  if showScanResult or mnemonicFulfill or keyCardFulfill or passphraseFulfill:
    asm """
      for(var i in registerEventList) {
        var ev = registerEventList[i];
        ev.elm.removeEventListener(ev.type, ev.cb);
      }
      var elms = document.querySelectorAll('a.pagenext');
      Array.prototype.forEach.call(elms, function(elm) {
        var href = elm.getAttribute("href");
        if(href && href.startsWith('#')) {
          var cb = function(e) {
            e.preventDefault();
            var href = this.getAttribute('href');
            if(href == '#section2') {
              goSection(href, page_scroll_done);
            } else if(href == '#section3') {
              goSection(href, page_scroll_done);
            }
          }
          registerEventList.push({elm: elm, type: 'click', cb: cb});
          elm.addEventListener('click', cb);
        }
      });
    """

  if showPage2 and not passphraseFulfill:
    asm """
      $('input[name="input-passphrase"]').focus();
    """

  if showPage4:
    asm """
      //$.fn.visibility.settings.silent = true;
      $('.backpage').visibility({
        type: 'fixed',
        offset: 0
      });
    """
    if showTradeLogs:
      asm """
        TradeLogs.start();
      """
    if showSettings:
      asm """
        Settings.init();
      """
    asm """
      goSection('#section4', function() {
        target_page_scroll = '#section3';
        page_scroll_done = function() {
          TradeLogs.stop();
          $('.backpage').visibility({silent: true});
          $('#tradeunconfs').empty();
          $('#tradelogs').empty();
          $('#section4').hide();
          window.scrollTo(0, 0);
          setSupressRedraw(false);
          reloadViewSafeStart();
          jsViewSelector(12);
          page_scroll_done = function() {};
          $('#bottom-blink').fadeIn(100).fadeOut(400);
        }
      });
    """
  else:
    asm """
      $('#section4').hide();
    """

  if showPage3 or showPage4:
    asm """
      reloadViewSafeEnd();
    """

var walletSetup = false
asm """
  var stor  = new Stor()
  var xpubs = stor.get_xpubs()
  stor = null;
  if(xpubs.length > 0) {
    `walletSetup` = true;
    function check_stream_ready() {
      setTimeout(function() {
        if(pastel.stream && !pastel.stream.status()) {
          pastel.stream.start();
        } else {
          check_stream_ready();
        }
      }, 50);
    }
    check_stream_ready();
  }
"""
if walletSetup:
  viewSelector(Wallet, true)
appInst = setInitializer(appMain, "main", afterScript)
