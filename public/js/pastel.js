var pastel = pastel || {};
pastel.config = pastel.config || {
  ws_url: 'ws://localhost:5001/',
  ws_protocol: 'pastel-v0.1'
};

String.prototype.toByteArray=String.prototype.toByteArray||(function(e){for(var b=[],c=0,f=this.length;c<f;c++){var a=this.charCodeAt(c);if(55296<=a&&57343>=a&&c+1<f&&!(a&1024)){var d=this.charCodeAt(c+1);55296<=d&&57343>=d&&d&1024&&(a=65536+(a-55296<<10)+(d-56320),c++)}128>a?b.push(a):2048>a?b.push(192|a>>6,128|a&63):65536>a?(55296<=a&&57343>=a&&(a=e?65534:65533),b.push(224|a>>12,128|a>>6&63,128|a&63)):1114111<a?b.push(239,191,191^(e?1:2)):b.push(240|a>>18,128|a>>12&63,128|a>>6&63,128|a&63)}return b})
Object.defineProperty(String.prototype, 'toByteArray', {
  enumerable: false
});
//function StringByteArray(s, e){for(var b=[],c=0,f=s.length;c<f;c++){var a=s.charCodeAt(c);if(55296<=a&&57343>=a&&c+1<f&&!(a&1024)){var d=s.charCodeAt(c+1);55296<=d&&57343>=d&&d&1024&&(a=65536+(a-55296<<10)+(d-56320),c++)}128>a?b.push(a):2048>a?b.push(192|a>>6,128|a&63):65536>a?(55296<=a&&57343>=a&&(a=e?65534:65533),b.push(224|a>>12,128|a>>6&63,128|a&63)):1114111<a?b.push(239,191,191^(e?1:2)):b.push(240|a>>18,128|a>>12&63,128|a>>6&63,128|a&63)}return b}

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

      cipher.mod_create_keypair = Module.cwrap('ed25519_create_keypair', null, ['number', 'number', 'number']);
      cipher.mod_sign = Module.cwrap('ed25519_sign', null, ['number', 'number', 'number', 'number', 'number']);
      cipher.mod_verify = Module.cwrap('ed25519_verify', 'number', ['number', 'number', 'number', 'number']);
      cipher.mod_key_exchange = Module.cwrap('ed25519_key_exchange', null, ['number', 'number', 'number']);
      cipher.mod_get_publickey = Module.cwrap('ed25519_get_publickey', null, ['number', 'number']);
      cipher.mod_add_scalar = Module.cwrap('ed25519_add_scalar', null, ['number', 'number', 'number']);

      cipher.mod_yespower_hash = Module.cwrap('yespower_hash', 'number', ['number', 'number', 'number']);

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

      pastel.cipher = cipher;
      ready_flag.cipher = true;
    }
  };

  cipherMod = Cipher(cipherMod);

  pastel.coin = coinlibs.coin;
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

