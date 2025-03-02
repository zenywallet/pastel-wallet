# Copyright (c) 2019 zenywallet

import caprese/contents

const SeedScript = """
var crypto = window.crypto || window.msCrypto;
if(crypto && crypto.getRandomValues) {
  var priv = new Uint8Array(32);
  crypto.getRandomValues(priv);
  var priv_base58 = base58.enc(priv);
  var priv_dec = priv_base58.dec();
  var enc_err = 0;
  if(priv.length != priv_dec.length) {
    enc_err = 1;
  } else {
    for(var i in priv) {
      if(priv[i] != priv_dec[i]) {
        enc_err = 1;
        break;
      }
    }
  }
  if(enc_err) {
    throw new Error('base58 encode failed.');
  }

  var tags = new Uint8Array(6);
  crypto.getRandomValues(tags);
  var tag = "";
  for(var i in tags) {
    tag += base58_chars[tags[i] % 58]
  }
  var seedstr = 'seed:' + priv_base58 + ',tag:' + tag + ',gen:pastel-v0.1';
  document.getElementById('seed').innerHTML = seedstr;
  var s = 400;
  $('#qrcode').qrcode({
    render: 'canvas',
    ecLevel: 'Q',
    radius: 0.39,
    text: seedstr,
    size: s,
    mode: 2,
    label: 'seed',
    fontname: 'sans',
    fontcolor: '#393939'
  });
} else {
  throw new Error('Secure random number generation is not supported by this browser.');
}
"""

const SeedHtml* = staticHtmlDocument:
  buildHtml(html):
    head:
      meta(charset="utf-8")
      script(type="text/javascript", src="/js/jquery-3.4.1.slim.min.js")
      script(type="text/javascript", src="/js/jquery-qrcode.min.js")
      script(type="text/javascript", src="/js/base58.js")
      title: text "Seed Maker"
    body:
      tdiv(id="qrcode")
      tdiv(id="seed")
      script: verbatim SeedScript
