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
  var video, canvasElement, canvas, seedseg;
  var abort = false;
  var showing = false;
  //var scandata = null;
  //var loadingMessage = document.getElementById("loadingMessage");
  //var outputContainer = document.getElementById("output");
  //var outputMessage = document.getElementById("outputMessage");
  //var outputData = document.getElementById("outputData");

  function drawLine(begin, end, color) {
    canvas.beginPath();
    canvas.moveTo(begin.x, begin.y);
    canvas.lineTo(end.x, end.y);
    canvas.lineWidth = 4;
    canvas.strokeStyle = color;
    canvas.stroke();
  }

  function checkRange(rect, x1, y1, x2, y2) {
    return (rect.x > x1 && rect.x < x2
      && rect.y > y1 && rect.y < y2);
  }

  var cb_done = function() {}

  function qr_stop() {
    camera_scanning(false);
    video.pause();
    if(video.srcObject) {
      video.srcObject.getTracks().forEach(function(track) {
        track.stop();
      });
    }
    video.removeAttribute('src');
    video.load();
  }

  var skip_first_tick = false;
  function tick() {
    if(video.readyState === video.HAVE_ENOUGH_DATA) {
      camera_scanning(true);
      canvasElement.height = video.videoHeight;
      canvasElement.width = video.videoWidth;
      canvas.drawImage(video, 0, 0, canvasElement.width, canvasElement.height);
      var imageData = canvas.getImageData(0, 0, canvasElement.width, canvasElement.height);
      var code = jsQR(imageData.data, imageData.width, imageData.height, {
        inversionAttempts: "dontInvert",
      });
      if(code) {
        drawLine(code.location.topLeftCorner, code.location.topRightCorner, "#ff3b58");
        drawLine(code.location.topRightCorner, code.location.bottomRightCorner, "#ff3b58");
        drawLine(code.location.bottomRightCorner, code.location.bottomLeftCorner, "#ff3b58");
        drawLine(code.location.bottomLeftCorner, code.location.topLeftCorner, "#ff3b58");

        var sw = seedseg.offsetWidth - 28;
        var sh = seedseg.offsetHeight - 28;
        if(canvasElement.width > 0 && sw > 0) {
          var mergin = 14;
          var c = canvasElement.height / canvasElement.width;
          var s = sh / sw;
          var x1, y1, x2, y2;
          if(c < s) {
            var w = canvasElement.height / s;
            x1 = (canvasElement.width - w) / 2;
            y1 = 0;
            x2 = x1 + w;
            y2 = canvasElement.height;
            x1 += mergin;
            x2 -= mergin;
            y1 += mergin;
            y2 -= mergin;
          } else {
            var h = canvasElement.width * s;
            x1 = 0;
            y1 = (canvasElement.height - h) / 2;
            x2 = canvasElement.width;
            y2 = y1 + h;
            x1 += mergin;
            x2 -= mergin;
            y1 += mergin;
            y2 -= mergin;
          }
          if(skip_first_tick
            && checkRange(code.location.topLeftCorner, x1, y1, x2, y2)
            && checkRange(code.location.topRightCorner, x1, y1, x2, y2)
            && checkRange(code.location.bottomRightCorner, x1, y1, x2, y2)
            && checkRange(code.location.bottomLeftCorner, x1, y1, x2, y2)) {
            console.log(code.data);
            qr_stop();
            if(!abort && cb_done) {
              cb_done(code.data);
            }
            return;
          }
          skip_first_tick = true;
        }
      }
    }
    if(abort) {
      return;
    }
    requestAnimationFrame(tick);
  }

  var mode_show = true;
  var video = null;
  var qr_instance = null;

  var prev_camera_scanning_flag = false;
  function camera_scanning(flag) {
    if(prev_camera_scanning_flag != flag) {
      if(flag) {
        $('.qr-scanning').show();
      } else {
        $('.qr-scanning').hide();
      }
      prev_camera_scanning_flag = flag;
    }
  }

  function video_status_change() {
    if(mode_show) {
      canvasElement.hidden = false;
      $('.bt-scan-seed').css('visibility', 'hidden');
      $('.camtools').css('visibility', 'visible');
    } else {
      camera_scanning(false);
      $('.camtools').css('visibility', 'hidden');
      $('.bt-scan-seed').css('visibility', 'visible');
      if(canvasElement) {
        canvasElement.hidden = true;
      }
    }
  }

  return {
    show: function(cb) {
      mode_show = true;
      showing = false;
      abort = false;
      skip_first_tick = false;
      video = video || document.createElement("video");
      canvasElement = document.getElementById("qrcanvas");
      canvas = canvasElement.getContext("2d");
      seedseg = document.getElementById("seed-seg");
      cb_done = cb;

      // Use facingMode: environment to attemt to get the front camera on phones
      navigator.mediaDevices.getUserMedia({ video: { facingMode: "environment" } }).then(function(stream) {
        video.srcObject = stream;
        video.setAttribute("playsinline", true); // required to tell iOS safari we don't want fullscreen
        video.play();
        video_status_change();
        showing = true;
        requestAnimationFrame(tick);
      });
    },
    hide: function(rescan) {
      if(mode_show) {
        abort = true;
        if(showing) {
          qr_stop();
          showing = false;
        }
        if(canvas && canvasElement) {
          canvas.clearRect(0, 0, canvasElement.width, canvasElement.height);
        }
        if(rescan) {
          mode_show = false;
          video_status_change();
        } else {
          if(canvasElement) {
            canvasElement.hidden = true;
          }
        }
        mode_show = false;
      }
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
  PassphraseEdit
  PassphraseDone
  Wallet

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
var mnemonicFulfill = false
var passphraseFulfill = false

proc viewSelector(view: ViewType) =
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
    showScanning = false
    showCamTools = false
    showScanResult = true
    showPage2 = true
  of MnemonicEdit:
    showPage2 = false
  of MnemonicFulfill:
    showPage2 = true
  of SetPassphrase:
    showScanSeedBtn = true
    showScanning = true
    showCamTools = true
    showScanResult = false

    showScanSeedBtn2 = true
    showScanning2 = true
    showCamTools2 = true
    showScanResult2 = false

    showPage1 = false
    showPage2 = true
  of KeyAfterScan:
    showPage3 = true
  of PassphraseDone:
    showPage3 = true
  of Wallet:
    showPage1 = false
    showPage2 = false
    showPage3 = true
  else:
    discard

  appInst.redraw()

var jsViewSelector {.importc, nodecl.}: JsObject
asm """
  jsViewSelector = `viewSelector`
"""

#proc importTypeButtonClass(importType: ImportType): cstring =
#  if importType == currentImportType:
#    "ui olive button"
#  else:
#    "ui grey button"

proc importSelector(importType: ImportType): proc() =
  result = proc() =
    asm """
      qrReader.hide(true);
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

proc protectSelector(protectType: ProtectType): proc() =
  result = proc() =
    asm """
      qrReader.hide(true);
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
      //qrReader.show(`cbSeedQrDone`);
    """

proc camClose(): proc() =
  result = proc() =
    asm """
      qrReader.hide(true);
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
var chklist: seq[tuple[idx: int, word: cstring, flag: bool, levs: seq[cstring]]]
var prevCheckWord: cstring = ""

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
      var allvalid = true
      for word in words:
        if wl_select.includes(cast[cstring](word)):
          chklist.add (idx, word, true, @[])
        else:
          let levs = cast[seq[cstring]](levens(word.toJs, bip39_wordlist))
          chklist.add (idx, word, false, levs)
          allvalid = false
        inc(idx)
      if allvalid and idx >= 12 and idx mod 3 == 0:
        mnemonicFulfill = true
        viewSelector(MnemonicFulfill)
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
      editingWords = ret
      confirmMnemonic(input_id)()

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
        seed_upper = seed_upper[0..3] & " " & seed_upper[4..7] & " " & seed_upper[8..11] & " " & seed_upper[12..15] & " " & seed_upper[16..19] & " " & seed_upper[20..^1]
        seed_lower = seed_lower[0..3] & " " & seed_lower[4..7] & " " & seed_lower[8..11] & " " & seed_lower[12..15] & " " & seed_lower[16..19] & " " & seed_lower[20..^1]
        tdiv(class="seed-body"):
          tdiv(class="seed"): text seed_upper
          tdiv(class="seed"): text seed_lower
    tdiv(class="extra content"):
      tdiv(class="inline field"):
        tdiv(class="vector-lavel"): text "Seed Vector:"
        tdiv(class="ui mini input vector-input"):
          input(type="text", placeholder="Type your seed vector")
    tdiv(class="bt-seed-del"):
      button(class="circular ui icon mini button"):
        italic(class="cut icon")

proc changePassphrase(ev: Event; n: VNode) =
  discard

proc confirmPassphrase(ev: Event; n: VNode) =
  passphraseFulfill = true
  showPage3 = true

proc passphraseEditor(): VNode =
  result = buildHtml(tdiv):
    tdiv(class="ui clearing segment medit-seg"):
      tdiv(class="ui form"):
        tdiv(class="field"):
          label:
            text "Input passphrase"
          input(type="text", name="input-passphrase", value="", onchange=changePassphrase)
      button(class="ui right floated primary button", onclick=confirmPassphrase):
        text "Save"

proc appMain(): VNode =
  result = buildHtml(tdiv):
    if showPage1:
      section(id="section1", class="section"):
        tdiv(class="intro"):
          tdiv(class="intro-head"):
            tdiv(class="caption"): text "Pastel Wallet"
            tdiv(class="ui container method-selector"):
              tdiv(class="title"): text "Import the master seed to start your wallet."
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
                  tdiv(class="ui link cards seed-card-holder"):
                    seedCard(seedCardInfo)
                    seedCard(seedCardInfo)
                    tdiv(class="seed-add-container"):
                      button(class="circular ui icon button bt-add-seed"):
                        italic(class="plus icon")
                  a(class="pagenext", href="#section2"):
                    span()
                    text "Next"
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
                canvas(id="qrcanvas")
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
                   You will need key card or passphrase before sending your coins.
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
                  tdiv(class="ui link cards seed-card-holder"):
                    seedCard(seedCardInfo)
                    seedCard(seedCardInfo)
                    tdiv(class="seed-add-container"):
                      button(class="circular ui icon button bt-add-seed"):
                        italic(class="plus icon")
                  a(class="pagenext", href="#section2"):
                    span()
                    text "Next"
                if showScanning2:
                  tdiv(class="qr-scanning"):
                    tdiv()
                    tdiv()
                if showScanSeedBtn2:
                  tdiv(class="ui teal labeled icon button bt-scan-seed", onclick=showQr()):
                    text "Scan key card with camera"
                    italic(class="camera icon")
                if showCamTools2:
                  tdiv(class="ui small basic icon buttons camtools"):
                    button(class="ui button", onclick=camChange()):
                      italic(class="camera icon")
                    button(class="ui button", onclick=camClose()):
                      italic(class="window close icon")
                canvas(id="qrcanvas")
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
          tdiv(class="intro-head"):
            tdiv(class="caption"): text "Pastel Wallet"
          tdiv(class="intro-body"):
            tdiv(id="seed-seg", class="ui left aligned segment seed-seg")

proc afterScript() =
  jq("#section0").remove()
  jq(".ui.dropdown").dropdown()
  if showScanResult:
    asm """
      function seedCardQrUpdate() {
        $('.seed-qrcode').each(function() {
          $(this).find('canvas').remove();
          var fillcolor;
          if($(this).hasClass('active')) {
            fillcolor = '#000'
          } else {
            fillcolor = '#f8f8f8';
          }
          $(this).qrcode({
            render: 'canvas',
            ecLevel: 'Q',
            radius: 0.39,
            text: $(this).data('orig'),
            size: 196,
            mode: 2,
            label: '',
            fontname: 'sans',
            fontcolor: '#393939',
            fill: fillcolor
          });
        });
      }
      $('.seed-qrcode').last().addClass('active');
      seedCardQrUpdate();

      $('.seed-card').off('click').on('click', function() {
        if(!$(this).find('.seed-qrcode').hasClass('active')) {
          $('.seed-card').each(function() {
            $(this).find('.seed-qrcode').removeClass('active');
          });
          $(this).find('.seed-qrcode').addClass('active');
          seedCardQrUpdate();
        }
      });
    """

  if showScanResult or mnemonicFulfill:
    asm """
      target_page_scroll = '#section2';
      page_scroll_done = function() {
        $('a.pagenext').css('visibility', 'hidden');
        $('#section1').hide();
        window.scrollTo(0, 0);
        jsViewSelector(5);
        page_scroll_done = function() {};
      }
    """
  if showScanResult2 or passphraseFulfill:
    asm """
      target_page_scroll = '#section3';
      page_scroll_done = function() {
        $('a.pagenext').css('visibility', 'hidden');
        $('#section2').hide();
        window.scrollTo(0, 0);
        jsViewSelector(8);
        page_scroll_done = function() {};
      }
    """
  if showScanResult or mnemonicFulfill or showScanResult2 or passphraseFulfill:
    asm """        
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

appInst = setRenderer(appMain, "main", afterScript)
#viewSelector(SeedAfterScan)
