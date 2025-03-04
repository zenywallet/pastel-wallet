# Copyright (c) 2019 zenywallet
# nim c -d:release -d:emscripten -o:yespower.js yespower.nim

{.compile: "../deps/yespower-1.0.1/sha256.c".}
{.compile: "../deps/yespower-1.0.1/yespower-opt.c".}
{.emit: """
#include <string.h>
#include "../deps/yespower-1.0.1/yespower.h"

static yespower_params_t params = {
  .version = YESPOWER_0_5,
  .N = 2048,
  .r = 8,
  .pers = (const uint8_t *)"Client Key",
  .perslen = strlen("Client Key")
};

static yespower_params_t params_n2r8 = {
  .version = YESPOWER_1_0,
  .N = 2048,
  .r = 8,
  .pers = (const uint8_t *)NULL,
  .perslen = 0
};

static yespower_params_t params_n4r16 = {
  .version = YESPOWER_1_0,
  .N = 4096,
  .r = 16,
  .pers = (const uint8_t *)NULL,
  .perslen = 0
};

static yespower_params_t params_n4r32 = {
  .version = YESPOWER_1_0,
  .N = 4096,
  .r = 32,
  .pers = (const uint8_t *)NULL,
  .perslen = 0
};
""".}

proc yespower_hash*(input: ptr UncheckedArray[byte], input_size: int, output: ptr UncheckedArray[byte]): int {.exportc.} =
  {.emit: "return yespower_tls((uint8_t *)`input`, `input_size`, &params, `output`);".}

proc yespower_n2r8*(input: ptr UncheckedArray[byte], input_size: int, output: ptr UncheckedArray[byte]): int {.exportc.} =
  {.emit: "return yespower_tls((uint8_t *)`input`, `input_size`, &params_n2r8, `output`);".}

proc yespower_n4r16*(input: ptr UncheckedArray[byte], input_size: int, output: ptr UncheckedArray[byte]): int {.exportc.} =
  {.emit: "return yespower_tls((uint8_t *)`input`, `input_size`, &params_n4r16, `output`);".}

proc yespower_n4r32*(input: ptr UncheckedArray[byte], input_size: int, output: ptr UncheckedArray[byte]): int {.exportc.} =
  {.emit: "return yespower_tls((uint8_t *)`input`, `input_size`, &params_n4r32, `output`);".}


when isMainModule:
  var a: array[80, byte]
  var b: array[32, byte]
  for i in 0..<80:
    a[i] = cast[byte](i)

  for i in 0..<1000:
    discard yespower_hash(cast[ptr UncheckedArray[byte]](addr a[0]), 80, cast[ptr UncheckedArray[byte]](addr b[0]))
  echo a
  echo b
