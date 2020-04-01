var pastel = pastel || {};
pastel.config = pastel.config || {
  ws_url: 'ws://localhost:5001/',
  ws_protocol: 'pastel-v0.1',
  network: 'bitzeny'
};
pastel.utxoballs = new UtxoBalls();

String.prototype.toByteArray=String.prototype.toByteArray||(function(e){for(var b=[],c=0,f=this.length;c<f;c++){var a=this.charCodeAt(c);if(55296<=a&&57343>=a&&c+1<f&&!(a&1024)){var d=this.charCodeAt(c+1);55296<=d&&57343>=d&&d&1024&&(a=65536+(a-55296<<10)+(d-56320),c++)}128>a?b.push(a):2048>a?b.push(192|a>>6,128|a&63):65536>a?(55296<=a&&57343>=a&&(a=e?65534:65533),b.push(224|a>>12,128|a>>6&63,128|a&63)):1114111<a?b.push(239,191,191^(e?1:2)):b.push(240|a>>18,128|a>>12&63,128|a>>6&63,128|a&63)}return b})
Object.defineProperty(String.prototype, 'toByteArray', {
  enumerable: false
});
//function StringByteArray(s, e){for(var b=[],c=0,f=s.length;c<f;c++){var a=s.charCodeAt(c);if(55296<=a&&57343>=a&&c+1<f&&!(a&1024)){var d=s.charCodeAt(c+1);55296<=d&&57343>=d&&d&1024&&(a=65536+(a-55296<<10)+(d-56320),c++)}128>a?b.push(a):2048>a?b.push(192|a>>6,128|a&63):65536>a?(55296<=a&&57343>=a&&(a=e?65534:65533),b.push(224|a>>12,128|a>>6&63,128|a&63)):1114111<a?b.push(239,191,191^(e?1:2)):b.push(240|a>>18,128|a>>12&63,128|a>>6&63,128|a&63)}return b}

