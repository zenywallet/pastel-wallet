# Copyright (c) 2019 zenywallet

import rocksdb, cpuinfo, algorithm

type
  RocksDb* = object
    db: rocksdb_t
    dbpath: cstring
    options: rocksdb_options_t
    readOptions*: rocksdb_readoptions_t
    writeOptions*: rocksdb_writeoptions_t
    err: cstring

  KeyType = openarray[byte]
  ValueType = openarray[byte]

  RocksDbError* = object of Exception

  ResultKeyValue* = object
    key*: seq[byte]
    value*: seq[byte]

template rocksdb_checkerr* {.dirty.} =
  if not rocks.err.isNil:
    let err_msg: string = $rocks.err
    rocksdb_free(rocks.err)
    raise newException(RocksDbError, err_msg)

proc open*(rocks: var RocksDb, dbpath: cstring, total_threads: int32 = cpuinfo.countProcessors().int32) =
  rocks.options = rocksdb_options_create()
  rocksdb_options_increase_parallelism(rocks.options, total_threads)
  rocksdb_options_set_create_if_missing(rocks.options, 1)
  rocks.readOptions = rocksdb_readoptions_create()
  rocks.writeOptions = rocksdb_writeoptions_create()
  rocks.dbpath = dbpath
  rocks.db = rocksdb_open(rocks.options, rocks.dbpath, rocks.err.addr)
  rocksdb_checkerr

proc close*(rocks: var RocksDb) =
  if not rocks.err.isNil:
    rocksdb_free(rocks.err)
    rocks.err = nil
  if not rocks.writeOptions.isNil:
    rocksdb_writeoptions_destroy(rocks.writeOptions)
    rocks.writeOptions = nil
  if not rocks.readOptions.isNil:
    rocksdb_readoptions_destroy(rocks.readOptions)
    rocks.readOptions = nil
  if not rocks.options.isNil:
    rocksdb_options_destroy(rocks.options)
    rocks.options = nil
  if not rocks.db.isNil:
    rocksdb_close(rocks.db)
    rocks.db = nil

proc put*(rocks: var RocksDb, key: KeyType, val: ValueType) =
  rocksdb_put(rocks.db,
    rocks.writeOptions,
    cast[cstring](unsafeAddr key[0]), key.len,
    cast[cstring](if val.len > 0: unsafeAddr val[0] else: nil), val.len,
    rocks.err.addr)
  rocksdb_checkerr

proc get*(rocks: var RocksDb, key: KeyType): seq[byte] =
  var len: csize
  var data = rocksdb_get(rocks.db, rocks.readOptions,
    cast[cstring](unsafeAddr key[0]), key.len,
    addr len, rocks.err.addr)
  rocksdb_checkerr
  var s: seq[byte] = newSeq[byte](len)
  if not data.isNil and len > 0:
    copyMem(addr s[0], unsafeAddr data[0], len)
  result = s

proc get_iter_key_value(iter: rocksdb_iterator_t): ResultKeyValue =
  var key_str, value_str: cstring
  var key_len, value_len: csize
  key_str = rocksdb_iter_key(iter, addr key_len)
  value_str = rocksdb_iter_value(iter, addr value_len)
  var key_seq: seq[byte] = newSeq[byte](key_len)
  var value_seq: seq[byte] = newSeq[byte](value_len)
  if key_len > 0:
    copyMem(addr key_seq[0], unsafeAddr key_str[0], key_len)
  if value_len > 0:
    copyMem(addr value_seq[0], unsafeAddr value_str[0], value_len)
  result = ResultKeyValue(key: key_seq, value: value_seq)

proc gets*(rocks: var RocksDb, key: KeyType): seq[ResultKeyValue] =
  var iter: rocksdb_iterator_t = rocksdb_create_iterator(rocks.db, rocks.readOptions)
  rocksdb_iter_seek(iter, cast[cstring](unsafeAddr key[0]), key.len)
  while cast[bool](rocksdb_iter_valid(iter)):
    let kv = get_iter_key_value(iter)
    if kv.key[0..key.high] != key:
      break
    result.add(get_iter_key_value(iter))
    rocksdb_iter_next(iter)
  rocksdb_iter_destroy(iter);

iterator gets*(rocks: var RocksDb, key: KeyType): ResultKeyValue =
  var iter: rocksdb_iterator_t
  try:
    iter = rocksdb_create_iterator(rocks.db, rocks.readOptions)
    rocksdb_iter_seek(iter, cast[cstring](unsafeAddr key[0]), key.len)
    while cast[bool](rocksdb_iter_valid(iter)):
      let kv = get_iter_key_value(iter)
      var i = key.high
      while i >= 0:
        if kv.key[i] != key[i]:
          break
        dec(i)
      yield kv
      rocksdb_iter_next(iter)
  finally:
    rocksdb_iter_destroy(iter);

proc key_countup(key: openarray[byte]): tuple[carry: bool, key: seq[byte]] =
  var k = newSeq[byte](key.len)
  var carry = true
  for i in countdown(key.high, 0):
    if carry:
      k[i] = (key[i] + 1) and 0xff
      if k[i] != 0:
        carry = false
    else:
      k[i] = key[i]
  if carry:
    k.fill(0xff)
  (carry, k)

proc getsReverse*(rocks: var RocksDb, key: KeyType): seq[ResultKeyValue] =
  var iter: rocksdb_iterator_t = rocksdb_create_iterator(rocks.db, rocks.readOptions)
  let (carry, lastkey) = key_countup(key)
  if carry:
    rocksdb_iter_seek(iter, cast[cstring](unsafeAddr lastkey[0]), lastkey.len)
  else:
    rocksdb_iter_seek_for_prev(iter, cast[cstring](unsafeAddr lastkey[0]), lastkey.len)
  while cast[bool](rocksdb_iter_valid(iter)):
    let kv = get_iter_key_value(iter)
    var i = key.high
    while i >= 0:
      if kv.key[i] != key[i]:
        break
      dec(i)
    result.add(get_iter_key_value(iter))
    rocksdb_iter_prev(iter)
  rocksdb_iter_destroy(iter)

iterator getsReverse*(rocks: var RocksDb, key: KeyType): ResultKeyValue =
  var iter: rocksdb_iterator_t
  try:
    iter = rocksdb_create_iterator(rocks.db, rocks.readOptions)
    let (carry, lastkey) = key_countup(key)
    if carry:
      rocksdb_iter_seek(iter, cast[cstring](unsafeAddr lastkey[0]), lastkey.len)
    else:
      rocksdb_iter_seek_for_prev(iter, cast[cstring](unsafeAddr lastkey[0]), lastkey.len)
    while cast[bool](rocksdb_iter_valid(iter)):
      let kv = get_iter_key_value(iter)
      var i = key.high
      while i >= 0:
        if kv.key[i] != key[i]:
          break
        dec(i)
      yield kv
      rocksdb_iter_prev(iter)
  finally:
    rocksdb_iter_destroy(iter)
