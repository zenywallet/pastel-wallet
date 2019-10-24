var TradeLogs = (function() {
  var cipher;
  var coin;
  var network;
  var crypto;

  function get_test_tx() {
    var data = new Uint8Array(32);
    crypto.getRandomValues(data);
    var hash = coin.crypto.sha256(data);
    var txid = hash.toString('hex');

    const keyPair = coin.ECPair.makeRandom();
    const { address } = coin.payments.p2pkh({ pubkey: keyPair.publicKey, network: network });

    return {address: address, txid: txid};
  }

  var test_tx_count = 0;
  function get_txlogs(limit, sequence, cb) {
    setTimeout(function() {
      var items = [];
      for(var i = 0; i < limit; i++) {
        if(test_tx_count >= 50) {
          cb(items);
          return;
        }
        test_tx_count++;
        items.push(get_test_tx());
      }
      cb(items);
    }, 200);
  }

  function txlogs_item(item) {
    var data = item;
    imgsrc = DotMatrix.getImage(cipher.buf2hex(cipher.murmurhash((new TextEncoder).encode(data.address))), 36, 1);
    var send = Math.round(Math.random()) == 0;
    var confirm = Math.round(Math.random()) == 0;
    var extra = confirm ? '<div class="extra content confirmed">' : '<div class="extra content unconfirmed">';
    confirm_msg = confirm ? '<i class="paw icon"></i> Confirmed (12345)' : '<i class="red dont icon"></i> Unconfirmed';
    var amount = Math.round(Math.random() * 100000 * 100000000) / 100000000;
    var h = '<div class="ui centered card metal">'
      + '<div class="content">'
      + '<img class="right floated mini ui image" src="' + imgsrc + '">'
      + '<div class="header">'
      + '<i class="' + (send ? 'counterclockwise rotated sign-out icon send' : 'clockwise rotated sign-in icon receive') + '"></i> ' + (send ? 'SEND' : 'RECEIVE')
      + '</div>'
      + '<div class="meta">'
      + '0000-00-00 00:00:00<br>'
      + '2 months ago'
      + '</div>'
      + '<div class="description">'
      + '<span class="right floated">' + amount + ' ZNY</span>'
      + data.address
      + '<div class="meta txid">'
      + data.txid
      + '</div>'
      + '</div>'
      + '</div>'
      + extra
      + '<span class="right floated">'
      + '0000-00-00 00:00:00'
      + '</span>'
      + '<span>'
      + confirm_msg
      + '</span>'
      + '</div>'
      + '</div>';
    return h;
  }

  var itemcache = [];
  var sequence = 0;
  var limit = 100;
  var cachelimit = 100;
  var eof = false;

  function infinite_additem(item) {
    var h = txlogs_item(item);
    $(h).hide().appendTo('#tradelogs').fadeIn(600);
  }

  var check_scroll_busy = false;
  function check_scroll() {
    var spos = $(window).scrollTop() + $(window).height();
    var dpos = $(document).height();
    if(spos + 600 > dpos) {
      check_scroll_busy = true;

      var item = itemcache.shift();
      if(item) {
        infinite_additem(item);
        loadcache();

        setTimeout(function() {
          check_scroll();
        }, 10);
      } else {
        loadcache();
      }
    } else {
      check_scroll_busy = false;
    }
  }

  var loadcache_loading = false;
  function loadcache() {
    if(itemcache.length < cachelimit && !eof && !loadcache_loading) {
      loadcache_loading = true;
      get_txlogs(limit, sequence, function(data) {
        if(data.length <= 0) {
          eof = true;
        } else {
          itemcache = itemcache.concat(data);
          check_scroll();
        }
        loadcache_loading = false;
      });
    }
  }

  function scroll_listener(e) {
    var spos = $(window).scrollTop() + $(window).height();
    var dpos = $(document).height();
    if(spos + 600 > dpos) {
      if(!check_scroll_busy) {
        check_scroll();
      }
    }
  }

  var TradeLogs = {};

  TradeLogs.start = function() {
    cipher = cipher || pastel.cipher;
    coin = coin || coinlibs.coin;
    network = network || coin.networks.bitzeny;
    crypto = crypto || window.crypto || window.msCrypto;

    if(!$('#tradelogs').length) {
      return;
    }

    console.log('start');
    test_tx_count = 0;
    eof = false;
    loadcache();
    window.addEventListener('scroll', scroll_listener);
    check_scroll();
  }

  TradeLogs.stop = function() {
    console.log('stop');
    window.removeEventListener('scroll', scroll_listener);
  }

  return TradeLogs;
})();
