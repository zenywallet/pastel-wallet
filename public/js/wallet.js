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

  function checkUtxos(utxos) {
    for(var i in utxos) {
      var utxo = utxos[i];
      var xpub = _xpubs[utxo.xpub_idx];
      if(!xpub) {
        error('xpub not found');
        return false;
      }
      if(!_nodes[xpub]) {
        _nodes[xpub] = bip32.fromBase58(xpub, network);
      }
      var child = _nodes[xpub].derive(utxo.change).derive(utxo.index);
      if(utxo.address == coin.payments.p2pkh({pubkey: child.publicKey, network: network}).address) {
        continue;
      } else {
        var p2wpkh = coin.payments.p2wpkh({pubkey: child.publicKey, network: network});
        if(utxo.address == p2wpkh.address
          || utxo.address == coin.payments.p2sh({redeem: p2wpkh, network: network}).address) {
          continue;
        }
        error('invalid utxo address');
        return false;
      }
    }
    return true;
  }

  this.setUtxos = function(utxos) {
    if(checkUtxos(utxos)) {
      _utxos = utxos;
      return true;
    }
    return false;
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

  this.getUtxos = function(utxos) {
    return _utxos;
  }

  this.unusedAddressList_cb = function(json) {}

  this.getUnusedAddressList = function(count, cb) {
    var cb_called_tval = null;
    this.unusedAddressList_cb = function(json) {
      clearTimeout(cb_called_tval);
      var xpub = _xpubs[0];
      if(!xpub) {
       xpub = this.getXpubs();
      }
      if(!_nodes[xpub]) {
        _nodes[xpub] = bip32.fromBase58(xpub, network);
      }
      var addrs = [];
      var data = json.data;
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
    pastel.send({cmd: "unused"});
    cb_called_tval = setTimeout(function() {
      var cur_cb = self.unusedAddressList_cb;
      self.unusedAddressList_cb = function(json) {}
      Notify.show("Error", "Server no response.", Notify.msgtype.error);
      cur_cb({data: []});
    }, 5000);
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
        console.log('after relock: ' + JSON.stringify(shieldedKeys));
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
    var dec = cipher.dec_json(p, stor.get_shield());
    shieldedKeys.priv = dec;
    if(shieldedKeys.priv.length != shieldedKeys.pub.length) {
      return false;
    }
    shieldedKeys.unlock = true;
    console.log('after unlock: ' + JSON.stringify(shieldedKeys));
    return true;
  }

  this.setSeedCard = function(cardInfos) {
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
        xc(sbuf, sv);
        sbuf = cipher.yespower_n4r32(sha256d(sbuf), 32);
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
}
