# Copyright (c) 2019 zenywallet
# nim js -d:release main.nim

include karax / prelude
import jsffi except `&`
import strutils
import unicode
import sequtils

var appInst: KaraxInstance

{.emit: """
var jsViewSelector = function() {}

var camDevice = (function() {
  var cam_ids = [];
  var sel_cam = null;
  var sel_cam_index = 0;
  navigator.mediaDevices.enumerateDevices().then(function(devices) {
    devices.forEach(function(device) {
      if(device.kind == 'videoinput') {
        cam_ids.push(device);
      }
    });
  });
  return {
    next: function() {
      if(cam_ids.length > 0) {
        if(sel_cam == null) {
          sel_cam_index = cam_ids.length - 1;
          sel_cam = cam_ids[sel_cam_index].deviceId;
        } else {
          sel_cam_index++;
          if(sel_cam_index >= cam_ids.length) {
            sel_cam_index = 0;
          }
          sel_cam = cam_ids[sel_cam_index].deviceId;
        }
      }
      return sel_cam;
    },
    count: function() {
      return cam_ids.length;
    }
  };
})();

var qrReader = (function() {
  var mode_show = true;
  var video = null;
  var qr_instance = null;

  function video_status_change() {
    if(mode_show) {
      $('.bt-scan-seed').css('visibility', 'hidden');
      $('.camtools').css('visibility', 'visible');
      $('.qr-scanning').show();
    } else {
      $('.qr-scanning').hide();
      $('.camtools').css('visibility', 'hidden');
      $('.bt-scan-seed').css('visibility', 'visible');
    }
  }

  function video_stop() {
    mode_show = false;
    video_status_change();
  }

  function cb_done(data) {
    console.log(data);
  }

  function stop_qr_instance(cb) {
    if(qr_instance) {
      setTimeout(function() {
        if(qr_instance) {
          qr_instance.stop();
          qr_instance = null;
          if(video) {
            video.removeAttribute('src');
            video.load();
          }
          if(cb) {
            cb();
          }
        }
      }, 1);
    } else {
      if(cb) {
        cb();
      }
    }
  }

  return {
    show: function(cb) {
      stop_qr_instance(function() {
        mode_show = true;
        var scandata = "";
        var cb_once = 0;
        var qr = new QCodeDecoder();
        qr_instance = qr;
        var qr_stop = function() {
          setTimeout(function() {
            qr.stop();
            video_stop();
          }, 1);
        }
        if(qr.isCanvasSupported() && qr.hasGetUserMedia()) {
          video = document.querySelector('#qrvideo');
          video.onloadstart = video_status_change;
          video.autoplay = true;

          function resultHandler(err, result) {
            if(err) {
              qr_stop();
              return;
            }
            if(scandata == result) {
              if(cb_once) {
                return;
              }
              cb_once = 1;
              qr_stop();
              if(cb) {
                cb(result);
              } else {
                cb_done(result);
              }
            }
            scandata = result;
          }
          qr.setSourceId(camDevice.next());
          qr.decodeFromCamera(video, resultHandler);
        }
      });
    },
    hide: function() {
      mode_show = false;
      stop_qr_instance();
    }
  }
})();
""".}

var document {.importc, nodecl.}: JsObject
#var console {.importc, nodecl.}: JsObject
proc jq(selector: cstring): JsObject {.importcpp: "$$(#)".}
#var camDevice {.importc, nodecl.}: JsObject

type ImportType {.pure.} = enum
  SeedCard
  Mnemonic

var currentImportType = ImportType.SeedCard

type ViewType = enum
  SeedNone
  SeedScanning
  SeedAfterScan

var showScanSeedBtn = true
var showScanning = true
var showCamTools = true
var showScanResult = false

proc viewSelector(view: ViewType) =
  echo "view", view
  case view
  of SeedNone:
    showScanSeedBtn = true
    showScanning = true
    showCamTools = true
    showScanResult = false
  of SeedScanning:
    showScanSeedBtn = true
    showScanning = true
    showCamTools = true
    showScanResult = false
  of SeedAfterScan:
    showScanSeedBtn = false
    showScanning = false
    showCamTools = false
    showScanResult = true
  appInst.redraw()

