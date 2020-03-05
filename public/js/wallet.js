// Copyright (c) 2019 zenywallet
function Wallet() {
  var bip39 = coinlibs.bip39;
  var bip32 = coinlibs.bip32;
  var coin = coinlibs.coin;
  var network = coin.networks[pastel.config.network];
  var stor = new Stor();
  var _hdpash = "m/44'/123'/0'";
  var self = this;

  function getWordList(mlang) {
    if(mlang == 1) {
      return bip39.wordlists.japanese;
    } else {
      return bip39.wordlists.english;
    }
  }

  this.getMnemonicToSeed = function(mnemonic, password) {
    var m = mnemonic.replace(/[ 　\n\r]+/g, ' ').trim();
    return bip39.mnemonicToSeedSync(m, password);
  }

  var MnemonicSeedType = {
    "0": "Unknown",
    "1": "Standard",
    "2": "Standard with password",
    "101": "Non-standard 1",
    "102": "Non-standard 2"
  };

  this.getMnemonicSeedType = function(type) {
    return MnemonicSeedType[type];
  }

  this.getNonStandardMnemonicToSeeds = function(mnemonic, mlang) {
    var seeds = [];
    var m = mnemonic.replace(/[ 　\n\r]+/g, ' ').trim();
    if(m.split(' ').length == 24) {
      var entropy = bip39.mnemonicToEntropy(m, getWordList(mlang), true);
      seeds.push({seed: entropy, type: 101});
      if(mlang == 0) {
        var m2 = bip39.entropyToMnemonic(entropy, getWordList(1));
        var seed2 = bip39.mnemonicToSeedSync(m2);
        seeds.push({seed: seed2, type: 102});
      }
    }
    return seeds;
  }

  this.getMnemonicToSeeds = function(mnemonic, mlang, password) {
    var seeds = [];
    var m = mnemonic.replace(/[ 　\n\r]+/g, ' ').trim();
    var seed = bip39.mnemonicToSeedSync(m, password);
    seeds.push({seed: seed, type: password ? 2 : 1});
    var nonstd_seeds = this.getNonStandardMnemonicToSeeds(mnemonic, mlang);
    seeds = seeds.concat(nonstd_seeds);
    console.log('seeds:', seeds);
    return seeds;
  }

  this.setHdpath = function(hdpath) {
    _hdpash = hdpath;
  }

  this.getHdNodeKeyPairs = function(seed, hdpath) {
    var node = (typeof seed === 'string') ? bip32.fromSeedHex(seed, network) : bip32.fromSeed(seed, network);
    var child = node.derivePath(hdpath || _hdpash);
    return {priv: child.toBase58(), pub: child.neutered().toBase58()};
  }

  this.getHdNodePrivate = function(seed, hdpath) {
    var node = (typeof seed === 'string') ? bip32.fromSeedHex(seed, network) : bip32.fromSeed(seed, network);
    var child = node.derivePath(hdpath || _hdpash);
    return child.toBase58();
  }

  this.getHdNodePublic = function(seed, hdpath) {
    var node = (typeof seed === 'string') ? bip32.fromSeedHex(seed, network) : bip32.fromSeed(seed, network);
    var child = node.derivePath(hdpath || _hdpash);
    return child.neutered().toBase58();
  }

  this.resetXpubFromSeed = function(seed, hdpath) {
    stor.del_xpubs();
    var xpub = wallet.getHdNodePublic(seed, hdpath || _hdpash);
    stor.add_xpub(xpub);
  }

  this.resetXpubFromMnemonic = function(mnemonic, mlang, password, hdpath) {
    var seeds = wallet.getMnemonicToSeeds(mnemonic, mlang, password);
    stor.del_xpubs();
    for(var i in seeds) {
      var seed = seeds[i].seed;
      var xpub = wallet.getHdNodePublic(seed, hdpath || _hdpash);
      stor.add_xpub(xpub);
    }
  }

  function error(msg) {
    console.log('ERROR: ' + msg);
  }

  var _xpubs = [];
  var _utxos = [];
  var _nodes = {};

  this.getXpubs = function() {
    _xpubs = stor.get_xpubs();
    return _xpubs;
  }

  this.getXpub = function(xpub_idx) {
    return _xpubs[xpub_idx];
  }

  this.checkXpubs = function(xpubs) {
    for(var i in xpubs) {
      if(_xpubs.indexOf(xpubs[i]) < 0) {
        return false;
      }
    }
    return true;
  }

  var address_caches = {};
  function checkUtxo(utxo) {
    var xpub = _xpubs[utxo.xpub_idx];
    if(!xpub) {
      error('xpub not found');
      return false;
    }
    if(!_nodes[xpub]) {
      _nodes[xpub] = bip32.fromBase58(xpub, network);
    }
    var idx = utxo.xpub_idx + '-' + utxo.change + '-' + utxo.index;
    var cache = address_caches[idx];
    if(cache) {
      if(utxo.address != cache.p2pkh) {
        var p2wpkh = address_caches[idx]['p2wpkh'];
        if(!p2wpkh) {
          p2wpkh = coin.payments.p2wpkh({pubkey: child.publicKey, network: network}).address;
          address_caches[idx]['p2wpkh'] = p2wpkh;
        }
        if(utxo.address != p2wpkh) {
          var p2sh = address_caches[idx]['p2sh'];
          if(!p2sh) {
            p2sh = coin.payments.p2sh({redeem: p2wpkh, network: network}).address;
            address_caches[idx]['p2sh'] = p2sh;
          }
          if(utxo.address != p2sh) {
            error('invalid utxo address');
            return false;
          }
        }
      }
    } else {
      var child = _nodes[xpub].derive(utxo.change).derive(utxo.index);
      var p2pkh = coin.payments.p2pkh({pubkey: child.publicKey, network: network}).address;
      address_caches[idx] = {child: child, p2pkh: p2pkh};
      if(utxo.address != p2pkh) {
        var p2wpkh = coin.payments.p2wpkh({pubkey: child.publicKey, network: network}).address;
        address_caches[idx]['p2wpkh'] = p2wpkh;
        if(utxo.address != p2wpkh) {
          var p2sh = coin.payments.p2sh({redeem: p2wpkh, network: network}).address;
          address_caches[idx]['p2sh'] = p2sh;
          if(utxo.address != p2sh) {
            error('invalid utxo address');
            return false;
          }
        }
      }
    }
    return true;
  }

  function checkUtxos(utxos) {
    var tmp_utxos = [];
    for(var i in utxos) {
      tmp_utxos.push(utxos[i]);
    }

    function worker() {
      var utxo = tmp_utxos.shift();
      if(utxo) {
        if(checkUtxo(utxo)) {
          setTimeout(worker, 10);
        } else {
          Notify.show('Error', 'Server is invalid and unreliable. Stop using this wallet.', Notify.msgtype.error);
        }
      }
    }
    worker();
  }

  this.setUtxos = function(utxos) {
    _utxos = utxos;
    checkUtxos(utxos);
  }

  this.addUtxos = function(utxos, deduplicate) {
    if(checkUtxos(utxos)) {
      if(deduplicate) {
        error('unimplemented');
        return false;
      } else {
        _utxos.concat(utxos);
      }
      return true;
    }
    return false;
  }

  this.getUtxos = function() {
    return _utxos;
  }

  var _unusedList = [];
  this.setUnusedAddress = function(data) {
    var changed = false;
    if(_unusedList.length == data.length) {
      for(i in _unusedList) {
        if(_unusedList[i] != data[i]) {
          changed = true;
          break;
        }
      }
    } else {
      changed = true;
    }
    _unusedList = data;
    return changed;
  }

  this.getUnusedAddressList = function(count, cb) {
    var xpub = _xpubs[0];
    if(!xpub) {
     xpub = this.getXpubs();
    }
    if(!_nodes[xpub]) {
      _nodes[xpub] = bip32.fromBase58(xpub, network);
    }
    var addrs = [];
    var data = _unusedList;
    var datatmp = [];
    if(data.length == 0) {
      for(var i = 0; i < count; i++) {
        datatmp.push(i);
      }
    } else {
      for(var i in data) {
        datatmp.push(data[i]);
      }
      var last = data[data.length - 1];
      for(var i = 1; i <= count - data.length; i++) {
        datatmp.push(last + i);
      }
    }
    console.log('datatmp=', datatmp);
    for(var i in datatmp) {
      var child = _nodes[xpub].derive(0).derive(datatmp[i]);
      var p2pkh = coin.payments.p2pkh({pubkey: child.publicKey, network: network});
      addrs.push(p2pkh.address);
    }
    cb(addrs);
  }

  function xc(b1, b2) {
    if(b1.length == b2.length) {
      for(var i = 0; i < b1.length; i++) {
        b1[i] ^= b2[i];
      }
    }
  }

  function sha256d(data) {
    return coin.crypto.sha256(coin.crypto.sha256(data));
  }

  function buf2hex(buffer) {
    return Array.prototype.map.call(new Uint8Array(buffer), function(x) {return ('00' + x.toString(16)).slice(-2)}).join('');
  }

  function hex2buf(hexstr) {
    if(hexstr.length % 2) {
      throw new Error('no even number');
    }
    return new Uint8Array(hexstr.match(/.{2}/g).map(function(byte) {return parseInt(byte, 16)}));
  }

  var shieldedKeys = {priv: [], pub: []};
  this.initShieldedKeys = function(keys) {
    shieldedKeys = {priv: [], pub: []};
  }

  this.setShieldedKeys = function(keys) {
    shieldedKeys = keys;
  }

  this.addShieldedKey = function(key) {
    shieldedKeys.priv.push(key.priv);
    shieldedKeys.pub.push(key.pub);
  }

  this.getShieldedKeysCount = function() {
    return shieldedKeys.pub.length;
  }

  this.getLockShieldedType = function() {
    return stor.get_lock_type();
  }

  this.getLockShieldedStatus = function() {
    return (shieldedKeys.pub.length > 0 && shieldedKeys.priv.length == 0);
  }

  this.lockShieldedKeys = function(phrase, lock_type, prelock) {
    var cipher = pastel.cipher;
    if(!cipher) {
      return false;
    }
    if(!phrase || phrase.length == 0) {
      if(self.getLockShieldedStatus()) {
        return true;
      }
      if(!prelock && shieldedKeys.unlock) {
        shieldedKeys.priv = [];
        delete shieldedKeys.unlock;
        console.log('after prelock: ' + JSON.stringify(shieldedKeys));
        return true;
      }
      return false;
    }
    if(shieldedKeys.priv.length == 0 || shieldedKeys.pub.length == 0 ||
      shieldedKeys.priv.length != shieldedKeys.pub.length) {
      return false;
    }
    var salt = stor.get_salt(true);
    if(!salt) {
      return false;
    }
    var p = cipher.yespower_n4r32(sha256d(phrase), 32);
    xc(p, salt);
    p = cipher.yespower_n4r32(sha256d(p), 32);
    var enc = cipher.enc_json(p, shieldedKeys.priv);

    console.log(enc);
    stor.set_shield(enc);
    stor.set_lock_type(lock_type);
    console.log('get_shield=', stor.get_shield());

    if(stor.get_lock_type() != lock_type) {
      return false;
    }
    var dec = cipher.dec_json(p, stor.get_shield());
    for(var i in shieldedKeys.priv) {
      if(shieldedKeys.priv[i] != dec[i]) {
        return false;
      }
    }

    stor.set_xpubs(shieldedKeys.pub);

    if(prelock) {
      shieldedKeys.unlock = true;
    } else {
      shieldedKeys.priv = [];
    }
    console.log('after lock: ' + JSON.stringify(shieldedKeys));
    return true;
  }

  this.unlockShieldedKeys = function(phrase) {
    var cipher = pastel.cipher;
    if(!cipher) {
      return false;
    }
    if(!phrase || phrase.length == 0) {
      return false;
    }
    var salt = stor.get_salt(true);
    if(!salt) {
      return false;
    }
    var p = cipher.yespower_n4r32(sha256d(phrase), 32);
    xc(p, salt);
    p = cipher.yespower_n4r32(sha256d(p), 32);
    try {
      var dec = cipher.dec_json(p, stor.get_shield());
      for(var i in dec) {
        bip32.fromBase58(dec[i], network);
      }
      shieldedKeys.priv = dec;
      shieldedKeys.pub = stor.get_xpubs();
      if(shieldedKeys.priv.length != shieldedKeys.pub.length) {
        return false;
      }
      shieldedKeys.unlock = true;
      console.log('after unlock: ' + JSON.stringify(shieldedKeys));
      return true;
    } catch(ex) {
      console.log(ex);
      return false;
    }
  }

  this.setSeedCard = function(cardInfos) {
    var cipher = pastel.cipher;
    this.initShieldedKeys();
    var mix;
    for(var i in cardInfos) {
      var s = cardInfos[i];
      console.log('cardInfos', JSON.stringify(s));
      var sbuf = base58.dec(s.seed || s.orig);
      if(!sbuf && !s.seed && s.orig) {
        sbuf = cipher.yespower_n4r32(sha256d(s.orig), 32);
      }
      if(s.sv && s.sv.length > 0) {
        var sv = cipher.yespower_n4r32(sha256d(s.sv), 32);
        var sbuf_sv = new Uint8Array(64);
        sbuf_sv.set(sbuf);
        sbuf_sv.set(sv, 32);
        var sv2 = cipher.yespower_n4r32(sha256d(sbuf_sv), 32);
        xc(sbuf, sv2);
      }
      if(mix) {
        xc(mix, sbuf);
      } else {
        mix = sbuf;
      }
      if(mix) {
        var kp = this.getHdNodeKeyPairs(buf2hex(mix));
        this.addShieldedKey(kp);
      }
    }
  }

  this.setMnemonic = function(words, lang_id) {
    this.initShieldedKeys();
    var sds = this.getMnemonicToSeeds(words, lang_id);
    console.log(sds);
    for(var i in sds) {
      var sd = sds[i];
      var kp = this.getHdNodeKeyPairs(sd.seed);
      this.addShieldedKey(kp);
    }
  }

  var stime, etime;
  function time_start(label) {
    stime = new Date();
    console.log('start time ' + label, stime);
  }
  function time_end() {
    etime = new Date();
    console.log('end time', etime, etime - stime);
  }

  var cb_set_change = function(data) {}
  this.setChange = function(data) {
    console.log('wallet change', data);
    cb_set_change(data);
  }

  var ErrSend = {
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
  this.ERR_SEND = ErrSend;

  var cb_rawtx = function(result_rawtx) {}

  this.rawtxResult = function(result_rawtx) {
    cb_rawtx(result_rawtx);
  }

  function send_tx(rawtx, cb) {
    var tval = null;
    var result_cb = cb;
    cb_rawtx = function(result) {
      clearTimeout(tval);
      if(!result.err && result.res) {
        result_cb({err: ErrSend.SUCCESS, res: result.res});
      } else {
        if(result.res) {
          result_cb({err: ErrSend.TX_FAILED, res: result.res});
        } else {
          result_cb({err: ErrSend.TX_FAILED, res: null});
        }
      }
      cb_rawtx = function(result_rawtx) {}
    }
    pastel.send({cmd: 'rawtx', data: rawtx});
    tval = setTimeout(function() {
      result_cb = function(ignore) {};
      cb({err: ErrSend.TX_TIMEOUT, res: null});
    }, 30000);
  }

  function send_internal(send_address, change_address, value, cb) {
    var tx = new coin.TransactionBuilder(network);
    var in_value = UINT64(0);
    var sign_utxos = [];
    var utxo_count = 0;
    var result_out = 0;

    for(var i in _utxos) {
      var utxo = _utxos[i];
      console.log('addInput', tx.addInput(utxo.txid, utxo.n));
      console.log(utxo.address, utxo.value.toString());
      in_value.add(UINT64(String(utxo.value)));
      sign_utxos.push(utxo);
      utxo_count++;
      console.log(in_value.toString(), value.toString());

      if(in_value.gt(value)) {
        var sub = in_value.clone().subtract(value);
        var fee1 = UINT64(String(148 * utxo_count + 34 * 2 + 10 + 546));
        if(sub.gt(fee1) || sub.eq(fee1)) {
          result_out = 2;
          break;
        } else {
          var fee2 = UINT64(String(148 * utxo_count + 34 + 10));
          if(sub.gt(fee2) || sub.eq(fee2)) {
            result_out = 1;
            var fee3 = UINT64(String(148 * utxo_count + 34 * 2 + 10 + 148));
            if(sub.lt(fee3)) {
              break;
            }
          }
        }
      }
    }
    if(result_out == 0) {
      cb({err: ErrSend.INSUFFICIENT_BALANCE});
      return;
    }

    var priv_nodes = {};
    var keys = {};
    for(var i in sign_utxos) {
      var s = sign_utxos[i];
      if(!priv_nodes[s.xpub_idx]) {
        priv_nodes[s.xpub_idx] = bip32.fromBase58(shieldedKeys.priv[s.xpub_idx], network);
      }
      var child = priv_nodes[s.xpub_idx].derive(s.change).derive(s.index);
      keys[s.xpub_idx + '-' + s.change + '-' + s.index] = child;
    }

    try {
      tx.addOutput(send_address, value);
    } catch(ex) {
      console.log(ex);
      cb({err: ErrSend.INVALID_ADDRESS});
      return;
    }
    if(result_out == 1) {
      for(var i in sign_utxos) {
        var s = sign_utxos[i];
        var key = keys[s.xpub_idx + '-' + s.change + '-' + s.index];
        tx.sign(Number(i), key);
      }
      var rawtx = tx.build().toHex();
      var total_bytes = rawtx.length / 2;
      var fee = in_value.clone().subtract(value);
      console.log('tx1', fee.toString(), total_bytes, rawtx);
      send_tx(rawtx, function(result) {
        cb(result);
      });
      return;
    }

    var change_value = in_value.clone().subtract(value);
    var fee_low = 147 * utxo_count + 34 * 2 + 10;
    var fee_high = 148 * utxo_count + 34 * 2 + 10;
    var fee_mid = Math.round(147.5 * utxo_count + 34 * 2 + 10);
    var fee_start = fee_mid - Math.ceil(1000 / utxo_count);
    if(fee_start < fee_low) {
      fee_start = fee_low;
    }

    var better_tx = null;
    var better_size;
    var better_fee;
    for(var fee = fee_start; fee <= fee_high; fee++) {
      var change_sub = change_value.clone().subtract(UINT64(String(fee)));
      tx.addOutput(change_address, change_sub);
      for(var i in sign_utxos) {
        var s = sign_utxos[i];
        var key = keys[s.xpub_idx + '-' + s.change + '-' + s.index];
        tx.sign(Number(i), key);
      }
      var rawtx = tx.build().toHex();
      var total_bytes = rawtx.length / 2;
      console.log('tx2', fee, total_bytes, rawtx);

      if(fee >= total_bytes) {
        better_tx = rawtx;
        better_size = total_bytes;
        better_fee = fee;
        break;
      }
      tx.removeOutput(1);
      tx.removeSign();
    }
    if(better_tx != null) {
      console.log('tx2 best', better_fee, better_size, better_tx);
      send_tx(better_tx, function(result) {
        cb(result);
      });
      return;
    }

    cb({err: ErrSend.FAILED});
  }

  var send_busy = false;
  this.send = function(address, value_str, cb) {
    if(send_busy) {
      cb({err: ErrSend.BUSY});
      return;
    }
    send_busy = true;
    console.log('send', address, value_str);
    var value = UINT64(String(value_str));
    if(value.lt(UINT64(String(546)))) {
      send_busy = false;
      cb({err: ErrSend.DUST_VALUE});
      return;
    }
    var cb_set_change_called = false;
    cb_set_change = function(data) {
      cb_set_change_called = true;
      cb_set_change = function(data) {}
      if(data.length > 0) {
        var index = data[0];
        var xpub = _xpubs[0];
        if(xpub && !_nodes[xpub]) {
          _nodes[xpub] = bip32.fromBase58(xpub, network);
        }
        var child = _nodes[xpub].derive(1).derive(index);
        var change_address = coin.payments.p2pkh({pubkey: child.publicKey, network: network}).address;
        send_internal(address, change_address, value, function(ret) {
          send_busy = false;
          cb(ret);
        });
      } else {
        send_busy = false;
        cb({err: ErrSend.SERVER_ERROR});
      }
    }
    pastel.send({cmd: 'change'});
    setTimeout(function() {
      cb_set_change = function(data) {}
      setTimeout(function() {
        if(!cb_set_change_called) {
          send_busy = false;
          cb({err: ErrSend.SERVER_TIMEOUT});
        }
      }, 1000);
    }, 30000);
  }

  function get_safecount() {
    var safe_size = UINT64(String("100000"));
    var safe_utxo_count = 0;
    var size = UINT64(34 + 10);
    while(true) {
      size.add(UINT64(148));
      if(safe_size.gt(size)) {
        safe_utxo_count++;
      } else {
        break;
      }
    }
    return safe_utxo_count;
  }
  var safe_utxo_count = get_safecount();

  this.calcSendValue = function(utxo_count) {
    var in_value = UINT64(0);
    var count = 0;
    for(var i = 0; i < utxo_count; i++) {
      var utxo = _utxos[i];
      if(utxo) {
        in_value.add(UINT64(String(utxo.value)));
        count++;
      } else {
        break;
      }
    }
    if(in_value.gt(UINT64(0))) {
      var fee = UINT64(String(148 * count + 34 + 10));
      return {err: 0, value: in_value.subtract(fee).toString(), count: count, all: _utxos.length, max: safe_utxo_count};
    } else {
      return {err: 0, value: "0", count: count, all: _utxos.length, max: safe_utxo_count};
    }
  }

  this.calcSendUtxo = function(value_str) {
    var value = UINT64(String(value_str));
    if(value.eq(UINT64(0))) {
      return {err: 0, count: 0, sign: 0, all: _utxos.length, max: safe_utxo_count};
    }
    var in_value = UINT64(0);
    var sign_utxos = [];
    var utxo_count = 0;
    var result_out = 0;
    var eq = false;
    for(var i in _utxos) {
      var utxo = _utxos[i];
      in_value.add(UINT64(String(utxo.value)));
      utxo_count++;
      if(in_value.gt(value)) {
        var sub = in_value.clone().subtract(value);
        var fee1 = UINT64(String(148 * utxo_count + 34 * 2 + 10 + 546));
        var chk_eq = sub.eq(fee1);
        if(sub.gt(fee1) || chk_eq) {
          result_out = 2;
          eq = chk_eq;
          break;
        } else {
          var fee2 = UINT64(String(148 * utxo_count + 34 + 10));
          var chk_eq = sub.eq(fee2);
          if(sub.gt(fee2) || chk_eq) {
            result_out = 1;
            eq = chk_eq;
            var fee3 = UINT64(String(148 * utxo_count + 34 * 2 + 10 + 148));
            if(sub.lt(fee3)) {
              break;
            }
          }
        }
      }
    }
    if(result_out != 0) {
      return {err: 0, count: utxo_count, sign: eq ? 0 : -1, all: _utxos.length, max: safe_utxo_count};
    } else {
      return {err: 1, sign: 1, all: _utxos.length, max: safe_utxo_count};
    }
  }
}
