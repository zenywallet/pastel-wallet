import ../deps/zip/zip/zlib
import unittest

proc toString(str: seq[char]): string =
  result = newStringOfCap(len(str))
  for ch in str:
    add(result, ch)

test "test1":
  let text = "The quick brown fox jumps over the lazy dog"
  let text2 = uncompress(compress(text, stream=RAW_DEFLATE), stream=RAW_DEFLATE)
  check(text == text2)

test "test2":
  let data = cast[seq[char]](@[byte 1, 2, 3, 4])
  let data_compress = cast[seq[char]](@[byte 99, 100, 98, 102, 1, 0])
  let data2 = compress(data.toString, stream=RAW_DEFLATE)
  let data3 = uncompress(data2, stream=RAW_DEFLATE)
  check(data == data3)
  check(data2 == data_compress)