var Stream = (function() {
  var reconnect_timer;
  var reconnect = true;

  function Stream(ws_url, ws_protocol) {
    if(this instanceof Stream) {
      this.ws_url = ws_url;
      this.ws_protocol = ws_protocol;
      var self = this;
      $(window).on('beforeunload', function() {
        self.stop();
      });
    } else {
      return new Stream(url, protocol);
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
    reconnect = true;
    this.ws = new WebSocket(this.ws_url, this.ws_protocol);
    this.ws.binaryType = 'arraybuffer';
    this.ws.onopen = this.onOpen;
    this.ws.onmessage = this.onMessage;
    var self = this;
    this.ws.onclose = function() {
      console.log('onclose');
      clearTimeout(reconnect_timer);
      if(reconnect) {
        reconnect_timer = setTimeout(function() {
          console.log('reconnect');
          self.connect();
        }, 5000);//10000 + Math.round(Math.random() * 20) * 1000);
      }
    }
  }

  Stream.prototype.start = function() {
    this.connect();
  }

  Stream.prototype.stop = function() {
    reconnect = false;
    clearTimeout(reconnect_timer);
    if(this.ws) {
      this.ws.close();
    }
  }

  return Stream;
}());

var Stor = (function() {
  var db;
  function Stor() {
    if(this instanceof Stor) {
      db = localStorage;
    } else {
      return new Stor();
    }
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

  return Stor;
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
  var stream = new Stream(pastel.config.ws_url, pastel.config.ws_protocol);

  stream.onOpen = function(evt) {
    seed = cipher.createSeed();
    kp = cipher.createKeyPair(seed);
    shared = null;
    stage = 0;
    stream.send(kp.publicKey);
    console.log('client publicKey=' + JSON.stringify(kp.publicKey));
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
    console.log(comp.length);
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
    console.log('sdata=', sdata);
    console.log(cipher.buf2hex(sdata));
    stream.send(sdata);
    return true;
  }

  pastel.secure_recv = function(json) {
    //console.log(JSON.stringify(json));
  }

  pastel.unsecure_recv = function(data) {
    try {
      var json = JSON.parse(data);
      //console.log(JSON.stringify(json));
    } catch(ex) {
      //console.log(data);
    }
  }

  stream.onMessage = function(evt) {
    if(typeof evt.data == 'object') {
      var data = new Uint8Array(evt.data, 0, evt.data.length);
      console.log('object=', data);
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
        console.log('rdata=', rdata);
        var decomp = new Zlib.RawInflate(rdata, {verify: true}).decompress();
        console.log('decomp=', decomp);
        var json = JSON.parse(new TextDecoder("utf-8").decode(decomp));
        console.log(JSON.stringify(json));
        pastel.secure_recv(json);
      } else if(stage == 0 && !shared && data.length == 96) {
        console.log('stage=0, length=96');
        var pub = data.slice(0, 32);
        console.log('server publicKey=' + JSON.stringify(pub));
        shared = cipher.keyExchange(pub, kp.secretKey);
        console.log('shared=' + JSON.stringify(shared));
        var shared_key = cipher.yespower(coin.crypto.sha256(shared), 32);
        var shared_key_uint8array = new Uint8Array(shared_key);
        console.log('shared hash=' + JSON.stringify(shared_key));
        console.log('shared hash=' + JSON.stringify(shared_key_uint8array));
        console.log('shared hash=' + shared_key.toString('hex'));
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
        console.log(cipher.buf2hex(shared));
        console.log(cipher.buf2hex(iv_srv));
        console.log(cipher.buf2hex(iv_cli));
        cipher.init(shared, iv_cli, iv_srv);

        stage = 1;

        pastel.send({test: "日本語", test1: 1234, test2: 5678901234, test3: 1234, test4: 123, test5: 123, test6: 123});
        /*var comp = new Zopfli.RawDeflate("日本".toByteArray(false)).compress();
        console.log('comp length=', comp.length);
        console.log(comp);
        var enc = cipher.enc(comp).slice(0, comp.length);
        console.log('enc=', enc);
        console.log(cipher.buf2hex(enc));
        ws.send(enc);*/
      } else {
        console.log(data);
      }
    } else if(typeof evt.data == 'string') {
      console.log(evt.data);
      pastel.unsecure_recv(evt.data);
    }
  }

  stream.start();

  var stor = new Stor();

  var send_xpub_retry_count = 0;
  function send_xpub() {
    if(pastel.stream_ready()) {
      var xpubs = stor.get_xpubs();
      var sendflag = true;
      for(var i in xpubs) {
        var ret = pastel.send({cmd: 'xpub', data: xpubs[i]});
        if(!ret) {
          sendflag = false;
        }
      }
      if(sendflag) {
        return;
      }
    }
    if(send_xpub_retry_count < 300) {
      send_xpub_retry_count++;
      setTimeout(send_xpub, 1000);
    } else {
      // giveup
    }
  }
  send_xpub();
}
pastel.load();
