// Copyright (c) 2019 zenywallet
var Wallet = (function() {
  var bip39 = coinlibs.bip39;
  var bip32 = coinlibs.bip32;
  var coin = coinlibs.coin;
  var network = coin.networks.bitzeny;
  var stor = new Stor();

  function Wallet() {
    if(!(this instanceof Wallet)) {
      return new Wallet();
    }
  }

  function getWordList(mlang) {
    if(mlang == 1) {
      return bip39.wordlists.japanese;
    } else {
      return bip39.wordlists.english;
    }
  }

  Wallet.prototype.getMnemonicToSeed = function(mnemonic, password) {
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

  Wallet.prototype.getMnemonicSeedType = function(type) {
    return MnemonicSeedType[type];
  }

  Wallet.prototype.getNonStandardMnemonicToSeeds = function(mnemonic, mlang) {
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

  Wallet.prototype.getMnemonicToSeeds = function(mnemonic, mlang, password) {
    var seeds = [];
    var m = mnemonic.replace(/[ 　\n\r]+/g, ' ').trim();
    var seed = bip39.mnemonicToSeedSync(m, password);
    seeds.push({seed: seed, type: password ? 2 : 1});
    var nonstd_seeds = this.getNonStandardMnemonicToSeeds(mnemonic, mlang);
    seeds = seeds.concat(nonstd_seeds);
    console.log('seeds:', seeds);
    return seeds;
  }

  Wallet.prototype.getHdNodeKeyPairs = function(seed, hdpath) {
    var node = bip32.fromSeed(seed);
    var child = node.derivePath(hdpath);
    return {priv: child.toBase58(), pub: child.neutered().toBase58()};
  }

  Wallet.prototype.getHdNodePrivate = function(seed, hdpath) {
    var node = bip32.fromSeed(seed);
    var child = node.derivePath(hdpath);
    return child.toBase58();
  }

  Wallet.prototype.getHdNodePublic = function(seed, hdpath) {
    var node = bip32.fromSeed(seed);
    var child = node.derivePath(hdpath);
    return child.neutered().toBase58();
  }

  function error(msg) {
    console.log('ERROR: ' + msg);
  }

  var _xpubs = [];
  var _utxos = [];
  var _nodes = {};

  Wallet.prototype.getXpubs = function() {
    _xpubs = stor.get_xpubs();
    return _xpubs;
  }

  Wallet.prototype.getXpub = function(xpub_idx) {
    return _xpubs[xpub_idx];
  }

  Wallet.prototype.checkXpubs = function(xpubs) {
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
        _nodes[xpub] = bip32.fromBase58(xpub);
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

  Wallet.prototype.setUtxos = function(utxos) {
    if(checkUtxos(utxos)) {
      _utxos = utxos;
      return true;
    }
    return false;
  }

  Wallet.prototype.addUtxos = function(utxos, deduplicate) {
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

  Wallet.prototype.getUtxos = function(utxos) {
    return _utxos;
  }

  return Wallet;
}());
