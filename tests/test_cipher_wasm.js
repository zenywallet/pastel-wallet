/* Copyright (c) 2019 zenywallet */

var Module = require('../public/js/cipher.js');

for(var obj in Module) {
  console.log(obj);
}

var cipher = cipher || {};

Module.onRuntimeInitialized = function() {
  cipher.mod_init = Module.cwrap('cipher_init', null, ['number', 'number', 'number']);
  cipher.mod_enc = Module.cwrap('cipher_enc', null, ['number', 'number']);
  cipher.mod_dec = Module.cwrap('cipher_dec', null, ['number', 'number']);

  cipher.alloclist = cipher.alloclist || [];

  cipher.free = function() {
    var p = cipher.alloclist.shift();
    while(p) {
      Module._free(p);
      p = cipher.alloclist.shift();
    }
  }

  if(cipher.alloclist.length > 0) {
    cipher.free();
  }

  cipher.alloc = function(size) {
    var p = new Number(Module._malloc(size));
    p.set = function(array) {
      Module.HEAPU8.set(array, p);
    }
    p.get = function() {
      return (new Uint8Array(Module.HEAPU8.buffer, p, size)).slice();
    }
    p.free = function() {
      Module._free(p);
      cipher.alloclist.splice(cipher.alloclist.indexOf(p), 1);
    }
    cipher.alloclist.push(p);
    return p;
  }

  cipher.init = function(key, enc_iv, dec_iv) {
    var pkey = cipher.alloc(32);
    var penc_iv = cipher.alloc(32);
    var pdec_iv = cipher.alloc(32);
    pkey.set(key);
    penc_iv.set(enc_iv);
    pdec_iv.set(dec_iv);
    cipher.mod_init(pkey, penc_iv, pdec_iv);
    pdec_iv.free();
    penc_iv.free();
    pkey.free();
  }

  var enc_src = cipher.alloc(16);
  var enc_dst = cipher.alloc(16);
  var dec_src = cipher.alloc(16);
  var dec_dst = cipher.alloc(16);

  cipher.enc = function(data) {
    enc_src.set(data);
    cipher.mod_enc(enc_src, enc_dst);
    return enc_dst.get();
  }

  cipher.dec = function(data) {
    dec_src.set(data);
    cipher.mod_dec(dec_src, dec_dst);
    return dec_dst.get();
  }

  function test() {
    var key = new Uint8Array(32);
    var enc_iv = new Uint8Array(32);
    var dec_iv = new Uint8Array(32);
    var data = new Uint8Array(16);
    var enc = new Uint8Array(16);
    var dec = new Uint8Array(16);
    for(var i = 0; i < 32; i++) {
      key[i] = 10;
      enc_iv[i] = 0;
      dec_iv[i] = 0;
    }
    for(var i = 0; i < 16; i++) {
      data[i] = 0xa5;
      enc[i] = 0;
      dec[i] = 0;
    }

    console.log(Buffer.from(data).toString('hex'));
    cipher.init(key, enc_iv, dec_iv);
    for(var i = 0; i < 5; i++) {
      var enc = cipher.enc(data);
      var dec = cipher.dec(enc);
      console.log('----');
      console.log(Buffer.from(enc).toString('hex'));
      console.log(Buffer.from(dec).toString('hex'));
    }
  }

  test();
}
