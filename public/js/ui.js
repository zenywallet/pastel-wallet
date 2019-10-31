function ready(cb) {
  if(document.readyState != 'loading') {
    cb();
  } else if(document.addEventListener) {
    document.addEventListener('DOMContentLoaded', cb);
  } else {
    document.attachEvent('onreadystatechange', function() {
      if(document.readyState == 'complete') {
        cb();
      }
    });
  }
}

var bodyWidth, bodyHeight;
function onClientSizeChanged(cb) {
  bodyWidth = document.body.clientWidth;
  bodyHeight = document.body.clientHeight;
  window.onresize = function() {
    var newBodyWidth = document.body.clientWidth;
    var newBodyHeight = document.body.clientHeight;
    if(bodyWidth != newBodyWidth || bodyHeight != newBodyHeight) {
      cb();
      bodyWidth = newBodyWidth;
      bodyHeight = newBodyHeight;
    }
  }
}

var target_scroll_pos = null;
function scrollPos(pos, duration, done) {
  target_scroll_pos = pos;
  var sy = window.scrollY;
  if(pos == sy) {
    if(done) {
      done();
    }
    return;
  }
  var rad = 0;
  var diff = pos - sy;
  var hpi = Math.PI / 2;
  var stime = performance.now();
  function step(timestamp) {
    if(target_scroll_pos != pos) {
      return;
    }
    var elaps = timestamp - stime;
    rad = hpi * elaps / duration;
    if(rad >= hpi) {
      window.scrollTo(0, pos);
      if(done) {
        done();
      }
      return;
    }
    var curpos = Math.round(sy + diff * Math.sin(rad));
    window.scrollTo(0, curpos);
    window.requestAnimationFrame(step);

  }
  window.requestAnimationFrame(step);
}

var lastSection = null;
function goSection(selector, cb) {
  var section = document.querySelector(selector);
  var rect = section.getBoundingClientRect();
  var offset_top = rect.top + (window.pageYOffset || document.documentElement.scrollTop);
  scrollPos(offset_top, 800, cb);
  lastSection = selector;
}

function reloadSection(cb) {
  if(lastSection) {
    goSection(lastSection, cb);
  }
}

var target_page_scroll = null;
var page_scroll_done = function () {};
var scroll_tval = null;
window.onscroll = function() {
  if(scroll_tval != null) {
    clearTimeout(scroll_tval);
    scroll_tval = null;
  }
  var sections = document.getElementsByClassName('section');
  var tradelogs_section = document.getElementById('section4');
  if(sections.length <= 1 && !tradelogs_section) {
    return;
  }
  var difflist = {};
  Array.prototype.forEach.call(sections, function(section) {
    var rect = section.getBoundingClientRect();
    var section_id = section.getAttribute('id');
    difflist['#' + section_id] = Math.abs(rect.top);
  });
  if(tradelogs_section) {
    var rect = tradelogs_section.getBoundingClientRect();
    if(rect.top <= 0) {
      return;
    }
    difflist['#section4'] = Math.abs(rect.top);
  }

  var min_val = 0;
  var min_item = null;
  for(var key in difflist) {
    if(min_item == null || difflist[key] < min_val || (key == target_page_scroll && difflist[key] <= min_val)) {
      min_val = difflist[key];
      min_item = key;
    }
  }
  if(min_item) {
    lastSection = min_item;
  }
  scroll_tval = setTimeout(function() {
    if(lastSection) {
      if(lastSection == target_page_scroll) {
        goSection(lastSection, page_scroll_done);
      } else {
        goSection(lastSection);
      }
    }
  }, 1200);
}

function showQrReader() {
  var qr = new QCodeDecoder();
  if(qr.isCanvasSupported() && qr.hasGetUserMedia()) {
    var video = document.querySelector('#qrvideo');
    function resultHandler(err, result) {
      if(err) {
        qr.stop();
        return;
      }
      console.log(result);
    }
    qr.decodeFromCamera(video, resultHandler);
  }
}

function calc_qrcode_size() {
  var w = $(window).width() - 120;
  var h = $(window).height() - 440;
  var s = (w < h) ? w : h;
  s = s > 200 ? s : 200;
  return s;
}

