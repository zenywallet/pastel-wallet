# Copyright (c) 2026 zenywallet

import std/macros

proc mask64(b: byte, len: int): uint64 {.compileTime.} =
  if len > 0:
    result = b
    for i in 1..<len:
      result = result shl 8
      result = result or b
  else:
    result = 0

proc mask32(b: byte, len: int): uint32 {.compileTime.} =
  if len > 0:
    result = b
    for i in 1..<len:
      result = result shl 8
      result = result or b
  else:
    result = 0

converter toUncheckedArrayByte*(p: pointer): ptr UncheckedArray[byte] =
  cast[ptr UncheckedArray[byte]](p)

converter toUncheckedArrayByte*(p: ptr byte): ptr UncheckedArray[byte] =
  cast[ptr UncheckedArray[byte]](p)

macro cmpString*(p1: ptr UncheckedArray[byte], p2: static string): bool =
  var s = nnkIfStmt.newTree()
  var left = p2.len
  var pos = 0

  while left >= 8:
    var val = cast[ptr uint](addr p2[pos])[]
    var cond = quote do: cast[ptr uint](addr `p1`[`pos`])[] != `val`
    s.add nnkElifBranch.newTree(
      cond,
      nnkStmtList.newTree(
        newIdentNode("false")
      )
    )
    dec(left, 8)
    inc(pos, 8)

  if left > 4:
    var mask = mask64(0xff.byte, left)
    var val = cast[ptr uint](addr p2[pos])[] and mask
    var cond = quote do: (cast[ptr uint](addr `p1`[`pos`])[] and `mask`) != `val`
    s.add nnkElifBranch.newTree(
      cond,
      nnkStmtList.newTree(
        newIdentNode("false")
      )
    )
  elif left == 4:
    var val = cast[ptr uint32](addr p2[pos])[]
    var cond = quote do: cast[ptr uint32](addr `p1`[`pos`])[] != `val`
    s.add nnkElifBranch.newTree(
      cond,
      nnkStmtList.newTree(
        newIdentNode("false")
      )
    )
  elif left > 0:
    var mask = mask32(0xff.byte, left)
    var val = cast[ptr uint32](addr p2[pos])[] and mask
    var cond = quote do: (cast[ptr uint32](addr `p1`[`pos`])[] and `mask`) != `val`
    s.add nnkElifBranch.newTree(
      cond,
      nnkStmtList.newTree(
        newIdentNode("false")
      )
    )

  s.add nnkElse.newTree(
    nnkStmtList.newTree(
      newIdentNode("true")
    )
  )
  s
