# Copyright (c) 2019 zenywallet

{.emit: """
var base58_chars = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
var base58 = (function(base58_chars) {
  var base58_map = {};
  for(var i in base58_chars) {
    base58_map[base58_chars[i]] = Number(i);
  }

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
      var enc = '';
      for(var i in array) {
        if(array[i] != 0) {
          break;
        }
        enc += '1';
      }
      var b = [];
      for(var i = enc.length; i < array.length; i++) {
        var c = array[i];
        var j = 0;
        while(c > 0 || j < b.length) {
          if(j >= b.length) {
            b.push(0);
          } else {
            c += b[j] * 256;
          }
          b[j] = c % 58
          c = Math.floor(c / 58);
          j++;
        }
      }
      for(var i = b.length - 1; i >= 0; i--) {
        enc += base58_chars[b[i]];
      }
      return obj_assign(new String(enc), methods);
    },

    dec: function(str) {
      str = str || this;
      var zeroLen = 0;
      for(var i in str) {
        if(str[i] != '1') {
          break;
        }
        zeroLen++;
      }
      var b = [];
      for(var i = zeroLen; i < str.length; i++) {
        var c = base58_map[str[i]];
        if(c == null) {
          return null;
        }
        for(var j = 0; j < b.length; j++) {
          c += b[j] * 58;
          b[j] = c % 256;
          c = Math.floor(c / 256);
        }
        if(c > 0) {
          b.push(c);
        }
      }
      var dec = new Uint8Array(zeroLen + b.length);
      var j = zeroLen;
      for(var i = b.length - 1; i >= 0; i--) {
        dec[j] = b[i];
        j++;
      }
      return obj_assign(dec, methods);
    }
  }
  return methods;
})(base58_chars);
""".}
