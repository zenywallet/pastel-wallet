import jsffi
import unicode, std/editdistance

const levenshtein_js = staticRead("../public/js/levenshtein.js")
{.emit: levenshtein_js.}
{.emit: """
var startTime, endTime;

function start_time() {
  startTime = new Date();
};

function stop_time() {
  endTime = new Date();
  var timeDiff = endTime - startTime;
  console.log('elapsed=' + timeDiff);
}
""".}
const bip39_js = staticRead("../public/js/bip39.js")
{.emit: bip39_js.}

proc levenshtein(a, b: JsObject): JsObject {.importc, nodecl.}
proc start_time() {.importc, nodecl.}
proc stop_time() {.importc, nodecl.}
var bip39 {.importc, nodecl.}: JsObject
var console {.importc, nodecl.}: JsObject

block test:
  for word in bip39.wordlists.japanese:
    let d1 = cast[int](levenshtein(word, "のりもの".toJs))
    let d2 = editDistance($cast[cstring](word), "のりもの")
    if d1 != d2:
      console.log("error:", word, d1, d2)
      break test

  echo "levenshtein.js"
  start_time()
  for i in 1..10:
    for word in bip39.wordlists.japanese:
      discard levenshtein(word, "のりもの".toJs)
  stop_time()

  echo "nim editDistance"
  start_time()
  for i in 1..10:
    for word in bip39.wordlists.japanese:
      discard editDistance($cast[cstring](word), "のりもの")
  stop_time()

  for word1 in bip39.wordlists.japanese:
    for word2 in bip39.wordlists.japanese:
      let d1 = cast[int](levenshtein(word1, word2))
      let d2 = editDistance($cast[cstring](word1), $cast[cstring](word2))
      if d1 != d2:
        console.log("error:", word1, word2, d1, d2)
        break test

  echo "levenshtein.js"
  start_time()
  for word1 in bip39.wordlists.japanese:
    for word2 in bip39.wordlists.japanese:
      discard levenshtein(word1, word2)
  stop_time()

  echo "nim editDistance"
  start_time()
  for word1 in bip39.wordlists.japanese:
    for word2 in bip39.wordlists.japanese:
      discard editDistance($cast[cstring](word1), $cast[cstring](word2))
  stop_time()
