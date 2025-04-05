# Copyright (c) 2019 zenywallet

import std/jsffi
import std/macros
#import zenyjs
import zenyjs/core
#import zenyjs/bip32 as zenyjs_bip32
import zenyjs/jsuint64
import stor as storMod
import base58

type
  WalletError = object of CatchableError

var coinlibs {.importc, nodecl.}: JsObject
var pastel {.importc, nodecl.}: JsObject
var Notify {.importc, nodecl.}: JsObject
var network {.importc, nodecl.}: JsObject

proc mnemonic_replace_trim(s: cstring): JsObject {.importcpp: "#.replace(/[ 　\\n\\r]+/g, ' ').trim()".} # /[ \u3000\n\r]+/g
proc match_regexp2(s: cstring): JsObject {.importcpp: "#.match(/.{2}/g)".}
proc `^=`(x, y: JsObject): JsObject {.importjs: "(# ^= #)", discardable.}
proc newUint64*(val: SomeSignedInt): Uint64 = newUint64(cstring($val.uint))
proc newTransactionBuilder(coin, network: JsObject): JsObject {.importcpp: "new #.TransactionBuilder(#)".}

proc Wallet*() {.exportc.} =
  var self = this
  var bip39 = coinlibs.bip39
  var bip32 = coinlibs.bip32
  var coin = coinlibs.coin
  var network = coin.networks[pastel.config.network.to(cstring)]
  var stor = newStor()
  var u_hdpath = "m/44'/123'/0'".cstring

  proc getWordList(mlang: int): JsObject =
    if mlang == 1:
      return bip39.wordlists.japanese
    else:
      return bip39.wordlists.english

  self.getMnemonicToSeed = proc(mnemonic, password: cstring): JsObject =
    var m = mnemonic.mnemonic_replace_trim()
    bip39.mnemonicToSeedSync(m, password)

  var MnemonicSeedType = JsObject{
    0: "Unknown".cstring,
    1: "Standard".cstring,
    2: "Standard with password".cstring,
    101: "Non-standard 1".cstring,
    102: "Non-standard 2".cstring
  }

  self.getMnemonicSeedType = proc(seedType: int): cstring =  MnemonicSeedType[seedType].to(cstring)

  self.getNonStandardMnemonicToSeeds = proc(mnemonic: cstring, mlang: int): JsObject =
    var seeds = [].toJs
    var m = mnemonic.mnemonic_replace_trim()
    if m.split(" ".cstring).length.to(int) == 24:
      var entropy = bip39.mnemonicToEntropy(m, getWordList(mlang), true)
      seeds.push(JsObject{seed: entropy, type: 101})
      if mlang == 0:
        var m2 = bip39.entropyToMnemonic(entropy, getWordList(1))
        var seed2 = bip39.mnemonicToSeedSync(m2)
        seeds.push(JsObject{seed: seed2, type: 102})
    seeds

  self.getMnemonicToSeeds = proc(mnemonic: cstring, mlang: int, password: cstring): JsObject =
    var seeds = [].toJs
    var m = mnemonic.mnemonic_replace_trim()
    var seed = bip39.mnemonicToSeedSync(m, password)
    seeds.push(JsObject{seed: seed, type: if password.toJs.to(bool): 2 else: 1})
    var nonstd_seeds = self.getNonStandardMnemonicToSeeds(mnemonic, mlang)
    seeds = seeds.concat(nonstd_seeds)
    seeds

  self.setHdpath = proc(hdpath: cstring) = u_hdpath = hdpath

  self.getHdNodeKeyPairs = proc(seed: JsObject, hdpath: cstring): JsObject =
    var node = if jsTypeof(seed) == "string": bip32.fromSeedHex(seed, network) else: bip32.fromSeed(seed, network)
    var child = node.derivePath(hdpath.toJs or u_hdpath.toJs)
    JsObject{priv: child.toBase58(), pub: child.neutered().toBase58()}

  self.getHdNodePrivate = proc(seed: JsObject, hdpath: cstring): JsObject =
    var node = if jsTypeof(seed) == "string": bip32.fromSeedHex(seed, network) else: bip32.fromSeed(seed, network)
    var child = node.derivePath(hdpath.toJs or u_hdpath.toJs)
    child.toBase58()

  self.getHdNodePublic = proc(seed: JsObject, hdpath: cstring): JsObject =
    var node = if jsTypeof(seed) == "string": bip32.fromSeedHex(seed, network) else: bip32.fromSeed(seed, network)
    var child = node.derivePath(hdpath.toJs or u_hdpath.toJs)
    child.neutered().toBase58()

  self.resetXpubFromSeed = proc(seed: JsObject, hdpath: cstring) =
    stor.del_xpubs()
    var xpub = self.getHdNodePublic(seed, hdpath.toJs or u_hdpath.toJs)
    stor.add_xpub(xpub)

  self.resetXpubFromMnemonic = proc(mnemonic: cstring, mlang: int, password: cstring, hdpath: cstring) =
    var seeds = self.getMnemonicToSeeds(mnemonic, mlang, password)
    stor.del_xpubs()
    for i in 0..<seeds.length.to(int):
      var seed = seeds[i].seed
      var xpub = self.getHdNodePublic(seed, hdpath.toJs or u_hdpath.toJs)
      stor.add_xpub(xpub)

  proc error(msg: cstring) = console.log("ERROR: ".cstring & msg)

  var u_xpubs = [].toJs
  var u_utxos = [].toJs
  var u_unconfs = [].toJs
  var u_nodes = JsObject{}

  self.getXpubs = proc(): JsObject =
    u_xpubs = stor.get_xpubs()
    u_xpubs

  self.getXpub = proc(xpub_idx: int): JsObject = u_xpubs[xpub_idx]

  self.checkXpubs = proc(xpubs: JsObject): bool =
    for i in 0..<xpubs.length.to(int):
      if u_xpubs.indexOf(xpubs[i]).to(int) < 0:
        return false
    return true

  var address_caches = JsObject{}
  proc checkUtxo(utxo: JsObject): bool =
    var xpub = u_xpubs[utxo.xpub_idx.to(int)]
    if not xpub.to(bool):
      error("xpub not found".cstring)
      return false
    if not u_nodes[xpub.to(cstring)].to(bool):
      u_nodes[xpub.to(cstring)] = bip32.fromBase58(xpub, network)
    var idx = (utxo.xpub_idx + "-".toJs + utxo.change + "-".toJs + utxo.index).to(cstring)
    var cache = address_caches[idx]
    if cache.toJs.to(bool):
      if utxo.address != cache.p2pkh:
        var p2wpkh = address_caches[idx]["p2wpkh".cstring]
        if not p2wpkh.to(bool):
          var child = u_nodes[xpub.to(cstring)].derive(utxo.change).derive(utxo.index)
          p2wpkh = coin.payments.p2wpkh(JsObject{pubkey: child.publicKey, network: network}).address
          address_caches[idx]["p2wpkh".cstring] = p2wpkh
        if utxo.address != p2wpkh:
          var p2sh = address_caches[idx]["p2sh".cstring]
          if not p2sh.to(bool):
            p2sh = coin.payments.p2sh(JsObject{redeem: p2wpkh, network: network}).address
            address_caches[idx]["p2sh".cstring] = p2sh
          if utxo.address != p2sh:
            error("invalid utxo address".cstring)
            return false
    else:
      var child = u_nodes[xpub.to(cstring)].derive(utxo.change).derive(utxo.index)
      var p2pkh = coin.payments.p2pkh(JsObject{pubkey: child.publicKey, network: network}).address
      address_caches[idx] = JsObject{child: child, p2pkh: p2pkh}
      if utxo.address != p2pkh:
        var p2wpkh = coin.payments.p2wpkh(JsObject{pubkey: child.publicKey, network: network}).address
        address_caches[idx]["p2wpkh".cstring] = p2wpkh
        if utxo.address != p2wpkh:
          var p2sh = coin.payments.p2sh(JsObject{redeem: p2wpkh, network: network}).address
          address_caches[idx]["p2sh".cstring] = p2sh
          if utxo.address != p2sh:
            error("invalid utxo address".cstring)
            return false
    return true

  proc checkUtxos(utxos: JsObject): bool {.discardable.} =
    var tmp_utxos = [].toJs
    for i in 0..<utxos.length.to(int):
      tmp_utxos.push(utxos[i])

    proc worker() =
      var utxo = tmp_utxos.shift()
      if utxo.to(bool):
        if checkUtxo(utxo):
          setTimeout(worker, 10)
        else:
          discard Notify.show("Error".cstring, "Server is invalid and unreliable. Stop using this wallet.".cstring, Notify.msgtype.error)
    worker()
    true

  self.setUtxos = proc(utxos: JsObject) =
    u_utxos = utxos
    checkUtxos(utxos)

  self.addUtxos = proc(utxos: JsObject, deduplicate: bool = false): bool =
    if checkUtxos(utxos):
      if deduplicate:
        error("unimplemented".cstring)
        return false
      else:
        u_utxos.concat(utxos)
      return true
    return false

  self.getUtxos = proc(): JsObject = u_utxos

  self.setUnconfs = proc(data: JsObject) =
    var mytxs = JsObject{}
    for txid, tx in data.txs:
      var send_addrs = JsObject{}
      for txa, v in tx.data:
        for i in 0..<v.length.to(int):
          if i == 0:
            send_addrs[txa] = 1
      if Object.keys(send_addrs).length.to(int) > 0:
        mytxs[txid] = send_addrs

    var spents_unconfs = JsObject{}
    for val in data.addrs:
      if val.spents.to(bool):
        for spent in val.spents:
          spents_unconfs[(spent.txid + "-".toJs + spent.n).to(cstring)] = 1

    var unconf_list = [].toJs
    for a, val in data.addrs:
      if val.txouts.to(bool):
        for txout in val.txouts:
          if not spents_unconfs[(txout.txid + "-".toJs + txout.n).to(cstring)].to(bool):
            var item = JsObject{txtype: 1, address: a, txid: txout.txid, n: txout.n,
              value: txout.value, change: val.change, index: val.index,
              xpub_idx: val.xpub_idx, trans_time: txout.trans_time, mytxs: if mytxs[txout.txid.to(cstring)].to(bool): 1 else: 0}
            unconf_list.push(item)

    unconf_list.sort(proc(a, b: JsObject): JsObject =
      var cmp = b.mytxs - a.mytxs
      if cmp == 0.toJs:
        cmp = b.change - a.change
        if cmp == 0.toJs:
          cmp = a.trans_time - b.trans_time
          if cmp == 0.toJs:
            cmp = a.xpub_idx - b.xpub_idx
            if cmp == 0.toJs:
              cmp = a.index - b.index
              if cmp == 0.toJs:
                cmp = a.txid > b.txid
                if cmp == 0.toJs:
                  cmp = a.n - b.n
      return cmp
    )
    u_unconfs = unconf_list

  var u_unusedList = [].toJs
  self.setUnusedAddress = proc(data: JsObject): bool =
    var changed = false
    if u_unusedList.length == data.length:
      for i in 0..<u_unusedList.length.to(int):
        if u_unusedList[i] != data[i]:
          changed = true
          break
    else:
      changed = true
    u_unusedList = data
    return changed

  self.getUnusedAddressList = proc(count: int, cb: proc(addrs: JsObject)) =
    var xpub = u_xpubs[0]
    if not xpub.to(bool):
     xpub = self.getXpubs()[0]
    if not u_nodes[xpub.to(cstring)].to(bool):
      u_nodes[xpub.to(cstring)] = bip32.fromBase58(xpub, network)
    var addrs = [].toJs
    var data = u_unusedList
    var datatmp = [].toJs
    if data.length.to(int) == 0:
      for i in 0..<count:
        datatmp.push(i)
    else:
      for i in 0..<data.length.to(int):
        datatmp.push(data[i]);
      var last = data[data.length.to(int) - 1].to(int)
      for i in 1..count - data.length.to(int):
        datatmp.push(last + i)
    for i in 0..<datatmp.length.to(int):
      var child = u_nodes[xpub.to(cstring)].derive(0).derive(datatmp[i])
      var p2pkh = coin.payments.p2pkh(JsObject{pubkey: child.publicKey, network: network})
      addrs.push(p2pkh.address)
    cb(addrs)

  proc xc(b1, b2: JsObject) =
    if b1.length == b2.length:
      for i in 0..<b1.length.to(int):
        b1[i] ^= b2[i]

  proc sha256d(data: JsObject): JsObject = coin.crypto.sha256(coin.crypto.sha256(data))

  proc buf2hex(buffer: JsObject): cstring =
    Array.prototype.map.call(newUint8Array(buffer), proc(x: JsObject): JsObject = ("00".toJs + x.toString(16)).slice(-2)).join("").to(cstring)

  proc hex2buf(hexstr: JsObject): JsObject =
    if hexstr.length % 2.toJs != 0.toJs:
      raise newException(WalletError, "no even number")
    newUint8Array(hexstr.to(cstring).match_regexp2().map(proc(b: JsObject): JsObject = Number.parseInt(b, 16)))

  var shieldedKeys = JsObject{priv: [].toJs, pub: [].toJs}
  self.initShieldedKeys = proc(keys: JsObject) =
    shieldedKeys = JsObject{priv: [].toJs, pub: [].toJs}

  self.setShieldedKeys = proc(keys: JsObject) =
    shieldedKeys = keys

  self.addShieldedKey = proc(key: JsObject) =
    shieldedKeys.priv.push(key.priv)
    shieldedKeys.pub.push(key.pub)

  self.getShieldedKeysCount = proc(): int = shieldedKeys.pub.length.to(int)

  self.getLockShieldedType = proc(): JsObject = stor.get_lock_type()

  self.getLockShieldedStatus = proc(): bool =
    (shieldedKeys.pub.length.to(int) > 0 and shieldedKeys.priv.length.to(int) == 0)

  self.lockShieldedKeys = proc(phrase: JsObject, lock_type: JsObject, prelock: bool): bool =
    var cipher = pastel.cipher
    if not cipher.to(bool):
      return false
    if not phrase.to(bool) or phrase.length.to(int) == 0:
      if self.getLockShieldedStatus().to(bool):
        return true
      if not prelock and shieldedKeys.unlock.to(bool):
        shieldedKeys.priv = [].toJs
        discard jsDelete(shieldedKeys.unlock)
        return true
      return false
    if shieldedKeys.priv.length.to(int) == 0 or shieldedKeys.pub.length.to(int) == 0 or
      shieldedKeys.priv.length.to(int) != shieldedKeys.pub.length.to(int):
      return false
    var salt = stor.get_salt(true)
    if not salt.to(bool):
      return false
    var p = cipher.yespower_n4r32(sha256d(phrase), 32)
    xc(p, salt)
    p = cipher.yespower_n4r32(sha256d(p), 32)
    var enc = cipher.enc_json(p, shieldedKeys.priv)

    stor.set_shield(enc)
    stor.set_lock_type(lock_type)

    if stor.get_lock_type() != lock_type:
      return false
    var dec = cipher.dec_json(p, stor.get_shield())
    for i in 0..<shieldedKeys.priv.length.to(int):
      if shieldedKeys.priv[i] != dec[i]:
        return false

    stor.set_xpubs(shieldedKeys.pub)

    if prelock:
      shieldedKeys.unlock = true
    else:
      shieldedKeys.priv = [].toJs
    return true

  self.unlockShieldedKeys = proc(phrase: JsObject): bool =
    var cipher = pastel.cipher
    if not cipher.to(bool):
      return false
    if not phrase.to(bool) or phrase.length.to(int) == 0:
      return false
    var salt = stor.get_salt(true)
    if not salt.to(bool):
      return false
    var p = cipher.yespower_n4r32(sha256d(phrase), 32)
    xc(p, salt)
    p = cipher.yespower_n4r32(sha256d(p), 32)
    try:
      var dec = cipher.dec_json(p, stor.get_shield())
      shieldedKeys.priv = dec
      shieldedKeys.pub = stor.get_xpubs()
      if shieldedKeys.priv.length != shieldedKeys.pub.length:
        return false
      shieldedKeys.unlock = true
      return true
    except:
      let e = getCurrentException()
      console.log(e.name & ": ".cstring & e.msg.cstring)
      return false

  self.setSeedCard = proc(cardInfos: JsObject) =
    var cipher = pastel.cipher
    self.initShieldedKeys()
    var mix: JsObject
    for i in 0..<cardInfos.length.to(int):
      var s = cardInfos[i]
      var sbuf = base58.dec(s.seed or s.orig)
      if not sbuf.to(bool) and not s.seed.to(bool) and s.orig.to(bool):
        sbuf = cipher.yespower_n4r32(sha256d(s.orig), 32)
      if s.sv.to(bool) and s.sv.length.to(int) > 0:
        var sv = cipher.yespower_n4r32(sha256d(s.sv), 32)
        var sbuf_sv = newUint8Array(64)
        sbuf_sv.set(sbuf)
        sbuf_sv.set(sv, 32)
        var sv2 = cipher.yespower_n4r32(sha256d(sbuf_sv), 32)
        xc(sbuf, sv2)
      if mix.to(bool):
        xc(mix, sbuf)
      else:
        mix = sbuf
      if mix.to(bool):
        var kp = self.getHdNodeKeyPairs(buf2hex(mix))
        self.addShieldedKey(kp)

  self.setMnemonic = proc(words: cstring, lang_id: int) =
    self.initShieldedKeys()
    var sds = self.getMnemonicToSeeds(words, lang_id)
    for i in 0..<sds.length.to(int):
      var sd = sds[i]
      var kp = self.getHdNodeKeyPairs(sd.seed)
      self.addShieldedKey(kp)

  var cb_set_change: proc(data: JsObject) = proc(data: JsObject) = discard
  self.setChange = proc(data: JsObject) =
    cb_set_change(data)

  var ErrSend = JsObject{
    SUCCESS: 0,
    FAILED: 1,
    INVALID_ADDRESS: 2,
    INSUFFICIENT_VALUE: 3,
    DUST_VALUE: 4,
    BUSY: 5,
    TX_FAILED: 6,
    TX_TIMEOUT: 7,
    SERVER_ERROR: 8,
    SERVER_TIMEOUT: 9
  }
  self.ERR_SEND = ErrSend

  var cb_rawtx: proc(result_rawtx: JsObject) = proc(result_rawtx: JsObject) = discard

  self.rawtxResult = proc(result_rawtx: JsObject) =
    cb_rawtx(result_rawtx)

  proc send_tx(rawtx: JsObject, cb: proc(data: JsObject)) =
    var tval: int = jsNull.to(int)
    var result_cb = cb
    cb_rawtx = proc(result_rawtx: JsObject) =
      clearTimeout(tval)
      if not result_rawtx.err.to(bool) and result_rawtx.res.to(bool):
        result_cb(JsObject{err: ErrSend.SUCCESS, res: result_rawtx.res})
      else:
        if result_rawtx.res.to(bool):
          result_cb(JsObject{err: ErrSend.TX_FAILED, res: result_rawtx.res})
        else:
          result_cb(JsObject{err: ErrSend.TX_FAILED, res: jsNull})
      cb_rawtx = proc(result_rawtx: JsObject) = discard
    var ret = pastel.send(JsObject{cmd: "rawtx".cstring, data: rawtx})
    if ret.to(bool):
      tval = setTimeout(proc() =
        result_cb = proc(ignore: JsObject) = discard
        cb(JsObject{err: ErrSend.TX_TIMEOUT, res: jsNull}), 30000)
    else:
      result_cb = proc(ignore: JsObject) = discard
      cb(JsObject{err: ErrSend.TX_FAILED, res: jsNull})

  proc send_internal(send_address: cstring, change_address: cstring, value: Uint64, cb: proc(data: JsObject)) =
    var tx = newTransactionBuilder(coin, network)
    var in_value = newUint64(0)
    var sign_utxos = [].toJs
    var utxo_count = 0
    var result_out = 0

    for i in 0..<u_utxos.length.to(int):
      var utxo = u_utxos[i]
      tx.addInput(utxo.txid, utxo.n)
      in_value.add(newUint64(String(utxo.value)))
      sign_utxos.push(utxo)
      inc(utxo_count)

      if in_value.gt(value).to(bool):
        var sub = in_value.clone().subtract(value).to(Uint64)
        var fee1 = newUint64(cstring($(148 * utxo_count + 34 * 2 + 10 + 546)))
        if sub.gt(fee1).to(bool) or sub.eq(fee1).to(bool):
          result_out = 2
          break
        else:
          var fee2 = newUint64(cstring($(148 * utxo_count + 34 + 10)))
          if sub.gt(fee2).to(bool) or sub.eq(fee2).to(bool):
            result_out = 1
            var fee3 = newUint64(cstring($(148 * utxo_count + 34 * 2 + 10 + 148)))
            if sub.lt(fee3).to(bool):
              break
    if result_out == 0:
      cb(JsObject{err: ErrSend.INSUFFICIENT_BALANCE})
      return

    var priv_nodes = JsObject{}
    var keys = JsObject{}
    for i in 0..<sign_utxos.length.to(int):
      var s = sign_utxos[i]
      if not priv_nodes[s.xpub_idx.to(int)].to(bool):
        priv_nodes[s.xpub_idx.to(int)] = bip32.fromBase58(shieldedKeys.priv[s.xpub_idx.to(int)], network)
      var child = priv_nodes[s.xpub_idx.to(int)].derive(s.change).derive(s.index)
      keys[(s.xpub_idx + "-".toJs + s.change + "-".toJs + s.index).to(cstring)] = child

    try:
      tx.addOutput(send_address, value)
    except:
      let e = getCurrentException()
      console.log(e.name & ": ".cstring & e.msg.cstring)
      cb(JsObject{err: ErrSend.INVALID_ADDRESS})
      return
    if result_out == 1:
      for i in 0..<sign_utxos.length.to(int):
        var s = sign_utxos[i]
        var key = keys[(s.xpub_idx + "-".toJs + s.change + "-".toJs + s.index).to(cstring)]
        tx.sign(i, key)
      var rawtx = tx.build().toHex()
      var total_bytes = rawtx.length.to(int) div 2
      var fee = in_value.clone().subtract(value).to(Uint64)
      send_tx(rawtx, proc(resultData: JsObject) = cb(resultData))
      return

    var change_value = in_value.clone().subtract(value).to(Uint64)
    var fee_low = 147 * utxo_count + 34 * 2 + 10
    var fee_high = 148 * utxo_count + 34 * 2 + 10
    var fee_mid = Math.round(147.5 * utxo_count.float64 + 34 * 2 + 10).to(int)
    var fee_start = fee_mid - Math.ceil(1000 / utxo_count).to(int)
    if fee_start < fee_low:
      fee_start = fee_low

    var better_tx = jsNull
    var better_size = 0
    var better_fee = 0
    for fee in fee_start..fee_high:
      var change_sub = change_value.clone().subtract(newUint64(fee.uint)).to(Uint64)
      tx.addOutput(change_address, change_sub)
      for i in 0..<sign_utxos.length.to(int):
        var s = sign_utxos[i]
        var key = keys[(s.xpub_idx + "-".toJs + s.change + "-".toJs + s.index).to(cstring)]
        tx.sign(i, key)
      var rawtx = tx.build().toHex()
      var total_bytes = rawtx.length.to(int) div 2

      if fee >= total_bytes:
        better_tx = rawtx
        better_size = total_bytes
        better_fee = fee
        break
      tx.removeOutput(1)
      tx.removeSign()
    if better_tx != jsNull:
      send_tx(better_tx, proc(resultData: JsObject) = cb(resultData))
      return

    cb(JsObject{err: ErrSend.FAILED})

  proc send_lazy_internal(send_address: cstring, change_address: cstring, value: Uint64, cb: proc(data: JsObject)) =
    var lazy_time = 2
    var tx = newTransactionBuilder(coin, network)
    var in_value = newUint64(0)
    var sign_utxos = [].toJs
    var utxo_count = 0
    var result_out = 0

    var sign_worker_sign_utxos = [].toJs
    var sign_i = 0
    var better_tx = jsNull
    var better_size = 0
    var better_fee = 0
    var sign_fee = 0
    var sign_fee_high = 0
    var keys = JsObject{}
    proc sign_worker3()

    proc sign_worker4() =
      var s = sign_worker_sign_utxos.shift()
      if s.to(bool):
        var key = keys[(s.xpub_idx + "-".toJs + s.change + "-".toJs + s.index).to(cstring)]
        tx.sign(sign_i, key)
        inc(sign_i)
        setTimeout(sign_worker4, lazy_time)
      else:
        var rawtx = tx.build().toHex()
        var total_bytes = rawtx.length.to(int) div 2

        if sign_fee >= total_bytes:
          better_tx = rawtx
          better_size = total_bytes
          better_fee = sign_fee
          send_tx(better_tx, proc(resultData: JsObject) = cb(resultData))
        else:
          tx.removeOutput(1)
          tx.removeSign()
          inc(sign_fee)
          if sign_fee <= sign_fee_high:
            sign_worker3()
          else:
            if better_tx != jsNull:
              send_tx(better_tx, proc(resultData: JsObject) = cb(resultData))
            else:
              cb(JsObject{err: ErrSend.FAILED})

    var change_value = newUint64(0)
    proc sign_worker3() =
      var change_sub = change_value.clone().subtract(newUint64(sign_fee.uint)).to(Uint64)
      tx.addOutput(change_address, change_sub)
      sign_worker_sign_utxos = JSON.parse(JSON.stringify(sign_utxos))
      sign_i = 0
      sign_worker4()

    proc sign_worker2() =
      change_value = in_value.clone().to(Uint64).subtract(value).to(Uint64)
      var fee_low = 147 * utxo_count + 34 * 2 + 10
      var fee_high = 148 * utxo_count + 34 * 2 + 10
      var fee_mid = Math.round(147.5 * utxo_count.float64 + 34 * 2 + 10)
      var fee_start = (fee_mid - Math.ceil(1000 / utxo_count)).to(int)
      if fee_start < fee_low:
        fee_start = fee_low
      sign_fee = fee_start
      sign_fee_high = fee_high
      sign_worker3()

    proc sign_worker() =
      var s = sign_worker_sign_utxos.shift()
      if s.to(bool):
        var key = keys[(s.xpub_idx + "-".toJs + s.change + "-".toJs + s.index).to(cstring)]
        tx.sign(sign_i, key)
        inc(sign_i)
        setTimeout(sign_worker, lazy_time)
      else:
        var rawtx = tx.build().toHex()
        var total_bytes = rawtx.length.to(int) div 2
        var fee = in_value.clone().subtract(value).to(Uint64)
        send_tx(rawtx, proc(resultData: JsObject) = cb(resultData))

    proc addoutput_worker() =
      try:
        tx.addOutput(send_address, value)
      except:
        let e = getCurrentException()
        console.log(e.name & ": ".cstring & e.msg.cstring)
        cb(JsObject{err: ErrSend.INVALID_ADDRESS})
        return
      if result_out == 1:
        sign_worker_sign_utxos = JSON.parse(JSON.stringify(sign_utxos))
        sign_i = 0
        sign_worker()
      else:
        sign_worker2()

    var priv_nodes = JsObject{}
    var keys_worker_sign_utxos = [].toJs
    proc keys_worker() =
      var s = keys_worker_sign_utxos.shift()
      if s.to(bool):
        if not priv_nodes[s.xpub_idx.to(int)].to(bool):
          priv_nodes[s.xpub_idx.to(int)] = bip32.fromBase58(shieldedKeys.priv[s.xpub_idx.to(int)], network)
        var child = priv_nodes[s.xpub_idx.to(int)].derive(s.change).derive(s.index)
        keys[(s.xpub_idx + "-".toJs + s.change + "-".toJs + s.index).to(cstring)] = child
        setTimeout(keys_worker, lazy_time)
      else:
        addoutput_worker()

    var utxos = u_utxos.concat(u_unconfs)
    proc addinput_worker() =
      var utxo = utxos.shift()
      if utxo.to(bool):
        tx.addInput(utxo.txid, utxo.n)
        in_value.add(newUint64(String(utxo.value)))
        sign_utxos.push(utxo)
        inc(utxo_count)

        if in_value.gt(value).to(bool):
          var sub = in_value.clone().subtract(value).to(Uint64)
          var fee1 = newUint64((148 * utxo_count + 34 * 2 + 10 + 546).uint)
          if sub.gt(fee1).to(bool) or sub.eq(fee1).to(bool):
            result_out = 2
            keys_worker_sign_utxos = JSON.parse(JSON.stringify(sign_utxos))
            keys_worker()
            return
          else:
            var fee2 = newUint64((148 * utxo_count + 34 + 10).uint)
            if sub.gt(fee2).to(bool) or sub.eq(fee2).to(bool):
              result_out = 1
              var fee3 = newUint64((148 * utxo_count + 34 * 2 + 10 + 148).uint)
              if sub.lt(fee3).to(bool):
                keys_worker_sign_utxos = JSON.parse(JSON.stringify(sign_utxos))
                keys_worker()
                return
        setTimeout(addinput_worker, lazy_time)
      else:
        if result_out == 0:
          cb(JsObject{err: ErrSend.INSUFFICIENT_BALANCE})
          return
        keys_worker_sign_utxos = JSON.parse(JSON.stringify(sign_utxos))
        keys_worker()
    addinput_worker()

  var send_busy = false
  self.send = proc(address: cstring, value_str: cstring, cb: proc(data: JsObject)) =
    if send_busy:
      cb(JsObject{err: ErrSend.BUSY})
      return
    send_busy = true
    var value = newUint64(String(value_str.toJs))
    if value.lt(newUint64(String(546.toJs))).to(bool):
      send_busy = false
      cb(JsObject{err: ErrSend.DUST_VALUE})
      return
    var cb_set_change_called = false
    var cb_set_tval: int = jsNull.to(int)
    cb_set_change = proc(data: JsObject) =
      cb_set_change_called = true
      clearTimeout(cb_set_tval)
      cb_set_change = proc(data: JsObject) = discard
      if data.length.to(int) > 0:
        var index = data[0]
        var xpub = u_xpubs[0]
        if xpub.to(bool) and not u_nodes[xpub.to(cstring)].to(bool):
          u_nodes[xpub.to(cstring)] = bip32.fromBase58(xpub, network)
        var child = u_nodes[xpub.to(cstring)].derive(1).derive(index)
        var change_address = coin.payments.p2pkh(JsObject{pubkey: child.publicKey, network: network}).address.to(cstring)
        send_lazy_internal(address, change_address, value, proc(ret: JsObject) =
          send_busy = false
          cb(ret)
        )
      else:
        send_busy = false
        cb(JsObject{err: ErrSend.SERVER_ERROR})
    pastel.send(JsObject{cmd: "change".cstring})
    cb_set_tval = setTimeout(proc() =
      if not cb_set_change_called:
        cb_set_change = proc(data: JsObject) = discard
        send_busy = false
        cb(JsObject{err: ErrSend.SERVER_TIMEOUT}), 30000)

  proc get_safecount(): int =
    var safe_size = newUint64("100000".cstring)
    var safe_utxo_count = 0
    var size = newUint64(34 + 10)
    while true:
      size.add(newUint64(148))
      if safe_size.gt(size).to(bool):
        inc(safe_utxo_count)
      else:
        break
    return safe_utxo_count
  var safe_utxo_count = get_safecount()

  self.calcSendValue = proc(utxo_count: int): JsObject =
    var unconfs = Object.assign([].toJs, u_unconfs)
    var utxos = u_utxos.concat(unconfs)
    var conf_count = utxos.length.to(int) - unconfs.length.to(int)
    var unconf_count = unconfs.length.to(int)
    var all_count = utxos.length.to(int)
    var in_value = newUint64(0)
    var count = 0
    for i in 0..<utxo_count:
      var utxo = utxos[i]
      if utxo.to(bool):
        in_value.add(newUint64(String(utxo.value)))
        inc(count)
      else:
        break
    if in_value.gt(newUint64(0)).to(bool):
      var fee = newUint64((148 * count + 34 + 10).uint)
      return JsObject{err: 0, value: in_value.subtract(fee).toString(), count: count, all: all_count, max: safe_utxo_count, conf: conf_count, unconf: unconf_count}
    else:
      return JsObject{err: 0, value: "0", count: count, all: all_count, max: safe_utxo_count, conf: conf_count, unconf: unconf_count}

  self.calcSendUtxo = proc(value_str: cstring): JsObject =
    var unconfs = Object.assign([].toJs, u_unconfs)
    var utxos = u_utxos.concat(unconfs)
    var conf_count = utxos.length.to(int) - unconfs.length.to(int)
    var unconf_count = unconfs.length.to(int)
    var all_count = utxos.length.to(int)
    var value = newUint64(String(value_str.toJs))
    if value.eq(newUint64(0)).to(bool):
      return JsObject{err: 0, count: 0, sign: 0, all: utxos.length, max: safe_utxo_count}
    var in_value = newUint64(0)
    var sign_utxos = [].toJs
    var utxo_count = 0
    var result_out = 0
    var eq = false
    for i in 0..<utxos.length.to(int):
      var utxo = utxos[i]
      in_value.add(newUint64(String(utxo.value)))
      inc(utxo_count)
      if in_value.gt(value).to(bool):
        var sub = in_value.clone().subtract(value).to(Uint64)
        var fee1 = newUint64((148 * utxo_count + 34 * 2 + 10 + 546).uint)
        var chk_eq = sub.eq(fee1).to(bool)
        if sub.gt(fee1).to(bool) or chk_eq:
          result_out = 2
          eq = chk_eq
          break
        else:
          var fee2 = newUint64((148 * utxo_count + 34 + 10).uint)
          var chk_eq2 = sub.eq(fee2).to(bool)
          if sub.gt(fee2).to(bool) or chk_eq2:
            result_out = 1
            eq = chk_eq2
            var fee3 = newUint64((148 * utxo_count + 34 * 2 + 10 + 148).uint)
            if sub.lt(fee3).to(bool):
              break
    if result_out != 0:
      return JsObject{err: 0, count: utxo_count, sign: if eq: 0 else: -1, all: all_count, max: safe_utxo_count, conf: conf_count, unconf: unconf_count}
    else:
      return JsObject{err: 1, sign: 1, all: all_count, max: safe_utxo_count, conf: conf_count, unconf: unconf_count}
