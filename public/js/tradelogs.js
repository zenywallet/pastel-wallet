var TradeLogs = (function() {
  var cipher;
  var coin;
  var network;
  var crypto;
  var _height = 0;

  function conv_coin(uint64_val) {
    var strval = uint64_val.toString();
    var val = parseInt(strval);
    if(val > Number.MAX_SAFE_INTEGER) {
      var d = strval.slice(-8).replace(/0+$/, '');
      var n = strval.substr(0, strval.length - 8);
      if(d.length > 0) {
        return n + '.' + d;
      } else {
        return n;
      }
    }
    return val / 100000000;
  }

  function get_txlogs(sequence, rev_flag) {
    if(sequence == null) {
      pastel.send({cmd: "txlogs"});
    } else {
      if(rev_flag) {
        pastel.send({cmd: "txlogs", data: {lt: sequence}});
      } else{
        pastel.send({cmd: "txlogs", data: {gt: sequence}});
      }
    }
  }

  function conv_time(unix_time) {
    var dt = new Date(unix_time * 1000)
    var local_time = dt.getFullYear() + '-'
      + ('00' + (dt.getMonth() + 1)).slice(-2) + '-'
      + ('00' + dt.getDate()).slice(-2) + ' '
      + ('00' + dt.getHours()).slice(-2) + ':'
      + ('00' + dt.getMinutes()).slice(-2) + ':'
      + ('00' + dt.getSeconds()).slice(-2);
    return local_time;
  }

  var time_elapsed_list = [
    {key: "week", val: 7 * 24 * 60 * 60},
    {key: "day", val: 24 * 60 * 60},
    {key: "hour", val: 60 * 60},
    {key: "minute", val: 60}
  ];

  var server_time_diff = 0;
  function set_expected_server_time(unix_time) {
    var local_dt = new Date();
    server_time_diff = unix_time - Math.floor(local_dt.getTime() / 1000);
    console.log('server_time_diff=', server_time_diff);
  }

  function expected_server_time(local_dt) {
    var cur_time = Math.floor(local_dt.getTime() / 1000) + server_time_diff;
    return cur_time;
  }

  function time_elapsed_string(unix_time) {
    var dt = new Date(unix_time * 1000)
    var cur_dt = new Date();
    var diff_year = cur_dt.getFullYear() - dt.getFullYear();
    var diff_month = cur_dt.getMonth() - dt.getMonth();
    if(diff_month < 0) {
      diff_month += 12;
      diff_year--;
    }
    if(diff_month > 0) {
      var diff_date = cur_dt.getDate() - dt.getDate();
      if(diff_date < 0) {
        diff_month--;
      }
    }
    if(diff_year != 0 || diff_month != 0) {
      var ret = '';
      if(diff_year > 0) {
        ret += diff_year + (diff_year > 1 ? ' years ' : ' year ');
      }
      if(diff_month > 0) {
        ret += diff_month + (diff_month > 1 ? ' months ' : ' month ');
      }
      ret += 'ago';
      return ret;
    } else {
      var cur_time = expected_server_time(cur_dt);
      var diff = cur_time - unix_time;
      if(diff < 0) {
        diff = 0;
      }
      for(var i in time_elapsed_list) {
        var t = time_elapsed_list[i];
        var d = diff / t.val;
        if(d >= 1) {
          d = Math.round(d);
          return d + ' ' + t.key + (d > 1 ? 's' : '') + ' ago';
          break;
        }
      }
      return 'just now';
    }
  }

  function txlogs_item(item) {
    var data = item;
    var imgsrc = DotMatrix.getImage(cipher.buf2hex(cipher.murmurhash((new TextEncoder).encode(data.address))), 36, 1);
    var send = (data.txtype == 0);
    var confirm = (_height >= data.height);
    var confirm_count = _height - data.height + 1;
    var extra = confirm ? '<div class="extra content confirmed">' : '<div class="extra content unconfirmed">';
    var confirm_msg = confirm ? '<i class="paw icon"></i> Confirmed (<span class="tx-confirm" data-height="' + data.height + '">' + confirm_count + '</span>)' : '<i class="red dont icon"></i> Unconfirmed';
    var amount = conv_coin(data.value);
    var local_time = confirm ? conv_time(data.time) : '';
    var trans_time = data.trans_time ? conv_time(data.trans_time) : local_time;
    var elapsed_time = data.trans_time ? data.trans_time : data.time;
    var h = '<div class="ui centered card metal txlog" data-sequence="' + item.sequence + '">'
      + '<div class="content">'
      + '<img class="right floated mini ui image" src="' + imgsrc + '">'
      + '<div class="header">'
      + '<i class="' + (send ? 'counterclockwise rotated sign-out icon send' : 'clockwise rotated sign-in icon receive') + '"></i> ' + (send ? 'SEND' : 'RECEIVE')
      + '</div>'
      + '<div class="meta">'
      + trans_time + '<br>'
      + '<span class="tx-elapsed" data-time="' + elapsed_time + '">' + time_elapsed_string(elapsed_time) + '</span>'
      + '</div>'
      + '<div class="description">'
      + '<span class="right floated">' + amount + ' ZNY</span>'
      + '<div>' + data.address + '</div>'
      + '<div class="meta txid">'
      + data.txid
      + '</div>'
      + '</div>'
      + '</div>'
      + extra
      + '<span class="right floated">'
      + local_time
      + '</span>'
      + '<span>'
      + confirm_msg
      + '</span>'
      + '</div>'
      + '</div>';
    return h;
  }

  var itemcache = [];
  var first_sequence = null;
  var last_sequence = null;
  var cachelimit = 200;
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
      get_txlogs(last_sequence, true);
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

  var start = false;
  var abort = false;
  var elapsed_update_worker_tval = null;
  function elapsed_update_worker() {
    if(abort) {
      return;
    }
    $('.tx-elapsed').each(function() {
      $(this).text(time_elapsed_string($(this).data('time')));
    });
    elapsed_update_worker_tval = setTimeout(function() {
      elapsed_update_worker();
    }, 10000);
  }

  function show_unconfs() {
    var unconf_list = [];
    var spent_addrs = {};
    var change_addrs = {};
    for(var addr in _unconfs.addrs) {
      var val = _unconfs.addrs[addr];
      if(val.spents) {
        for(var i in val.spents) {
          var spent = val.spents[i];
          spent_addrs[addr] = 1;
          break;
        }
      }
      if(val.txouts) {
        if(val.change != 1) {
          for(var i in val.txouts) {
            var txout = val.txouts[i];
            var item = {txtype: 1, address: addr, txid: txout.txid, value: txout.value,
              change: val.change, index: val.index, xpub_idx: val.xpub_idx, trans_time: txout.trans_time};
            unconf_list.push(item);
          }
        } else {
          change_addrs[addr] = 1;
        }
      }
    }
    for(var txid in _unconfs.txs) {
      var tx = _unconfs.txs[txid];
      var find = false;
      var find_else = 0;
      var s0 = UINT64(0);
      var s1 = UINT64(0);
      var fs0 = UINT64(0);
      var fs1 = UINT64(0);
      var out_addr = null;
      for(var txa in tx.data) {
        var v = tx.data[txa]
        for(var i in v) {
          if(i == 0) {
            if(spent_addrs[txa]) {
              find = true;
              s0.add(UINT64(String(v[i])));
            } else {
              find_else++;
            }
            fs0.add(UINT64(String(v[i])));
          } else if(i == 1) {
            if(change_addrs[txa]) {
              s1.add(UINT64(String(v[i])));
            } else if(out_addr == null) {
              out_addr = txa;
            }
            fs1.add(UINT64(String(v[i])));
          }
        }
      }
      if(find && out_addr) {
        var val = s0.subtract(s1);
        if(find_else == 0) {
          var fee = fs0.subtract(fs1);
          val.subtract(fee);
        }
        var item = {txtype: 0, address: out_addr, txid: txid, value: val};
        if(tx.trans_time) {
          item['trans_time'] = tx.trans_time;
        }
        unconf_list.push(item);
      }
    }

    unconf_list.sort(function(a, b) {
      if(a.trans_time != b.trans_time) {
        return b.trans_time - a.trans_time;
      }
      if(a.txid != b.txid) {
        return b.txid > a.txid ? 1 : -1;
      }
      if(a.txtype != b.txtype) {
        return b.txtype - a.txtype;
      }
      if(a.change != b.change) {
        return b.change - a.change;
      }
      if(a.index != b.index) {
        return b.index - a.index;
      }
      if(a.xpub_idx != b.xpub_idx) {
        return b.xpub_idx - a.xpub_idx;
      }
    });

    console.log(JSON.stringify(unconf_list));
    $('#tradeunconfs').empty();
    for(var i in unconf_list) {
      var h = txlogs_item(unconf_list[i]);
      $(h).appendTo('#tradeunconfs');
    }
  }

  var TradeLogs = {};

  TradeLogs.start = function() {
    cipher = cipher || pastel.cipher;
    coin = coin || coinlibs.coin;
    network = network || coin.networks[pastel.config.network];
    crypto = crypto || window.crypto || window.msCrypto;
    if(!$('#tradelogs').length) {
      return;
    }

    start = true;
    abort = false;
    console.log('start');
    eof = false;
    first_sequence = null;
    last_sequence = null;
    itemcache = [];
    pastel.send({cmd: "time"});
    show_unconfs();
    loadcache();
    window.addEventListener('scroll', scroll_listener);
    check_scroll();
    clearTimeout(elapsed_update_worker_tval);
    elapsed_update_worker();
  }

  TradeLogs.stop = function() {
    console.log('stop');
    start = false;
    abort = true;
    window.removeEventListener('scroll', scroll_listener);
    clearTimeout(elapsed_update_worker_tval);
  }

  var new_txlogs_worker_tval = null;
  TradeLogs.get_txlogs_cb = function(data) {
    if(!start) {
      return;
    }
    console.log(JSON.stringify(data));
    var txlogs = data.txlogs;
    var rev_flag = data.rev;
    if(txlogs.length <= 0) {
      eof = true;
    } else {
      if(rev_flag) {
        var first = txlogs[0];
        if(first) {
          var max = first.sequence;
          var min = first.sequence;
          for(var i = 1; i < txlogs.length; i++) {
            var t = txlogs[i];
            if(max < t.sequence) {
              max = t.sequence;
            } else if(min > t.sequence) {
              min = t.sequence;
            }
          }
          if(first_sequence == null) {
            first_sequence = max;
          } else {
            first_sequence = first_sequence > max ? first_sequence : max;
          }
          if(last_sequence == null) {
            last_sequence = min;
          } else {
            last_sequence = last_sequence < min ? last_sequence : min;
          }
        }
        itemcache = itemcache.concat(txlogs);
        check_scroll();
      } else {
        var first = txlogs[0];
        if(first) {
          var max = first.sequence;
          var min = first.sequence;
          for(var i = 1; i < txlogs.length; i++) {
            var t = txlogs[i];
            if(max < t.sequence) {
              max = t.sequence;
            } else if(min > t.sequence) {
              min = t.sequence;
            }
          }

          if(first_sequence >= min) {
            var remove_list = [];
            $('.txlog').each(function() {
              var seq = $(this).data('sequence');
              if(seq >= min) {
                remove_list.push($(this));
              }
            });
            function remove_worker() {
              var elm = remove_list.shift();
              if(elm) {
                elm.animate({opacity: 0}, 600, function() {
                  elm.animate({height: 'hide'}, 600, function() {
                    elm.remove();
                    setTimeout(remove_worker, 10);
                  });
                });
              }
            }
            remove_worker();
          }

          function worker() {
            var item = txlogs.shift();
            if(item) {
              var h = txlogs_item(item);
              $(h).hide().prependTo('#tradelogs').css({opacity: 0}).stop(true, true).animate({height: 'show'}, 600).animate({opacity: 1}, 600);
              new_txlogs_worker_tval = setTimeout(worker, 1000);
            } else {
              first_sequence = max;
              var tid = document.getElementById('tradelogs');
              var rect = tid.getBoundingClientRect();
              var offset_top = rect.top - 50 + (window.pageYOffset || document.documentElement.scrollTop);
              scrollPos(offset_top, 800);
              get_txlogs(first_sequence, false);
            }
          }
          worker();
        }
      }
    }
    loadcache_loading = false;
  }

  TradeLogs.update_height = function(height) {
    _height = height;
    if(start) {
      $('.tx-confirm').each(function() {
        $(this).text(_height - $(this).data('height') + 1);
      });
      $('.tx-elapsed').each(function() {
        $(this).text(time_elapsed_string($(this).data('time')));
      });
      get_txlogs(first_sequence, false);
    }
  }

  TradeLogs.rollbacked = function(sequence) {
    clearTimeout(new_txlogs_worker_tval);
    get_txlogs(sequence, false);
  }

  var _unconfs = {};
  TradeLogs.unconfs = function(data) {
    _unconfs = data;
    if(start) {
      show_unconfs();
    }
  }

  TradeLogs.server_time = function(unix_time) {
    set_expected_server_time(unix_time);
  }
  return TradeLogs;
})();