var bip21_uri;
var draw_qrcode_animate = false;
var draw_qrcode_prev_size = 0;
function draw_qrcode(check_resize) {
  var s = calc_qrcode_size();
  if(check_resize && draw_qrcode_prev_size == s) {
    if(bip21_uri) {
      $('#recv-qrcode').attr('title', bip21_uri);
    }
    return;
  }
  draw_qrcode_prev_size = s;

  if(bip21_uri) {
    function draw() {
      $('#recv-qrcode').empty();
      $('#recv-qrcode').attr('title', '');
      $('#recv-qrcode').qrcode({
        render: 'canvas',
        ecLevel: 'Q',
        radius: 0.39,
        text: bip21_uri,
        size: s,
        mode: 0,
        label: '',
        fontname: 'sans',
        fontcolor: '#393939'
      });
      if($('#recv-qrcode canvas').length) {
        $('#recv-qrcode').attr('title', bip21_uri);
        if(draw_qrcode_animate) {
          $('#recv-qrcode').stop(true, false).animate({opacity: 1}, 200);
        }
      } else {
        console.log('qrcode error');
        $('#recv-qrcode').append('<div style="text-align:center;display:inline-block;">unable to display qrcode</div>');
      }
    }
    if(draw_qrcode_animate && $('#recv-qrcode canvas').length) {
      $('#recv-qrcode').stop(true, false).animate({opacity: 0}, 200, function() {
        draw();
      });
    } else {
      draw();
    }
  }
}

var resize_qrcode_tval = null;
function resize_qrcode() {
  var canvas = $('#recv-qrcode canvas');
  if(!canvas.length) {
    return;
  }
  var s = calc_qrcode_size();
  canvas.css({width: s, height: s});
  if(!resize_qrcode_tval) {
    resize_qrcode_tval = setTimeout(function() {
      draw_qrcode(s);
      resize_qrcode_tval = null;
    }, 200);
  }
}

