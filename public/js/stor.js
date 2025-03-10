// Copyright (c) 2019 zenywallet
var Stor = (function() {
  var db;
  function Stor() {
    if(this instanceof Stor) {
      db = localStorage;
    } else {
      return new Stor();
    }
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

  Stor.prototype.add_xpub = function(xpub) {
    var xpubs = db['xpubs'];
    if(xpubs) {
      xpubs = JSON.parse(xpubs);
    } else {
      xpubs = [];
    }
    if(!xpubs.includes(xpub)) {
      xpubs.push(xpub);
      db['xpubs'] = JSON.stringify(xpubs);
    }
  }

  Stor.prototype.set_xpubs = function(xpubs) {
    db['xpubs'] = JSON.stringify(xpubs);
  }

  Stor.prototype.get_xpubs = function() {
    var xpubs = db['xpubs'];
    if(xpubs) {
      xpubs = JSON.parse(xpubs);
    } else {
      xpubs = [];
    }
    return xpubs;
  }

  Stor.prototype.del_xpub = function(xpub) {
    var xpubs = db['xpubs'];
    if(xpubs) {
      xpubs = JSON.parse(xpubs);
      var idx = xpubs.indexOf(xpub);
      if(idx >= 0) {
        xpubs.splice(idx, 1);
        db['xpubs'] = JSON.stringify(xpubs);
      }
    } else {
      xpubs = [];
    }
    if(xpubs.length == 0) {
      db.removeItem('xpubs');
    }
  }

  Stor.prototype.del_xpubs = function() {
    db.removeItem('xpubs');
  }

  Stor.prototype.del_all = function() {
    db.clear();
  }

  Stor.prototype.get_salt = function(create_no_exists) {
    var salt = db['salt'];
    if(salt) {
      return hex2buf(salt);
    }

    if(create_no_exists) {
      var buf = new Uint8Array(32);
      crypto.getRandomValues(buf);
      db['salt'] = buf2hex(buf);

      salt = db['salt'];
      if(salt) {
        return hex2buf(salt);
      }
      return null;
    } else {
      return null;
    }
  }

  Stor.prototype.set_shield = function(data) {
    db['shield'] = buf2hex(data);
  }

  Stor.prototype.get_shield = function() {
    return hex2buf(db['shield']);
  }

  Stor.prototype.set_lock_type = function(lock_type) {
    db['locktype'] = lock_type;
  }

  Stor.prototype.get_lock_type = function() {
    return db['locktype'];
  }

  Stor.prototype.set_lang = function(lang) {
    db['lang'] = lang;
  }

  Stor.prototype.get_lang = function() {
    return db['lang'];
  }

  return Stor;
}());
