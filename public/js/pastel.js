var pastel = pastel || {};
pastel.config = pastel.config || {
  ws_url: 'ws://localhost:5001/',
  ws_protocol: 'pastel-v0.1'
};

pastel.ready = function() {}
pastel.load = function() {
  var ready_flag = {supercop: false, cipher: false, coin: false};
  supercop_wasm.ready(function() {
    pastel.supercop = supercop_wasm;
    ready_flag.supercop = true;
  });

  var cipher = pastel.cipher || {};
  var cipherMod = {
    onRuntimeInitialized: function() {
      var Module = cipherMod;
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

      var isBigEndian = new Uint8Array(new Uint32Array([0x12345678]).buffer)[0] === 0x12;
      function endian_swap(array) {
        var ret_array = new Uint8Array(array.length);
        var pos = 0;
        for(var i = 0; i < array.length; i+= 4) {
          for(var j = 3; j >= 0; j--) {
            ret_array[pos] = array[i + j];
            pos++;
          }
        }
        return ret_array;
      }

      cipher.alloc = function(size) {
        var p = new Number(Module._malloc(size));
        if(isBigEndian) {
          p.set = function(array) {
            Module.HEAPU8.set(endian_swap(array), p);
          }
          p.get = function() {
            return endian_swap((new Uint8Array(Module.HEAPU8.buffer, p, size)).slice());
          }
        } else {
          p.set = function(array) {
            Module.HEAPU8.set(array, p);
          }
          p.get = function() {
            return (new Uint8Array(Module.HEAPU8.buffer, p, size)).slice();
          }
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

      cipher.buf2hex = function(buffer) {
        return Array.prototype.map.call(new Uint8Array(buffer), function(x) {return ('00' + x.toString(16)).slice(-2)}).join('');
      }

      pastel.cipher = cipher;
      ready_flag.cipher = true;
    }
  };
  cipherMod = Cipher(cipherMod);

  pastel.coin = coin;
  ready_flag.coin = true;

  stime = new Date();
  var check_ready = function() {
    setTimeout(function() {
      var check = true;
      for(var i in ready_flag) {
        if(ready_flag[i] == false) {
          check = false;
          break;
        }
      }
      if(check) {
        pastel.ready();
      } else {
        var etime = new Date();
        var sec = (etime - stime) / 1000;
        if(sec < 5 * 60) {
          check_ready();
        } else {
          // giveup
        }
      }
    }, 100);
  }
  check_ready();
}