function recvform_change() {
  var uri = 'bitzeny:' + $('#recvaddr-form input[name="address"]').val();
  var amount_elm = $('#recvaddr-form input[name="amount"]');
  var amount = amount_elm.val();
  var label = $('#recvaddr-form input[name="label"]').val();
  var message = $('#recvaddr-form textarea[name="message"]').val();
  var firstflag = true;
  if(amount) {
    if(amount.indexOf('.') == amount.length - 1 && amount[amount.length - 1] == '.') {
      amount = amount.slice(0, -1);
    }
    var desep_amount = amount.replace(/[',]/g, '');
    if(amount_pasted) {
      amount = desep_amount;
      amount_elm.val(amount);
    }
    amount_pasted = false;
    if(/^\d+\.?\d{0,8}$/.test(amount)) {
      amount_elm.closest('.field').removeClass('error');
    } else {
      amount_elm.closest('.field').addClass('error');
    }
    amount = desep_amount;
    if(amount) {
      uri += (firstflag ? '?' : '&') + 'amount=' + Encoding.convert(amount, 'SJIS', 'UNICODE');
      firstflag = false;
    }
  }
  if(label) {
    uri += (firstflag ? '?' : '&') + 'label=' + Encoding.convert(label, 'SJIS', 'UNICODE');
    firstflag = false;
  }
  if(message) {
    uri += (firstflag ? '?' : '&') + 'message=' + Encoding.convert(message, 'SJIS', 'UNICODE');
    firstflag = false;
  }
  bip21_uri = encodeURI(uri);
  draw_qrcode();
}

var amount_pasted = false;
var recv_moval_init_flag = false;
function initRecvModal() {
  $('#recvaddr-form form input[name="amount"]').on('paste', function() {
    amount_pasted = true;
  });

  $('#recvaddr-form input[name="address"]').change(function() {
    console.log('change');
    recvform_change();
  });
  $('#recvaddr-form input[name="amount"],#recvaddr-form input[name="label"],#recvaddr-form textarea[name="message"]').keyup(function() {
    console.log('keyup');
    recvform_change();
  });

  $('#recv-modal .close-arc').click(function() {
    hideRecvModal();
  });
}

var recvModalViewState = false;
function showRecvModal() {
  recvModalViewState = true;
  $('html').css('background-color', '#fff');
  $('#recv-modal').fadeIn(600);
  window.addEventListener("resize", resize_qrcode);
  draw_qrcode(true);
}

function hideRecvModal() {
  recvModalViewState = false;
  $('#recv-qrcode').attr('title', '');
  window.removeEventListener("resize", resize_qrcode);
  $('#recv-modal').fadeOut(600);
  $('#recvaddr-form .menu').empty();
  $('html').css('background-color', '#444');
  $('#btn-recv-qrcode').blur();
}

var save_view_state = {recv_modal_menu: null};
function reloadViewSafeStart() {
  if(recvModalViewState) {
    save_view_state.recv_modal_menu = $('#recvaddr-form .menu').html();
    $('#recvaddr-form .menu').empty();
  }
}

function reloadViewSafeEnd() {
  if(recvModalViewState && save_view_state.recv_modal_menu) {
    $('#recvaddr-form .menu').html(save_view_state.recv_modal_menu);
    save_view_state.recv_modal_menu = null;
  }
}

var modal_recv_addrs = [];
function showRecvAddress() {
  if(!pastel.wallet || !pastel.utxoballs) {
    return;
  }
  var wallet = pastel.wallet;
  modal_recv_addrs = wallet.getUnusedAddressList(5);
  $('#receive-address .new').hide();
  $('#receive-address .new').empty();
  for(var i in modal_recv_addrs) {
    var addr = modal_recv_addrs[i];
    $('#receive-address .new').append('<div class="circular ui icon mini button ball" data-idx="' + i + '"><img src="' + Ball.get(addr, 28) + '"></div>');
  }

  function ball_selector_event(sel) {
    $(sel).off('click').click(function() {
      var idx = $(this).data('idx');
      if(modal_recv_addrs[idx].length > 0) {
        $('#receive-address .ball').each(function() {
          $(this).removeClass('active');
        });
        $(this).addClass('active');
        $('#receive-address .address').stop(true, true).fadeOut(200, function() {
          $(this).text(modal_recv_addrs[idx]).fadeIn(400);
          if(idx != 5 && modal_recv_addrs[5].length > 0) {
            modal_recv_addrs[5] = "";
            $('#receive-address .used').stop().animate({opacity: 0}, 400).animate({width: 0}, 100);
          }
        });
      }
    });
  }

  var utxoballs_click = function(addr) {
    console.log('address=' + addr);
    if(modal_recv_addrs[5].length > 0) {
      modal_recv_addrs[5] = addr;
      $('#receive-address .used .ball').animate({opacity: 0}, 200, function() {
        $('#receive-address .used').animate({width: 0}, 100, function() {
          $('#receive-address .used .ball img').replaceWith('<img src="' + Ball.get(addr, 28) + '">');
          $('#receive-address .used').animate({width: 42}, 100, function() {
            $('#receive-address .ball').animate({opacity: 1}, 400);
            if($('#receive-address .used .ball').hasClass('active')) {
              $('#receive-address .address').stop(true, true).fadeOut(200, function() {
                if(modal_recv_addrs[5].length > 0) {
                  $(this).text(modal_recv_addrs[5]).fadeIn(400);
                }
              });
            }
          });
        });
      });
    } else {
      modal_recv_addrs[5] = addr;
      $('#receive-address .used').stop().css("opacity", 0).animate({width: 42}, 100, function() {
        $('#receive-address .used .ball').replaceWith('<div class="circular ui icon mini button ball" data-idx="5"><img src="' + Ball.get(addr, 28) + '"></div>');
        $('#receive-address .used').stop().css("visibility", "visible").animate({opacity: 1}, 400);
        ball_selector_event('#receive-address .used .ball');
      });
    }
  }

  ball_selector_event('#receive-address .new .ball');
  $('#receive-address .used').css("visibility", "hidden");
  $('#receive-address .used').css("width", 0);
  $('#receive-address .used .ball').removeClass('active')
  $('#receive-address').show();
  $('#receive-address .new').fadeIn(800, function() {
    $('#receive-address .new .ball:first').addClass('active');
    setTimeout(function() {
      $('#receive-address .address').hide().text(modal_recv_addrs[0]).fadeIn(400);
      modal_recv_addrs.push("");
      pastel.utxoballs.click(utxoballs_click);
    }, 400);
  });

  if(!recv_moval_init_flag) {
    initRecvModal();
    recv_moval_init_flag = true;
    var btn_qrcode = document.getElementById('btn-recv-qrcode');
    btn_qrcode.addEventListener('click', function() {
      $('#recvaddr-form .menu').empty();
      var item_addrs = [];
      if(modal_recv_addrs[5] && modal_recv_addrs[5].length > 0) {
        item_addrs.push({addr: modal_recv_addrs[5], idx: 5});
      }
      for(var i = 0; i < 5; i++) {
        item_addrs.push({addr: modal_recv_addrs[i], idx: i});
      }
      for(var i in item_addrs) {
        var item_addr = item_addrs[i];
        $('#recvaddr-form .menu').append('<div class="item" data-value="' + item_addr.addr + '" data-idx="' + item_addr.idx
          + '"><img class="ui mini avatar image" src="' + Ball.get(item_addr.addr, 28) + '">' + item_addr.addr + '</div>');
      }

      var idx = $('#receive-address .ball.active').data('idx') || 0;
      var sel_addr = modal_recv_addrs[idx];
      var sel_item = -1;
      for(var i in item_addrs) {
        if(item_addrs[i].addr == sel_addr) {
          sel_item = i;
          break;
        }
      }
      $('#recv-modal .text').html('<img class="ui mini avatar image" src="' + Ball.get(sel_addr, 28) + '">' + sel_addr + '</div>');
      $('#recvaddr-form input[name="address"]').val(sel_addr);
      $('#recvaddr-form .ui.dropdown').dropdown('set selected', sel_addr);
      $('#recvaddr-form .ui.dropdown').dropdown({
        onChange: function(val) {
          var idx = null;
          $('#recvaddr-form .item').each(function() {
            if(val == $(this).data('value')) {
              idx = $(this).data('idx');
              return false;
            }
          });
          if(idx != null) {
            $('#receive-address .ball').each(function() {
              var bidx = $(this).data('idx');
              if(bidx == idx) {
                $(this).addClass('active');
              } else {
                $(this).removeClass('active');
              }
            });
          }
          $('#receive-address .address').text(val);
        }
      });
      if(sel_item >= 0) {
        $('#recvaddr-form .menu .item:eq(' + sel_item + ')').addClass('active selected');
      }
      recvform_change();
      showRecvModal();
    });
  }
}


var Settings = (function() {
  var Module = {};
  var confirm_popup_tval;

  function reset_click() {
    var self = $(this);
    var check = $('#settings .ui.checkbox').checkbox('is checked');
    if(check) {
      $('#btn-reset').blur();
      $('.ui.basic.modal').modal("setting", {
        closable: false,
        onApprove: function() {
          location.reload();
        },
        onDeny: function() {}
      }).modal('show');
    } else {
      self.blur();
      var confirm = $('#settings input[name="confirm"]');
      clearTimeout(confirm_popup_tval);
      confirm.popup({
        title: 'Confirmation',
        content: 'Please read and check here before resetting your wallet.',
        on: 'manual',
        variation: 'inverted',
        position: 'bottom left',
        distanceAway: 6,
        exclusive: true
      }).popup('show');
      confirm_popup_tval = setTimeout(function() {
        confirm.popup('hide');
      }, 5000);
    }
  }

  Module.init = function() {
    $('#settings .ui.checkbox').checkbox('set unchecked');

    $('#settings .ui.checkbox').checkbox({
      onChange: function() {
        var check = $('#settings .ui.checkbox').checkbox('is checked');
        if(check) {
          var confirm = $('#settings input[name="confirm"]');
          clearTimeout(confirm_popup_tval);
          confirm.popup('hide');
        }
      }
    });

    var btn_reset = document.getElementById('btn-reset');
    btn_reset.removeEventListener('click', reset_click);
    btn_reset.addEventListener('click', reset_click);
  }

  return Module;
})();

var registerEventList = [];
ready(function() {
  var elms = document.querySelectorAll('a');
  Array.prototype.forEach.call(elms, function(elm) {
    var href = elm.getAttribute("href");
    if(href && href.startsWith('#')) {
      var cb = function(e) {
        e.preventDefault();
        var href = this.getAttribute('href');
        goSection(href);
      }
      registerEventList.push({elm: elm, type: 'click', cb: cb});
      elm.addEventListener('click', cb);
    }
  });

  onClientSizeChanged(function() {
    reloadSection();
  });
});