var zbar_stream = function(symbol, data, polygon, polysize) {}
pastel.ready = function() {}
pastel.load = function() {
  var ready_flag = {cipher: false, coin: false};
  var cipher = pastel.cipher || {};
  var cipherMod = {
    onRuntimeInitialized: function() {
      var Module = cipherMod;
      cipher.mod_init = Module.cwrap('cipher_init', null, ['number', 'number', 'number']);
      cipher.mod_enc = Module.cwrap('cipher_enc', null, ['number', 'number']);
      cipher.mod_dec = Module.cwrap('cipher_dec', null, ['number', 'number']);
      cipher.mod_set_key = Module.cwrap('serpent_set_key', 'number', ['number', 'number', 'number']);
      cipher.mod_encrypt = Module.cwrap('serpent_encrypt', null, ['number', 'number', 'number']);
      cipher.mod_decrypt = Module.cwrap('serpent_decrypt', null, ['number', 'number', 'number']);

      cipher.mod_create_keypair = Module.cwrap('ed25519_create_keypair', null, ['number', 'number', 'number']);
      cipher.mod_sign = Module.cwrap('ed25519_sign', null, ['number', 'number', 'number', 'number', 'number']);
      cipher.mod_verify = Module.cwrap('ed25519_verify', 'number', ['number', 'number', 'number', 'number']);
      cipher.mod_key_exchange = Module.cwrap('ed25519_key_exchange', null, ['number', 'number', 'number']);
      cipher.mod_get_publickey = Module.cwrap('ed25519_get_publickey', null, ['number', 'number']);
      cipher.mod_add_scalar = Module.cwrap('ed25519_add_scalar', null, ['number', 'number', 'number']);

      cipher.mod_yespower_hash = Module.cwrap('yespower_hash', 'number', ['number', 'number', 'number']);
      cipher.mod_yespower_n2r8 = Module.cwrap('yespower_n2r8', 'number', ['number', 'number', 'number']);
      cipher.mod_yespower_n4r16 = Module.cwrap('yespower_n4r16', 'number', ['number', 'number', 'number']);
      cipher.mod_yespower_n4r32 = Module.cwrap('yespower_n4r32', 'number', ['number', 'number', 'number']);

      cipher.mod_murmurhash = Module.cwrap('murmurhash', null, ['number', 'number', 'number']);
      cipher.zbar_init = Module.cwrap('zbar_init', null, [null]);
      cipher.zbar_destroy = Module.cwrap('zbar_destroy', null, [null]);
      cipher.mod_zbar_scan = Module.cwrap('zbar_scan', null, ['number', 'number', 'number']);

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
      if(isBigEndian) {
        throw new Error('big endian machines are not supported');
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

      cipher.buf2hex = function(buffer) {
        return Array.prototype.map.call(new Uint8Array(buffer), function(x) {return ('00' + x.toString(16)).slice(-2)}).join('');
      }

      cipher.setkey = function(key) {
        var pkey = cipher.alloc(key.length);
        var pl_key = cipher.alloc(140 * 4);
        pkey.set(key);
        cipher.mod_set_key(pkey, key.length * 8, pl_key);
        pkey.free();
        return pl_key;
      }

      cipher.encrypt = function(handle, data) {
        var src = cipher.alloc(16);
        var dst = cipher.alloc(16);
        src.set(data);
        cipher.mod_encrypt(handle, src, dst);
        var ret = dst.get();
        dst.free();
        src.free();
        return ret;
      }

      cipher.decrypt = function(handle, data) {
        var src = cipher.alloc(16);
        var dst = cipher.alloc(16);
        src.set(data);
        cipher.mod_decrypt(handle, src, dst);
        var ret = dst.get();
        dst.free();
        src.free();
        return ret;
      }

      cipher.countup = function(data) {
        for(var i in data) {
          data[i] = (data[i] + 1) & 0xff;
          if(data[i] != 0) {
            break;
          }
        }
      }

      var coin = coinlibs.coin;

      cipher.enc_json = function(key, json, deflate) {
        var h = cipher.setkey(key);
        var d = JSON.stringify(json);
        var comp;
        if(deflate) {
          comp = new Zopfli.RawDeflate(d.toByteArray(false)).compress();
        } else {
          comp = d.toByteArray(false);
        }
        var encdata = new Uint8Array(comp.length);
        var enc_iv = cipher.yespower(coin.crypto.sha256(key), 32).slice(0, 16);
        var pos = 0, next_pos = 16;
        while(next_pos < comp.length) {
          var enc = cipher.encrypt(h, enc_iv);
          cipher.countup(enc_iv);
          var dtmp = comp.slice(pos, next_pos);
          for(var i in enc) {
            enc[i] ^= dtmp[i];
          }
          encdata.set(enc, pos);
          pos = next_pos;
          next_pos += 16;
        }
        if(pos < comp.length) {
          var buf = new Uint8Array(16);
          var plen = comp.length - pos;
          buf.fill(plen);
          buf.set(comp.slice(pos, comp.length), 0)
          var enc = cipher.encrypt(h, enc_iv).slice(0, plen);
          for(var i in enc) {
            enc[i] ^= buf[i];
          }
          encdata.set(enc, pos);
        }
        console.log('encdata=', encdata);
        console.log(cipher.buf2hex(encdata));
        h.free();
        return encdata;
      }

      cipher.dec_json = function(key, encdata, deflate) {
        var h = cipher.setkey(key);
        var data = new Uint8Array(encdata, 0, encdata.length);
        var decdata = new Uint8Array(data.length);
        var dec_iv = cipher.yespower(coin.crypto.sha256(key), 32).slice(0, 16);
        var pos = 0, next_pos = 16;
        while(next_pos < data.length) {
          var dec = cipher.encrypt(h, dec_iv);
          cipher.countup(dec_iv);
          var dtmp = data.slice(pos, next_pos);
          for(var i in dec) {
            dec[i] ^= dtmp[i];
          }
          decdata.set(dec, pos);
          pos = next_pos;
          next_pos += 16;
        }
        if(pos < data.length) {
          var buf = new Uint8Array(16);
          var plen = data.length - pos;
          buf.fill(plen);
          buf.set(data.slice(pos, data.length), 0)
          var dec = cipher.encrypt(h, dec_iv).slice(0, plen);
          for(var i in dec) {
            dec[i] ^= buf[i];
          }
          decdata.set(dec, pos);
        }
        console.log('decdata=', decdata);
        if(deflate) {
          decdata = new Zlib.RawInflate(decdata, {verify: true}).decompress();
          console.log('decomp=', decdata);
        }
        var json = JSON.parse(new TextDecoder().decode(decdata));
        console.log(JSON.stringify(json));
        h.free();
        return json;
      }

      var crypto = window.crypto || window.msCrypto;

      cipher.createSeed = function() {
        if(crypto && crypto.getRandomValues) {
          var seed = new Uint8Array(32);
          crypto.getRandomValues(seed);
          return seed;
        } else {
          throw new Error('no secure crypto random');
        }
      }

      cipher.createKeyPair = function(seed) {
        var a_seed = cipher.alloc(32);
        var a_pubkey = cipher.alloc(32);
        var a_seckey = cipher.alloc(64);
        a_seed.set(seed);
        cipher.mod_create_keypair(a_pubkey, a_seckey, a_seed)
        var ret = {publicKey: a_pubkey.get(), secretKey: a_seckey.get()};
        a_seckey.free();
        a_pubkey.free();
        a_seed.free();
        return ret;
      }

      cipher.sign = function(msg, pubkey, seckey) {
        var msg_bytes = new Uint8Array(msg.toByteArray())
        var a_msg = cipher.alloc(msg_bytes.length);
        var a_pubkey = cipher.alloc(32);
        var a_seckey = cipher.alloc(64);
        var a_sig = cipher.alloc(64);
        a_msg.set(msg);
        a_pubkey.set(pubkey);
        a_seckey.set(seckey);
        cipher.sign(a_sig, a_msg, msg_bytes.length, a_pubkey, a_seckey);
        var sig = a_sig.get();
        a_sig.free();
        a_seckey.free();
        a_pubkey.free();
        a_msg.free();
        return sig;
      }

      cipher.verify = function(sig, msg, pubkey) {
        var a_sig = cipher.alloc(64);
        var msg_bytes = new Uint8Array(msg.toByteArray())
        var a_msg = cipher.alloc(msg_bytes.length);
        var a_pubkey = cipher.alloc(32);
        a_sig.set(sig);
        a_msg.set(msg_bytes);
        a_pubkey.set(pubkey);
        var ret = cipher.verify(a_sig, a_msg, msg_bytes.length, a_pubkey);
        a_pubkey.free();
        a_msg.free();
        a_sig.free();
        return (ret == 1);
      }

      cipher.keyExchange = function(pubkey, seckey) {
        var a_pubkey = cipher.alloc(32);
        var a_seckey = cipher.alloc(64);
        var a_shared = cipher.alloc(32);
        a_pubkey.set(pubkey);
        a_seckey.set(seckey);
        cipher.mod_key_exchange(a_shared, a_pubkey, a_seckey);
        var ret = a_shared.get();
        a_shared.free();
        a_seckey.free();
        a_pubkey.free();
        return ret;
      }

      cipher.getPublicKey = function(seckey) {
        var a_pubkey = cipher.alloc(32);
        var a_seckey = cipher.alloc(64);
        a_seckey.set(seckey);
        cipher.mod_get_publickey(a_pubkey, a_seckey)
        var ret = a_pubkey.get();
        a_seckey.free();
        a_pubkey.free();
        return ret;
      }

      cipher.addScalar = function(pubkey, seckey, scalar) {
        var a_pubkey = cipher.alloc(32);
        var a_seckey = cipher.alloc(64);
        var a_scalar = cipher.alloc(32);
        a_pubkey.set(pubkey);
        a_seckey.set(seckey);
        a_scalar.set(scalar);
        cipher.mod_add_scalar(a_pubkey, a_seckey, a_scalar);
        var ret = {publicKey: a_pubkey.get(), secretKey: a_seckey.get()};
        a_scalar.free();
        a_seckey.free();
        a_pubkey.free();
        return ret;
      }

      cipher.yespower = function(input, size) {
        var a_input = cipher.alloc(size);
        var a_output = cipher.alloc(32);
        a_input.set(input);
        cipher.mod_yespower_hash(a_input, size, a_output);
        var ret = a_output.get();
        a_output.free();
        a_input.free();
        return ret;
      }

      cipher.yespower_n2r8 = function(input, size) {
        var a_input = cipher.alloc(size);
        var a_output = cipher.alloc(32);
        a_input.set(input);
        cipher.mod_yespower_n2r8(a_input, size, a_output);
        var ret = a_output.get();
        a_output.free();
        a_input.free();
        return ret;
      }

      cipher.yespower_n4r16 = function(input, size) {
        var a_input = cipher.alloc(size);
        var a_output = cipher.alloc(32);
        a_input.set(input);
        cipher.mod_yespower_n4r16(a_input, size, a_output);
        var ret = a_output.get();
        a_output.free();
        a_input.free();
        return ret;
      }

      cipher.yespower_n4r32 = function(input, size) {
        var a_input = cipher.alloc(size);
        var a_output = cipher.alloc(32);
        a_input.set(input);
        cipher.mod_yespower_n4r32(a_input, size, a_output);
        var ret = a_output.get();
        a_output.free();
        a_input.free();
        return ret;
      }

      cipher.murmurhash = function(data) {
        var input = cipher.alloc(data.length);
        var output = cipher.alloc(16);
        input.set(data);
        cipher.mod_murmurhash(input, data.length, output);
        var ret = output.get();
        output.free();
        input.free();
        return ret;
      }

      cipher.zbar_scan = function(raw, width, height) {
        var p = cipher.alloc(width * height * 4);
        p.set(raw);
        var ret = cipher.mod_zbar_scan(p, width, height);
        p.free();
        return ret;
      }

      cipher.result = function(symbol, data, polygon) {}

      cipher.stream = function(symbol, data, polygon, polysize) {
        var resultView = new Int32Array(Module.HEAP32.buffer, polygon, polysize * 2);
        var coordinates = new Int32Array(resultView);
        cipher.result(Module.UTF8ToString(symbol), Module.UTF8ToString(data), coordinates);
      }
      zbar_stream = cipher.stream
      cipher.zbar_init();

      pastel.cipher = cipher;
      ready_flag.cipher = true;
    }
  };

  cipherMod = Cipher(cipherMod);

  pastel.coin = coinlibs.coin;
  ready_flag.coin = true;

  var stime = new Date();
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

var Stream = (function() {
  var reconnect_timer;
  var reconnect_count = 3;
  var status = 0;
  var pause = false;
  var monitor = null;
  var visibility_func_cb = function() {};
  function visibility_func() {
    visibility_func_cb();
  }
  function set_visibility_event(cb) {
    visibility_func_cb = cb;
    window.removeEventListener('visibilitychange', visibility_func);
    window.addEventListener('visibilitychange', visibility_func);
  }

  function Stream(ws_url, ws_protocol) {
    if(this instanceof Stream) {
      this.ws_url = ws_url;
      this.ws_protocol = ws_protocol;
      var self = this;
      self.startMonitor();
      $(window).on('beforeunload', function() {
        self.stop();
      });
      set_visibility_event(function() {
        if(document.hidden) {
          if(!pause && status == 1) {
            pause = true;
            self.stop();
          }
        } else {
          if(pause && status == 0) {
            pause = false;
            self.start();
          }
        }
      });
    } else {
      return new Stream(ws_url, ws_protocol);
    }
  }

  Stream.prototype.onOpen = function(evt) {}

  Stream.prototype.onMessage = function(evt) {}

  Stream.prototype.send = function(data) {
    if(this.ws.readyState === WebSocket.OPEN) {
      this.ws.send(data);
      return true;
    }
    return false;
  }

  Stream.prototype.connect = function() {
    var self = this;
    this.ws = new WebSocket(this.ws_url, this.ws_protocol);
    this.ws.binaryType = 'arraybuffer';
    this.ws.onopen = function(evt) {
      self.showStatus(true);
      self.onOpen(evt);
    }
    this.ws.onmessage = this.onMessage;
    this.ws.onclose = function() {
      self.showStatus(false);
      status = 0;
      console.log('onclose');
      clearTimeout(reconnect_timer);
      if(reconnect_count > 0) {
        reconnect_timer = setTimeout(function() {
          console.log('reconnect');
          reconnect_count--;
          self.connect();
        }, 5000);//10000 + Math.round(Math.random() * 20) * 1000);
      }
    }
  }

  Stream.prototype.status = function() {
    return status;
  }

  Stream.prototype.start = function() {
    status = 1;
    reconnect_count = 3;
    this.connect();
  }

  Stream.prototype.stop = function() {
    reconnect_count = 0;
    clearTimeout(reconnect_timer);
    if(this.ws) {
      this.ws.close();
    }
  }

  Stream.prototype.startMonitor = function() {
    this.monitor = document.getElementById('connection-monitor');
    if(!monitor) {
      var elm = document.createElement('div');
      elm.id = 'connection-monitor';
      this.monitor = document.body.appendChild(elm);
      var self = this;
      elm.addEventListener('click', function() {
        if(!status) {
          self.start();
        }
      });
    }
  }

  Stream.prototype.showStatus = function(status) {
    if(status) {
      this.monitor.innerHTML = '<i class="heartbeat icon"></i>';
    } else {
      this.monitor.innerHTML = '<i class="heart outline icon"></i>';
    }
  }
  return Stream;
}());

pastel.ready = function() {
  console.log('pastel ready');
  console.log(pastel);
  var cipher = pastel.cipher;
  var coin = pastel.coin;

  var seed = cipher.createSeed();
  var kp = cipher.createKeyPair(seed);
  var shared = null;
  var stage = 0;
  var wallet = new Wallet();
  pastel.wallet = wallet;
  var stream = new Stream(pastel.config.ws_url, pastel.config.ws_protocol);

  stream.onOpen = function(evt) {
    seed = cipher.createSeed();
    kp = cipher.createKeyPair(seed);
    shared = null;
    stage = 0;
    stream.send(kp.publicKey);
  }

  pastel.stream_ready = function() {
    return stage == 1;
  }

  pastel.send = function(json) {
    if(stage != 1) {
      return false;
    }
    var d = JSON.stringify(json);
    var comp = new Zopfli.RawDeflate(d.toByteArray(false)).compress();
    var sdata = new Uint8Array(comp.length);
    var pos = 0, next_pos = 16;
    while(next_pos < comp.length) {
      var enc = cipher.enc(comp.slice(pos, next_pos));
      sdata.set(enc, pos);
      pos = next_pos;
      next_pos += 16;
    }
    if(pos < comp.length) {
      var buf = new Uint8Array(16);
      var plen = comp.length - pos;
      buf.fill(plen);
      buf.set(comp.slice(pos, comp.length), 0)
      var enc = cipher.enc(buf).slice(0, plen);
      sdata.set(enc, pos);
    }
    return stream.send(sdata);
  }

  function thousands_separators(num) {
    var num_parts = num.toString().split(".");
    num_parts[0] = num_parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ",");
    return num_parts.join(".");
  }

  function conv_coin(uint64_val) {
    var strval = uint64_val.toString();
    var val = parseInt(strval);
    if(val > Number.MAX_SAFE_INTEGER) {
      var d = strval.slice(-8).replace(/0+$/, '');
      var n = thousands_separators(strval.substr(0, strval.length - 8));
      if(d.length > 0) {
        return n + '.' + d;
      } else {
        return n;
      }
    }
    return thousands_separators(val / 100000000);
  }

  function fadeIn(el, speed) {
    el.style.opacity = 0;
    el.style.display = 'block';
    var start = null;
    requestAnimationFrame(function fade(timestamp) {
      if (!start) start = timestamp;
      var progress = (timestamp - start) / speed;
      el.style.opacity = Math.min(progress, 1);
      if (progress < 1) {
        requestAnimationFrame(fade);
      }
    });
  }

  pastel.unspents_after_actions = [];

  pastel.secure_recv = function(json) {
    var type = json['type'];
    var data = json['data'];
    console.log('recv ' + (data ? (type + ': ' + JSON.stringify(data)) : (type ? type : 'unknown')));
    if(type == 'xpubs') {
      if(!wallet.checkXpubs(data)) {
        throw new Error('check xpubs');
      }
    } else if(type == 'unspents') {
      wallet.setUtxos(data);
      pastel.utxoballs.setUtxos(data);
      var action;
      while(action = pastel.unspents_after_actions.shift()) {
        action();
      }
    } else if(type == 'unconfs') {
      var send = UINT64(0);
      var recv = UINT64(0);
      var recv_change = UINT64(0);
      var fee = UINT64(0);
      if(data) {
        for(var addr in data.addrs) {
          var txouts = data.addrs[addr].txouts;
          if(txouts) {
            if(data.addrs[addr].change == 0) {
              for(var i in txouts) {
                var txout = txouts[i];
                recv.add(UINT64(String(txout.value)));
              }
            } else {
              for(var i in txouts) {
                var txout = txouts[i];
                recv_change.add(UINT64(String(txout.value)));
              }
            }
          }
        }
        var chk_addrs = {};
        for(var addr in data.addrs) {
          chk_addrs[addr] = 1;
          var spents = data.addrs[addr].spents;
          if(spents) {
            for(var i in spents) {
              var spent = spents[i];
              send.add(UINT64(String(spent.value)));
            }
          }
        }
        if(send.greaterThan(recv_change) || send.eq(recv_change)) {
          send.subtract(recv_change);
        }
        for(var txid in data.txs) {
          var tx = data.txs[txid];
          var find = false;
          var find_else = 0;
          var s0 = UINT64(0);
          var s1 = UINT64(0);
          for(var txa in tx.data) {
            var v = tx.data[txa]
            for(var i in v) {
              if(i == 0) {
                if(chk_addrs[txa]) {
                  find = true;
                } else {
                  find_else++;
                }
                s0.add(UINT64(String(v[i])));
              } else if(i == 1) {
                s1.add(UINT64(String(v[i])));
              }
            }
          }
          if(find && find_else == 0) {
            fee.add(s0.subtract(s1));
          }
        }
      }
      if(send.greaterThan(UINT64(0))) {
        if(fee.eq(0)) {
          $('#wallet-balance .send span').text(conv_coin(send));
        } else {
          send.subtract(fee);
          $('#wallet-balance .send span').text(conv_coin(send) + ' / ' + conv_coin(fee));
        }
        $('#wallet-balance .send').fadeIn(400);
      } else {
        $('#wallet-balance .send').fadeOut(400);
      }
      if(recv.greaterThan(UINT64(0))) {
        $('#wallet-balance .receive span').text(conv_coin(recv));
        $('#wallet-balance .receive').fadeIn(400);
      } else {
        $('#wallet-balance .receive').fadeOut(400);
      }
      TradeLogs.unconfs(data);
      wallet.setUnconfs(data);
      pastel.utxoballs.setUnconfs(data);
    } else if(type == 'balance') {
      $('#wallet-balance .balance').text(conv_coin(data));
      var el = document.getElementById('wallet-balance');
      if(!el.style.display) {
        fadeIn(el, 800);
      }
    } else if(type == 'addresses') {
    } else if(type == 'unused') {
      var changed = wallet.setUnusedAddress(data);
      if(changed) {
        showRecvAddress(function() {
          showRecvAddressAfterEffect();
        });
      }
    } else if(type == 'change') {
      wallet.setChange(data);
    } else if(type == 'height') {
      TradeLogs.update_height(data);
    } else if(type == 'rollback') {
      console.log('rollback');
    } else if(type == 'rollbacked') {
      TradeLogs.rollbacked(data);
      pastel.send({cmd: 'unspents'});
    } else if(type == 'txlogs') {
      if(data) {
        TradeLogs.get_txlogs_cb(data);
      }
    } else if(type == 'rawtx') {
      pastel.wallet.rawtxResult(data);
    } else if(type == 'time') {
      if(data) {
        TradeLogs.server_time(data);
      }
    } else if(type == 'ready') {
      var xpubs = wallet.getXpubs();
      pastel.send({cmd: 'xpubs', data: xpubs});
    } else {
      console.log('unknown: ' + JSON.stringify(json));
    }
  }

  pastel.unsecure_recv = function(data) {
    try {
      var json = JSON.parse(data);
      console.log(JSON.stringify(json));
    } catch(ex) {
      console.log(data);
    }
  }

  stream.onMessage = function(evt) {
    if(typeof evt.data == 'object') {
      var data = new Uint8Array(evt.data, 0, evt.data.length);
      if(stage == 1) {
        var rdata = new Uint8Array(data.length);
        var pos = 0, next_pos = 16;
        while(next_pos < data.length) {
          var dec = cipher.dec(data.slice(pos, next_pos));
          rdata.set(dec, pos);
          pos = next_pos;
          next_pos += 16;
        }
        if(pos < data.length) {
          var buf = new Uint8Array(16);
          var plen = data.length - pos;
          buf.fill(plen);
          buf.set(data.slice(pos, data.length), 0)
          var dec = cipher.dec(buf).slice(0, plen);
          rdata.set(dec, pos);
        }
        var decomp = new Zlib.RawInflate(rdata, {verify: true}).decompress();
        var json = JSON.parse(new TextDecoder().decode(decomp));
        pastel.secure_recv(json);
      } else if(stage == 0 && !shared && data.length == 96) {
        var pub = data.slice(0, 32);
        shared = cipher.keyExchange(pub, kp.secretKey);
        var shared_key = cipher.yespower(coin.crypto.sha256(shared), 32);
        var shared_key_uint8array = new Uint8Array(shared_key);
        shared = shared_key_uint8array;

        var seed_srv = data.slice(32, 64);
        var seed_cli = data.slice(64, 96);
        var rs = new Uint8Array(32);
        var rc = new Uint8Array(32);
        for(var i = 0; i < 32; i++) {
          rs[i] = shared[i] ^ seed_srv[i];
          rc[i] = shared[i] ^ seed_cli[i];
        }
        var iv_srv = cipher.yespower(coin.crypto.sha256(rs), 32);
        var iv_cli = cipher.yespower(coin.crypto.sha256(rc), 32);
        cipher.init(shared, iv_cli, iv_srv);

        stage = 1;
        pastel.send({cmd: 'ready'});
      } else {
        console.log(data);
      }
    } else if(typeof evt.data == 'string') {
      pastel.unsecure_recv(evt.data);
    }
  }

  pastel.stream = stream;
}
pastel.load();