var jsViewSelector {.importc, nodecl.}: JsObject
asm """
  jsViewSelector = `viewSelector`
"""

proc importTypeButtonClass(importType: ImportType): cstring =
  if importType == currentImportType:
    "ui olive button"
  else:
    "ui grey button"

proc importSelector(importType: ImportType): proc() =
  result = proc() =
    currentImportType = importType

type SeedCardInfo = object
  seed: cstring
  gen: cstring
  tag: cstring
  orig: cstring

var seedCardInfo: SeedCardInfo

proc cbSeedQrDone(data: cstring) =
  echo "cbQrDone:", data
  var sdata = $data
  var ds = sdata.split(',')
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
  echo seedCardInfo

  asm """
    qrReader.hide();
  """
  viewSelector(SeedAfterScan)

proc showQr(): proc() =
  result = proc() =
    asm """
      qrReader.show(`cbSeedQrDone`);
    """

proc camChange(): proc() =
  result = proc() =
    asm """
      $('.camtools button').blur();
      qrReader.show(`cbSeedQrDone`);
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
    var lev = levenshtein(word, wl)
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
""".}

proc replace*(s, a, b: cstring): cstring {.importcpp, nodecl.}
proc join*(s: cstring): cstring {.importcpp, nodecl.}
proc includes*(s: seq[cstring], a: cstring): bool {.importcpp, nodecl.}

var coinlibs {.importc, nodecl.}: JsObject
var bip39 = coinlibs.bip39
var bip39_wordlist = bip39.wordlists.japanese
#proc levenshtein(a, b: JsObject): JsObject {.importc, nodecl.}
proc levens(word, wordlist: JsObject): JsObject {.importc, nodecl.}

var editingWords: cstring = ""
var autocompleteWords: seq[cstring] = @[]

proc checkMnemonic(ev: Event; n: VNode) =
  var s = n.value
  if not s.isNil and s.len > 0:
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
        input_elm.focus()
        input_elm.selectionEnd = newcur
    autocompleteWords = @[]

var chklist: seq[tuple[idx: int, word: cstring, flag: bool, levs: seq[cstring]]]
var wl_japanese = cast[seq[cstring]](bip39.wordlists.japanese.map(proc(x: JsObject): cstring = cast[cstring](x)))
var wl_english = cast[seq[cstring]](bip39.wordlists.english.map(proc(x: JsObject): cstring = cast[cstring](x)))
var wl_select = wl_japanese

proc confirmMnemonic(input_id: cstring): proc() =
  result = proc() =
    let x = getVNodeById(input_id)
    var s = x.value
    if not s.isNil and s.len > 0:
      var words: seq[cstring]
      asm """
        `words` = `s`.replace(/[ 　\n\r]+/g, ' ').trim().split(' ');
      """
      chklist = @[]
      var idx: int = 0
      for word in words:
        if wl_select.includes(cast[cstring](word)):
          chklist.add (idx, word, true, @[])
        else:
          let levs = cast[seq[cstring]](levens(word.toJs, bip39_wordlist))
          chklist.add (idx, word, false, levs)
        inc(idx)
    else:
      chklist = @[]
    autocompleteWords = @[]

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

proc changeLanguage(ev: Event; n: VNode) =
  var langId = cast[int](n.value)
  if langId == 0:
    bip39_wordlist = bip39.wordlists.japanese
    wl_select = wl_japanese
  elif langId == 1:
    bip39_wordlist = bip39.wordlists.english
    wl_select = wl_english
  autocompleteWords = @[]
  chklist = @[]

