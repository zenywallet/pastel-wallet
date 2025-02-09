# nim js -d:release widgets.nim
# cat widgets.js | grep -o 'offset: "[^"]\+"' | sort | uniq | grep -o '"[^"]\+"' | tr -d '"'
# java -jar closure-compiler.jar --compilation_level ADVANCED_OPTIMIZATIONS --js widgets.js --externs jquery-3.4.1.slim-externs.js --externs jquery-externs.js --externs bip39-externs.js --externs widgets-externs.js > widgets.min.js

include karax / prelude
import jsffi except `&`
import strutils
import unicode
import sequtils

const bip39_js = staticRead("bip39.js")
{.emit: bip39_js.}
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

var document {.importc, nodecl.}: JsObject
#var console {.importc, nodecl.}: JsObject
proc jq(selector: cstring): JsObject {.importcpp: "$$(#)".}
var bip39 {.importc, nodecl.}: JsObject
var bip39_wordlist = bip39.wordlists.japanese
#proc levenshtein(a, b: JsObject): JsObject {.importc, nodecl.}
proc levens(word, wordlist: JsObject): JsObject {.importc, nodecl.}

var autocompleteWords: seq[cstring] = @[]

proc checkMnemonic(ev: Event; n: VNode) =
  var s = n.value
  if not s.isNil and s.len > 0:
    var cur = document.getElementById(n.id).selectionStart
    {.emit: """
      `s` = `s`.substr(0, `cur`).replace(/[ 　\n\r]+/g, ' ').split(' ').slice(-1)[0];
    """.}
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

proc replace*(s, a, b: cstring): cstring {.importcpp, nodecl.}
proc join*(s: cstring): cstring {.importcpp, nodecl.}
proc includes*(s: seq[cstring], a: cstring): bool {.importcpp, nodecl.}

proc selectWord(input_id: cstring, word: cstring): proc() =
  result = proc() =
    let x = getVNodeById(input_id)
    var s = x.value
    if not s.isNil and s.len > 0:
      var input_elm = document.getElementById(input_id)
      var cur = input_elm.selectionStart
      var newcur = cur
      {.emit: """
        var t = `s`.substr(0, `cur`).replace(/[ 　\n\r]+/g, ' ').split(' ').slice(-1)[0];
        if(t && t.length > 0) {
          var tail = `s`.substr(`cur`) || '';
          `s` = `s`.substr(0, `cur` - t.length) + `word` + tail;
          `newcur` = `s`.length - tail.length;
        }
      """.}
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
      {.emit: """
        `words` = `s`.replace(/[ 　\n\r]+/g, ' ').trim().split(' ');
      """.}
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
      {.emit: """
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
      """.}
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
    tdiv(class="ui clearing segment"):
      tdiv(class="ui form"):
        tdiv(class="field"):
          label:
            text "Select mnemonic language"
          tdiv(class="ui selection dropdown"):
            input(type="hidden", name="mnmonic-language", value="0", onchange = changeLanguage)
            italic(class="dropdown icon")
            tdiv(class="default text"):
              text "Mnemonic Language"
            tdiv(class="menu"):
              tdiv(class="item", data-value="0"):
                text "Japanese"
              tdiv(class="item", data-value="1"):
                text "English"
        tdiv(class="field"):
          label:
            text "Import your mnemonic you already have"
          textarea(id = input_id, rows = "5", onkeyup = checkMnemonic, onmouseup = checkMnemonic)
        button(class="ui right floated primary button", onclick = confirmMnemonic(input_id)):
          text "Check"
      for word in autocompleteWords:
        a(class="ui small teal label", onclick = selectWord(input_id, word)):
          text word
      for i in chklist.low..chklist.high:
        if chklist[i].flag:
          a(class="ui green label"):
            italic(class="check circle icon"):
              text " " & chklist[i].word
        else:
          a(class="ui pink label"):
            italic(class="x icon"):
              text " " & chklist[i].word
            for lev in chklist[i].levs:
              a(class="ui blue basic label", onclick = fixWord(input_id, chklist[i].idx, lev)):
                text lev

proc afterScript() =
  jq(".ui.dropdown").dropdown()

setRenderer mnemonicEditor, "mnemonic-editor", afterScript
