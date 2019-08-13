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

var document {. importc, nodecl .}: JsObject
#var console {. importc, nodecl .}: JsObject
#proc jq(selector: JsObject): JsObject {. importcpp: "$(#)" .}
var bip39 {. importc, nodecl .}: JsObject
#proc levenshtein(a, b: JsObject): JsObject {. importc, nodecl .}
proc levens(word, wordlist: JsObject): JsObject {. importc, nodecl .}

var autocompleteWords: seq[cstring] = @[]

proc checkMnemonic(ev: Event; n: VNode) =
  var s = n.value
  var cur = document.getElementById(n.id).selectionStart
  asm """
    `s` = `s`.substr(0, `cur`).replace(/[ 　\n\r]+/g, ' ').split(' ').slice(-1)[0]
  """
  if not s.isNil and s.len > 0:
    var tmplist: seq[cstring] = @[]
    for word in bip39.wordlists.japanese:
      let w = cast[cstring](word)
      if w.startsWith(s):
        tmplist.add(w)
    autocompleteWords = tmplist
  else:
    autocompleteWords = @[]

proc replace*(s, a, b: cstring): cstring {.importcpp, nodecl.}
proc join*(s: cstring): cstring {.importcpp, nodecl.}
proc includes*(s: seq[cstring], a: cstring): bool {.importcpp, nodecl.}

proc selectWord(input_id: cstring, word: cstring): proc() =
  result = proc() =
    let x = getVNodeById(input_id)
    var s = x.value
    var cur = document.getElementById(input_id).selectionStart
    asm """
      var t = `s`.substr(0, `cur`).replace(/[ 　\n\r]+/g, ' ').split(' ').slice(-1)[0]
      if(t && t.length > 0) {
        var tail = `s`.substr(`cur`) || '';
        `s` = `s`.substr(0, `cur` - t.length) + `word` + tail;
      }
    """
    x.setInputText(s)
    autocompleteWords = @[]

var chklist: seq[tuple[idx: int, word: cstring, flag: bool, levs: seq[cstring]]]
var wl_japanese = cast[seq[cstring]](bip39.wordlists.japanese.map(proc(x: JsObject): cstring = cast[cstring](x)))
proc confirmMnemonic(input_id: cstring): proc() =
  result = proc() =
    let x = getVNodeById(input_id)
    var s = x.value
    var words: seq[cstring]
    asm """
      `words` = `s`.replace(/[ 　\n\r]+/g, ' ').trim().split(' ');
    """
    chklist = @[]
    var idx: int = 0
    for word in words:
      if wl_japanese.includes(cast[cstring](word)):
        chklist.add (idx, word, true, @[])
      else:
        let levs = cast[seq[cstring]](levens(word.toJs, bip39.wordlists.japanese))
        chklist.add (idx, word, false, levs)
      inc(idx)
    autocompleteWords = @[]

proc fixWord(input_id: cstring, idx: int, word: cstring): proc() =
  result = proc() =
    let x = getVNodeById(input_id)
    var s = x.value
    var ret: cstring
    asm """
      `ret` = "";
      var count = 0;
      var find = false;
      var skip = false;
      for(var t in `s`) {
        if(/[ 　\n\r]/.test(`s`[t])) {
          `ret` += `s`[t]
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
              `ret` += `s`[t]
            }
          }
        }
      }
    """
    x.setInputText(ret)

proc mnemonicEditor(): VNode =
  let input_id: cstring = "minput"
  result = buildHtml(tdiv):
    tdiv(class="ui clearing segment"):
      tdiv(class="ui form"):
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

setRenderer mnemonicEditor, "mnemonic-editor"
