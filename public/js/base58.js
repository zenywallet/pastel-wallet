// Copyright (c) 2019 zenywallet
var base58_chars = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
var base58 = (function(base58_chars) {
  var base58_map = {};
  for(var i in base58_chars) {
    base58_map[base58_chars[i]] = Number(i);
  }
  var log58_256 = Math.log(256) / Math.log(58);
  var log256_58 = 1 / log58_256;
  function ceil_precision(x) {
    var precision = String(x).replace('.', '').length - x.toFixed().length;
    var multi = Number('1' + '0'.repeat(precision - 1));
    return Math.ceil(x * multi) / multi;
  }
  log58_256 = ceil_precision(log58_256);
  log256_58 = ceil_precision(log256_58);

  function obj_assign(obj, methods) {
    var o = Object.assign(obj, methods);
    var keys = Object.keys(methods);
    for(var i in keys) {
      Object.defineProperty(o, keys[i], {enumerable: false});
    }
    return o;
  }

  var methods = {
    toArray: function(str) {
      str = str || this;
      var array = new Uint8Array(str.length);
      for(var i in array) {
        array[i] = str.charCodeAt(i);
      }
      return obj_assign(array, methods);
    },

    toString: function(array) {
      array = array || this;
      var s = "";
      for(var i in array) {
        s += String.fromCharCode(array[i]);
      }
      return obj_assign(new String(s), methods);
    },

    enc: function(array) {
      array = array || this;
      var size = Math.ceil(array.length * log58_256);
      var buf = new Uint8Array(size);
      var carry;
      for(var i in array) {
        carry = array[i];
        for(var j = size - 1; j >= 0; j--) {
          carry += buf[j] * 256;
          buf[j] = carry % 58;
          carry /= 58;
        }
      }
      var enc;
      for(var i in buf) {
        if(enc) {
          enc += base58_chars[buf[i]];
        } else if(buf[i] != 0) {
          enc = base58_chars[buf[i]];
        }
      }
      return obj_assign(new String(enc), methods);
    },

    dec: function(str) {
      str = str || this;
      var size = Math.ceil(str.length * log256_58);
      var dec = new Uint8Array(size);
      var carry;
      for(var i in str) {
        carry = base58_map[str[i]];
        if(carry == null) {
          return null;
        }
        for(var j = size - 1; j >= 0; j--) {
          carry += dec[j] * 58;
          dec[j] = carry % 256;
          carry /= 256;
        }
      }
      for(var i in dec) {
        if(dec[i] != 0) {
          dec = dec.slice(i);
          break;
        }
      }
      return obj_assign(dec, methods);
    }
  }
  return methods;
})(base58_chars);