proc mnemonicEditor(): VNode =
  let input_id: cstring = "minput"
  result = buildHtml(tdiv):
    tdiv(class="ui clearing segment medit-seg"):
      tdiv(class="ui form"):
        tdiv(class="field"):
          label:
            text "Select mnemonic language"
          tdiv(class="ui selection dropdown"):
            input(type="hidden", name="mnemonic-language", value="0", onchange=changeLanguage)
            italic(class="dropdown icon")
            tdiv(class="default text"):
              text "Mnemonic Language"
            tdiv(class="menu"):
              tdiv(class="item", data-value="0"):
                text "Japanese"
              tdiv(class="item", data-value="1"):
                text "English"
        tdiv(class="field minput-field"):
          label:
            text "Import your mnemonic you already have"
          textarea(id=input_id, value=editingWords, onkeyup=checkMnemonic, onmouseup=checkMnemonic, spellcheck="false")
      button(class="ui right floated primary button", onclick=confirmMnemonic(input_id)):
        text "Check"
    tdiv(class="medit-autocomp"):
      for word in autocompleteWords:
        button(class="ui mini teal label", onclick=selectWord(input_id, word)):
          text word
      for i in chklist.low..chklist.high:
        if chklist[i].flag:
          button(class="ui mini green label"):
            italic(class="check circle icon"):
              text " " & chklist[i].word
        else:
          button(class="ui mini pink label"):
            italic(class="x icon"):
              text " " & chklist[i].word
            for lev in chklist[i].levs:
              button(class="ui mini blue basic label", onclick=fixWord(input_id, chklist[i].idx, lev)):
                text lev

proc seedCard(cardInfo: SeedCardInfo): VNode =
  result = buildHtml(tdiv(class="ui card seed-card")):
    tdiv(class="image"):
      tdiv(class="seed-qrcode", data-orig=cardInfo.orig):
        canvas(width="196", height="196")
    tdiv(class="content"):
      tdiv(class="ui tag label mini tag"): text cardInfo.tag
      tdiv(class="header"): text "Seed"
      tdiv(class="meta"):
        span(class="date"): text cardInfo.gen
      var clen = cardInfo.seed.len
      if clen > 0:
        var half = clen - toInt(clen / 2)
        var seed = $cardInfo.seed
        var seed_upper = seed[0..<half]
        var seed_lower = seed[half..^1]
        tdiv(): text seed_upper
        tdiv(): text seed_lower
    tdiv(class="extra content"):
      tdiv(class="inline field"):
        tdiv(class="vector-lavel"): text "Seed Vector:"
        tdiv(class="ui mini input vector-input"):
          input(type="text", placeholder="Type your seed vector")

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
            tdiv(class="ui enter aligned segment seed-seg"):
              if showScanResult:
                tdiv(class="ui link cards seed-card-holder"):
                  seedCard(seedCardInfo)
                  seedCard(seedCardInfo)
                  seedCard(seedCardInfo)
              if showScanning:
                tdiv(class="qr-scanning"):
                  tdiv()
                  tdiv()
              if showScanSeedBtn:
                tdiv(class="ui teal labeled icon button bt-scan-seed", onclick=showQr()):
                  text "Scan seed card with camera"
                  italic(class="camera icon")
              if showCamTools:
                tdiv(class="ui small basic icon buttons camtools"):
                  button(class="ui button", onclick=camChange()):
                    italic(class="camera icon")
                  button(class="ui button", onclick=camClose()):
                    italic(class="window close icon")
              video(id="qrvideo")

          else:
            tdiv(class="ui enter aligned segment mnemonic-seg"):
              mnemonicEditor()

proc afterScript() =
  jq("#section0").remove()
  jq(".ui.dropdown").dropdown()
  if showScanResult:
    asm """
      $('.seed-qrcode canvas').remove();
      $('.seed-qrcode').each(function() {
        $(this).qrcode({
          render: 'canvas',
          ecLevel: 'Q',
          radius: 0.39,
          text: $(this).data('orig'),
          size: 196,
          mode: 2,
          label: '',
          fontname: 'sans',
          fontcolor: '#393939'
        });
      });
    """

appInst = setRenderer(appMain, "main", afterScript)
