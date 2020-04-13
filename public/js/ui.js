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

function adjustHeight() {
  var vh = window.innerHeight * 0.01;
  document.documentElement.style.setProperty('--vh', `${vh}px`);
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
    adjustHeight();
  }
  adjustHeight();
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
var pause_user_scroll = false;
var pause_event_list = {};
function goSection(selector, cb) {
  var section = document.querySelector(selector);
  if(section) {
    pause_user_scroll = true;
    if(!pause_event_list[selector]) {
      pause_event_list[selector] = 1;
      $(selector).on('touchstart touchmove', function(e) {
        if(pause_user_scroll) {
          e.preventDefault();
        }
      });
    }
    var rect = section.getBoundingClientRect();
    var offset_top = rect.top + (window.pageYOffset || document.documentElement.scrollTop);
    scrollPos(offset_top, 800, function() {
      pause_user_scroll = false;
      if(cb) {
        cb();
      }
    });
    lastSection = selector;
  }
}

function reloadSection(cb) {
  if(lastSection) {
    if(lastSection == '#section4') {
      var tradelogs_section = document.getElementById('section4');
      var rect = tradelogs_section.getBoundingClientRect();
      if(rect.top < 0) {
        return;
      }
    }
    goSection(lastSection, cb);
  }
}

var target_page_scroll = null;
var page_scroll_done = function () {};
var scroll_tval = null;
var section_auto_scroll = true;
var onscroll_func = function() {
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
  if(tradelogs_section && !(tradelogs_section.style && tradelogs_section.style.display == 'none')) {
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
    if(lastSection && section_auto_scroll) {
      if(lastSection == target_page_scroll) {
        goSection(lastSection, page_scroll_done);
      } else {
        goSection(lastSection);
      }
    }
  }, 1200);
}

function setAutoScroll(flag) {
  section_auto_scroll = flag;
  if(section_auto_scroll) {
    onscroll_func();
  }
}
window.onscroll = onscroll_func;

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
      $('#recv-qrcode').attr('data-content', bip21_uri);
    }
    return;
  }
  draw_qrcode_prev_size = s;

  if(bip21_uri) {
    function draw() {
      $('#recv-qrcode').empty();
      $('#recv-qrcode').attr('title', '');
      $('#recv-qrcode').attr('data-content', '');
      $('#recv-qrcode').popup({
        hoverable: true,
        position: 'bottom center',
        variation: 'mini inverted'
      });
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
        $('#recv-qrcode').attr('data-content', bip21_uri);
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
  } else {
    amount_elm.closest('.field').removeClass('error');
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
    setAutoScroll(true);
  });
  $('#recv-modal .close-arc').keydown(function(evt) {
    if(evt.which == 13 || evt.keyCode == 13) {
      $(this).click();
    }
  });
}

var recvModalViewState = false;
function showRecvModal() {
  disable_caret_browsing($('#section3'));
  recvModalViewState = true;
  $('html').css('background-color', '#fff');
  $('#recv-modal').fadeIn(600);
  window.addEventListener("resize", resize_qrcode);
  draw_qrcode(true);
}

function hideRecvModal() {
  recvModalViewState = false;
  $('#recv-qrcode').attr('data-content', '');
  window.removeEventListener("resize", resize_qrcode);
  $('#recv-modal').fadeOut(600);
  $('#recvaddr-form .menu').empty();
  $('html').css('background-color', '#444');
  $('#btn-recv-qrcode').blur();
  enable_caret_browsing($('#section3'));
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
function showRecvAddress(cb) {
  var wallet = pastel.wallet;
  wallet.getUnusedAddressList(5, function(addrs) {
    modal_recv_addrs = addrs;

    $('#receive-address .new').hide();
    for(var i in modal_recv_addrs) {
      var addr = modal_recv_addrs[i];
      $('#receive-address .new .ball').eq(i).replaceWith('<div class="circular ui icon mini button ball tabindex" data-idx="' + i + '" tabindex="0"><img src="' + Ball.getImage(addr, 28) + '"></div>');
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
            if(idx != 5 && modal_recv_addrs[5] && modal_recv_addrs[5].length > 0) {
              modal_recv_addrs[5] = "";
              $('#receive-address .used').stop().animate({opacity: 0}, 400).animate({width: 0, 'margin-right': 0}, 100, function() {
                $(this).css("visibility", "hidden");
              });
            }
          });
        }
      });
      $(sel).off('keydown').on('keydown', function(evt) {
        if(evt.which == 13 || evt.keyCode == 13) {
          $(this).click();
        }
      });
    }

    var utxoballs_click = function(addr) {
      console.log('address=' + addr);
      if(modal_recv_addrs[5] && modal_recv_addrs[5].length > 0) {
        modal_recv_addrs[5] = addr;
        $('#receive-address .used .ball').stop(true, true).animate({opacity: 0}, 200, function() {
          $('#receive-address .used').animate({width: 0, 'margin-right': 0}, 100, function() {
            $('#receive-address .used .ball img').attr('src', Ball.getImage(addr, 28));
            $('#receive-address .used').animate({width: 42, 'margin-right': 7}, 100, function() {
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
        $('#receive-address .used').stop().css("opacity", 0).animate({width: 42, 'margin-right': 7}, 100, function() {
          $('#receive-address .used .ball').replaceWith('<div class="circular ui icon mini button ball tabindex" data-idx="5" tabindex="0"><img src="' + Ball.getImage(addr, 28) + '"></div>');
          $('#receive-address .used').stop().css("visibility", "visible").animate({opacity: 1}, 400);
          ball_selector_event('#receive-address .used .ball');
        });
      }
    }

    ball_selector_event('#receive-address .new .ball');
    $('#receive-address .used').css("visibility", "hidden");
    $('#receive-address .used').css({width: 0, 'margin-right': 0});
    $('#receive-address .used .ball').removeClass('active');
    $('#receive-address .address').css("visibility", "hidden").css("opacity", 0).text(modal_recv_addrs[0]);
    if(pastel.utxoballs) {
      pastel.utxoballs.click(utxoballs_click);
    }

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
            + '"><img class="ui mini avatar image" src="' + Ball.getImage(item_addr.addr, 28) + '">' + item_addr.addr + '</div>');
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
        $('#recv-modal .text').html('<img class="ui mini avatar image" src="' + Ball.getImage(sel_addr, 28) + '">' + sel_addr + '</div>');
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
        setAutoScroll(false);
        showRecvModal();
      });

      var btn_copy = document.getElementById('btn-recv-copy');
      var copied_popup_tval;
      btn_copy.addEventListener('click', function() {
        var address_elm = document.getElementById('address-text');
        if(address_elm) {
          var ret = false;
          var copydata = '';
          var textarea = document.getElementById('clipboard');
          if(textarea) {
            copydata = address_elm.textContent;
            textarea.style.visibility ="visible";
            textarea.readOnly = false;
            textarea.textContent = copydata;
            textarea.select();
            ret = document.execCommand('copy');
            textarea.textContent = '';
            textarea.readOnly = true;
            textarea.style.visibility ="hidden";
          }
          if(!ret && window.getSelection) {
            var getsel = window.getSelection();
            var range = document.createRange();
            range.selectNode(address_elm);
            getsel.removeAllRanges();
            getsel.addRange(range);
            copydata = getsel.toString();
            ret = document.execCommand('copy');
            getsel.removeAllRanges();
          }
          if(ret) {
            var copied = $('#address-text');
            clearTimeout(copied_popup_tval);
            copied.popup({
              title: __t('Copied to clipboard'),
              content: copydata,
              on: 'manual',
              variation: 'inverted',
              position: 'bottom center',
              distanceAway: 0,
              exclusive: true
            }).popup('show');
            copied_popup_tval = setTimeout(function() {
              copied.popup('hide');
            }, 2000);
          }
        }
        btn_copy.blur();
      });
    }
    cb();
  });
}

function showRecvAddressAfterEffect() {
  $('#receive-address .new').fadeIn(400, function() {
    $('#receive-address .new .ball:first').addClass('active');
    $('#receive-address .address').css("visibility", "visible").animate({opacity: 1}, 400);
  });
}

function escape_html(s) {
  return s.replace(/[&'`"<>]/g, function(match) {
    return {
      '&': '&amp;',
      "'": '&#39;',
      "`": '&#96;',
      '"': '&quot;',
      '<': '&lt;',
      '>': '&gt;',
    }[match]
  });
}

function bip21reader(uri) {
  var d_uri = decodeURI(uri);
  var s = d_uri.split(/[?&]/);
  if(s.length <= 0) {
    return null;
  }
  var a = s[0].split(':');
  var result = {}
  if(a.length <= 2) {
    if(a.length == 2) {
      if(a[0].toLowerCase() != 'bitzeny') {
        result.unknown = escape_html(d_uri);
        return result;
      }
    }
    var addr = a[a.length - 1];
    if(addr.length > 0 && /^[a-z0-9]+$/i.test(addr)) {
      var coin = pastel.coin;
      if(coin) {
        try {
          coin.address.toOutputScript(addr, coin.networks[pastel.config.network]);
          result.address = addr;
        } catch(e) {
          result.unknown = escape_html(d_uri);
          return result;
        }
      } else {
        result.address = addr;
      }
      for(var i = 1; i < s.length; i++) {
        var p = s[i].split('=');
        if(p.length == 2) {
          result[escape_html(p[0])] = escape_html(Encoding.convert(p[1], 'UNICODE', 'SJIS'));
        }
      }
      return result;
    }
  }
  result.unknown = escape_html(d_uri);
  return result;
}

function crlftab_to_html(s) {
  return s.replace(/\r\n/g, '<br>').replace(/\n/g, '<br>').replace(/\t/g, '&nbsp;&nbsp;&nbsp;&nbsp;');
}

var camDevice = (function() {
  var cam_ids = [];
  var sel_cam = null;
  var sel_cam_index = 0;
  if(navigator.mediaDevices) {
    navigator.mediaDevices.enumerateDevices().then(function(devices) {
      devices.forEach(function(device) {
        if(device.kind == 'videoinput') {
          cam_ids.push(device);
        }
      });
    });
  }
  return {
    set_current: function(deviceId) {
      var new_cam_index = 0;
      for(var i in cam_ids) {
        if(deviceId == cam_ids[i].deviceId) {
          new_cam_index = i;
          break;
        }
      }
      sel_cam_index = new_cam_index;
      sel_cam = cam_ids[sel_cam_index].deviceId;
    },
    next: function() {
      if(cam_ids.length > 0) {
        if(sel_cam == null) {
          sel_cam_index = cam_ids.length - 1;
          sel_cam = cam_ids[sel_cam_index].deviceId;
        } else {
          sel_cam_index++;
          if(sel_cam_index >= cam_ids.length) {
            sel_cam_index = 0;
          }
          sel_cam = cam_ids[sel_cam_index].deviceId;
        }
      }
      return sel_cam;
    },
    count: function() {
      return cam_ids.length;
    }
  };
})();

var qrReader = (function() {
  var video = null;
  var canvas, ctx, seg;
  var cipher = {};
  var abort = false;
  var showing = false;

  function drawPoly(poly, lineWidth, color) {
    ctx.beginPath();
    ctx.moveTo(poly[0], poly[1]);
    for(var item = 2; item < poly.length - 1; item += 2) {
      ctx.lineTo(poly[item], poly[item + 1]);
    }
    ctx.lineWidth = lineWidth;
    ctx.strokeStyle = color;
    ctx.closePath();
    ctx.stroke();
  }

  function checkRange(x, y, x1, y1, x2, y2) {
    return (x > x1 && x < x2 && y > y1 && y < y2);
  }

  var cb_done = function() {}

  function qr_stop() {
    camera_scanning(false);
    video.pause();
    if(video.srcObject) {
      video.srcObject.getTracks().forEach(function(track) {
        track.stop();
      });
    }
    video.removeAttribute('src');
    video.load();
  }

  function shutter(data) {
    var active = true;
    var count = 0;
    function _shutter() {
      setTimeout(function() {
        if(active) {
          $('.qrcamera-shutter').addClass('active');
          active = false;
        } else {
          $('.qrcamera-shutter').removeClass('active');
          active = true;
          count++;
        }
        if(count < 3) {
          _shutter();
        } else {
          scan_done = true;
          qr_stop();
          showing = false;
          cb_done(0, data);
        }
      }, 50);
    }
    _shutter();
  }

  function zbar_result(symbol, data, polygon) {
    console.log(symbol, data);
    if(symbol == 'QR-Code') {
      drawPoly(polygon, 4, 'rgba(255,59,88,.4)');
    } else {
      drawPoly(polygon, 1, 'rgba(0,153,255,.4)');
    }
    var sw = seg.offsetWidth - 28;
    var sh = seg.offsetHeight - 28;
    if(canvas.width > 0 && sw > 0) {
      var mergin = 14;
      var c = canvas.height / canvas.width;
      var s = sh / sw;
      var x1, y1, x2, y2;
      if(c < s) {
        var w = canvas.height / s;
        x1 = (canvas.width - w) / 2;
        y1 = 0;
        x2 = x1 + w;
        y2 = canvas.height;
        x1 += mergin;
        x2 -= mergin;
        y1 += mergin;
        y2 -= mergin;
      } else {
        var h = canvas.width * s;
        x1 = 0;
        y1 = (canvas.height - h) / 2;
        x2 = canvas.width;
        y2 = y1 + h;
        x1 += mergin;
        x2 -= mergin;
        y1 += mergin;
        y2 -= mergin;
      }
      var range_flag = true;
      for(var i = 0; i < polygon.length - 1; i += 2) {
        if(!checkRange(polygon[i], polygon[i + 1], x1, y1, x2, y2)) {
          range_flag = false;
          break;
        }
      }
      if(range_flag && !abort && cb_done) {
        abort = true;
        shutter(data);
        return;
      }
    }
  }

  function tick() {
    if(video.readyState === video.HAVE_ENOUGH_DATA) {
      camera_scanning(true);
      canvas.height = video.videoHeight;
      canvas.width = video.videoWidth;
      ctx.drawImage(video, 0, 0, canvas.width, canvas.height);
      var imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);
      var grayData = [];
      var d = imageData.data;
      for(var i = 0, j = 0; i < d.length; i += 4, j++) {
        grayData[j] = (d[i] * 66 + d[i + 1] * 129 + d[i + 2] * 25 + 4096) >> 8;
      }
      cipher.result = zbar_result;
      cipher.zbar_scan(grayData, imageData.width, imageData.height);
    }
    if(abort) {
      return;
    }
    requestAnimationFrame(tick);
  }

  var mode_show = true;
  var qr_instance = null;
  var scan_done = false;

  var prev_camera_scanning_flag = false;
  function camera_scanning(flag) {
    if(prev_camera_scanning_flag != flag) {
      if(flag) {
        $('.qrcamera-loader').removeClass('active');
        $('.qr-scanning').show();
      } else {
        $('.qr-scanning').hide();
        if(!abort) {
          $('.qrcamera-loader').addClass('active');
        }
      }
      prev_camera_scanning_flag = flag;
    }
  }

  function video_status_change() {
    if(mode_show) {
      canvas.style.visibility = 'visible';
      $('.camtools').css('visibility', 'visible');
    } else {
      camera_scanning(false);
      $('.camtools').css('visibility', 'hidden');
      if(canvas) {
        canvas.style.visibility = 'hidden';
      }
    }
  }

  var current_deviceId = null;

  function show(cb) {
    canvas = document.getElementById("qrcanvas");
    if(!canvas || !pastel.cipher) {
      return;
    }
    cipher = pastel.cipher;
    mode_show = true;
    showing = false;
    abort = false;
    scan_done = false;
    $('.bt-scan-seed').css('visibility', 'hidden');
    $('.qrcamera-loader').addClass('active');
    video = video || document.createElement("video");
    canvas.style.visibility = 'visible';
    ctx = canvas.getContext("2d");
    seg = document.getElementById("seed-seg");
    cb_done = cb;

    var constraints;
    if(!current_deviceId) {
      constraints = {video: {facingMode: "environment"}};
    } else {
      constraints = {video: {deviceId: current_deviceId}};
    }
    if(navigator.mediaDevices) {
      navigator.mediaDevices.getUserMedia(constraints).then(function(stream) {
        if(!current_deviceId) {
          var envcam;
          stream.getTracks().forEach(function(track) {
            envcam = track.getSettings().deviceId;
            return true;
          });
          if(envcam) {
            camDevice.set_current(envcam);
          }
        }
        video.srcObject = stream;
        video.setAttribute("playsinline", true);
        video.play();

        video_status_change();
        showing = true;
        requestAnimationFrame(tick);
      }).catch(function(err) {
        cb_done(2, null);
      });
    } else {
      cb_done(1, null);
    }
  }

  function next() {
    hide(true);
    current_deviceId = camDevice.next();
    show(cb_done);
  }

  function hide(rescan) {
    if(mode_show) {
      abort = true;
      if(showing) {
        qr_stop();
        showing = false;
      }
      if(ctx && canvas) {
        ctx.clearRect(0, 0, canvas.width, canvas.height);
      }
      mode_show = false;
      video_status_change();
      if(!rescan) {
        if(canvas) {
          canvas.style.visibility = 'hidden';
        }
        $('.qrcamera-loader').removeClass('active');
      }
      $('.bt-scan-seed').css('visibility', 'visible');
    } else {
      console.log('hide mode_show', mode_show);
    }
  }

  var Module = {
    show: show,
    next: next,
    hide: hide
  }
  return Module;
})();

var qrReaderModal = (function() {
  var video = null;
  var canvas, ctx, seg;
  var cipher = {};
  var abort = false;
  var showing = false;

  function drawPoly(poly, lineWidth, color) {
    ctx.beginPath();
    ctx.moveTo(poly[0], poly[1]);
    for(var item = 2; item < poly.length - 1; item += 2) {
      ctx.lineTo(poly[item], poly[item + 1]);
    }
    ctx.lineWidth = lineWidth;
    ctx.strokeStyle = color;
    ctx.closePath();
    ctx.stroke();
  }

  function checkRange(x, y, x1, y1, x2, y2) {
    return (x > x1 && x < x2 && y > y1 && y < y2);
  }

  var cb_done = function() {}

  function qr_stop() {
    camera_scanning(false);
    video.pause();
    if(video.srcObject) {
      video.srcObject.getTracks().forEach(function(track) {
        track.stop();
      });
    }
    video.removeAttribute('src');
    video.load();
  }

  function shutter(data) {
    var active = true;
    var count = 0;
    function _shutter() {
      setTimeout(function() {
        if(active) {
          $('#qrcode-modal .qrcamera-shutter').addClass('active');
          active = false;
        } else {
          $('#qrcode-modal .qrcamera-shutter').removeClass('active');
          active = true;
          count++;
        }
        if(count < 3) {
          _shutter();
        } else {
          scan_done = true;
          qr_stop();
          showing = false;
          cb_done(0, data);
        }
      }, 50);
    }
    _shutter();
  }

  function zbar_result(symbol, data, polygon) {
    console.log(symbol, data);
    if(symbol == 'QR-Code') {
      drawPoly(polygon, 4, 'rgba(255,59,88,.4)');
    } else {
      drawPoly(polygon, 1, 'rgba(0,153,255,.4)');
    }
    var sw = seg.offsetWidth - 28;
    var sh = seg.offsetHeight - 28;
    if(canvas.width > 0 && sw > 0) {
      var mergin = 14;
      var c = canvas.height / canvas.width;
      var s = sh / sw;
      var x1, y1, x2, y2;
      if(c < s) {
        var w = canvas.height / s;
        x1 = (canvas.width - w) / 2;
        y1 = 0;
        x2 = x1 + w;
        y2 = canvas.height;
        x1 += mergin;
        x2 -= mergin;
        y1 += mergin;
        y2 -= mergin;
      } else {
        var h = canvas.width * s;
        x1 = 0;
        y1 = (canvas.height - h) / 2;
        x2 = canvas.width;
        y2 = y1 + h;
        x1 += mergin;
        x2 -= mergin;
        y1 += mergin;
        y2 -= mergin;
      }
      var range_flag = true;
      for(var i = 0; i < polygon.length - 1; i += 2) {
        if(!checkRange(polygon[i], polygon[i + 1], x1, y1, x2, y2)) {
          range_flag = false;
          break;
        }
      }
      if(range_flag && !abort && cb_done) {
        abort = true;
        shutter(data);
        return;
      }
    }
  }

  function tick() {
    if(video.readyState === video.HAVE_ENOUGH_DATA) {
      camera_scanning(true);
      canvas.height = video.videoHeight;
      canvas.width = video.videoWidth;
      ctx.drawImage(video, 0, 0, canvas.width, canvas.height);
      var imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);
      var grayData = [];
      var d = imageData.data;
      for(var i = 0, j = 0; i < d.length; i += 4, j++) {
        grayData[j] = (d[i] * 66 + d[i + 1] * 129 + d[i + 2] * 25 + 4096) >> 8;
      }
      cipher.result = zbar_result;
      cipher.zbar_scan(grayData, imageData.width, imageData.height);
    }
    if(abort) {
      return;
    }
    requestAnimationFrame(tick);
  }

  var mode_show = true;
  var qr_instance = null;
  var scan_done = false;

  var prev_camera_scanning_flag = false;
  function camera_scanning(flag) {
    if(prev_camera_scanning_flag != flag) {
      if(flag) {
        $('#qrcode-modal .qrcamera-loader').removeClass('active');
        $('#qrcode-modal .qr-scanning').show();
      } else {
        $('#qrcode-modal .qr-scanning').hide();
        if(!abort) {
          $('#qrcode-modal .qrcamera-loader').addClass('active');
        }
      }
      prev_camera_scanning_flag = flag;
    }
  }

  function video_status_change() {
    if(mode_show) {
      canvas.style.visibility = 'visible';
      $('.camtools').css('visibility', 'visible');
      $('#qrcode-modal .camtools .btn-camera').off('click').click(function() {
        hide(true);
        next();
        $(this).blur();
      });
      $('#qrcode-modal .def-close').off('click').click(function() {
        hide();
        $('#qrcode-modal').modal('hide');
      });
    } else {
      camera_scanning(false);
      $('.camtools').css('visibility', 'hidden');
      if(canvas) {
        canvas.style.visibility = 'hidden';
      }
    }
  }

  var current_deviceId = null;

  function qrShow(cb) {
    canvas = document.getElementById("qrcanvas-modal");
    if(!canvas || !pastel.cipher) {
      return;
    }
    cipher = pastel.cipher;
    $.fn.transition.settings.silent = true;
    mode_show = true;
    showing = false;
    abort = false;
    scan_done = false;
    $('#qrcode-modal .qrcamera-loader').addClass('active');
    video = video || document.createElement("video");
    ctx = canvas.getContext("2d");
    seg = document.getElementById("qrreader-seg");
    cb_done = cb;

    var constraints;
    if(!current_deviceId) {
      constraints = {video: {facingMode: "environment"}};
    } else {
      constraints = {video: {deviceId: current_deviceId}};
    }
    if(navigator.mediaDevices) {
      navigator.mediaDevices.getUserMedia(constraints).then(function(stream) {
        if(!current_deviceId) {
          var envcam;
          stream.getTracks().forEach(function(track) {
            envcam = track.getSettings().deviceId;
            return true;
          });
          if(envcam) {
            camDevice.set_current(envcam);
          }
        }
        video.srcObject = stream;
        video.setAttribute("playsinline", true);
        video.play();

        video_status_change();
        showing = true;
        requestAnimationFrame(tick);
      }).catch(function(err) {
        cb_done(2, null);
      });
    } else {
      cb_done(1, null);
    }
  }

  var qrcode_modal_html = function() {
    return  '<div id="qrcode-modal" class="ui basic modal" data-lang="' + getlang() + '">' +
              '<i class="close icon def-close"></i><div class="ui icon header"></div>' +
              '<div class="scrolling content"><div id="qrreader-seg" class="ui center aligned segment">' +
                '<div class="qr-scanning"><div></div><div></div></div>' +
                '<div class="ui small basic icon buttons camtools">' +
                  '<button class="ui button btn-camera"><i class="camera icon"></i></button>' +
                '</div>' +
                '<canvas id="qrcanvas-modal" width="0" height="0"></canvas>' +
                '<div class="ui active dimmer qrcamera-loader">' +
                  '<div class="ui indeterminate text loader">' + __t('Preparing Camera') + '</div>' +
                '</div>' +
                '<div class="ui dimmer qrcamera-shutter"></div>' +
              '</div></div>' +
              '<div class="actions"><button class="ui basic cancel inverted button">' +
                '<i class="remove icon"></i>' + __t('Cancel') +
              '</button></div>' +
            '</div>';
  }

  function show(cb, title) {
    if(!$('#qrcode-modal').length) {
      $('body').append(qrcode_modal_html());
    } else {
      if($('#qrcode-modal').data() != getlang()) {
        $('#qrcode-modal').replaceWith(qrcode_modal_html());
      }
    }
    $('#qrcode-modal .ui.header').text(title || __t('Scan QR Code'));
    $('#qrcode-modal').modal("setting", {
      closable: false,
      autofocus: false,
      onShow: function() {
        qrShow(function(err, data) {
          function worker() {
            var flag = $('#qrcode-modal').hasClass('active');
            if(flag) {
              cb(err, data);
              hide();
              $('#qrcode-modal').modal('hide');
            } else {
              setTimeout(worker, 300);
            }
          }
          worker();
        });
      },
      onApprove: function() {
        hide();
      },
      onDeny: function() {
        hide();
      }
    }).modal('show');
  }

  function next() {
    current_deviceId = camDevice.next();
    qrShow(cb_done);
  }

  function hide(rescan) {
    if(mode_show) {
      abort = true;
      if(showing) {
        qr_stop();
        showing = false;
      }
      if(ctx && canvas) {
        ctx.clearRect(0, 0, canvas.width, canvas.height);
      }
      mode_show = false;
      if(rescan) {
        video_status_change();
      } else {
        if(canvas) {
          canvas.style.visibility = 'hidden';
        }
      }
    }
  }

  var Module = {
    show: show,
    next: next,
    hide: hide
  }
  return Module;
})();

var Settings = (function() {
  var Module = {};
  var confirm_popup_tval;

  function reset_click() {
    var self = $(this);
    var check = $('#settings .ui.checkbox').checkbox('is checked');
    if(check) {
      $('#btn-reset').blur();
      $('#settings-modal').modal("setting", {
        closable: false,
        onApprove: function() {
          var stor = new Stor();
          stor.del_all();
          location.reload();
        },
        onDeny: function() {},
        onHidden: function() {
          var modal = $('#settings-modal');
          modal.clone().insertAfter('#settings');
          modal.remove();
        }
      }).modal('show');
    } else {
      self.blur();
      var confirm = $('#settings input[name="confirm"]');
      clearTimeout(confirm_popup_tval);
      confirm.popup({
        title: __t('Confirmation'),
        content: __t('Please read and check here before resetting your wallet.'),
        on: 'manual',
        variation: 'inverted',
        position: 'bottom left',
        distanceAway: 6,
        exclusive: true
      }).popup('show');
      confirm_popup_tval = setTimeout(function() {
        confirm.popup('hide');
      }, 10000);
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

var Notify = (function() {
  function hide(elm) {
    elm.addClass('remove').stop(true, true).animate({opacity: 0}, 100).animate({height: 0, 'padding-top': 0, 'padding-bottom': 0}, {
      duration: 100,
      complete: function() {
        elm.remove();
      }
    });
  }
  var _msgtype = {none: 0, error: 1, warning: 2, info: 3};
  function show(title, message, msgtype) {
    var m = $('#tools .notify-container .message').not('remove');
    var count = m.length - 6;
    if(count > 0) {
      for(var i = 0; i < count; i++) {
        var tval = m.eq(i).data('tval');
        clearTimeout(tval);
        if(i < count - 1) {
          m.eq(i).remove();
        } else {
          hide(m.eq(i));
        }
      }
    }
    var msgfmt;
    switch(msgtype) {
      case _msgtype.error:
        msgfmt = ' error';
        break;
      case _msgtype.warning:
        msgfmt = ' warning';
        break;
      case _msgtype.info:
        msgfmt = ' info';
        break;
      default:
        msgfmt = '';
    }
    var notify_html = '<div class="ui' + msgfmt +
      ' tiny message hidden"><i class="close icon"></i><div class="header">' + title +
      '</div><p>' + message + '</p></div>';
    $(notify_html).appendTo('#tools .notify-container').transition({
      animation: 'fade left',
      onComplete: function() {
        var self = $(this);
        var tval = setTimeout(function() {
          hide(self);
        }, 7000);
        self.attr('data-tval', tval);
      }
    }).find('.close').click(function() {
      var elm = $(this).closest('.message');
      var tval = elm.data('tval');
      clearTimeout(tval);
      hide(elm);
    });
  }

  function hide_all() {
    $('#tools .notify-container .message').each(function() {
      hide($(this));
    });
  }

  $(function() {
    var tools = document.getElementById('tools');
    if(!tools) {
      tools = document.createElement('div');
      tools.setAttribute('id', 'tools');
      document.body.appendChild(tools);
      $('<div class="notify-container"></div>').appendTo('#tools');
    }
  });

  var Module = {
    show: show,
    hide_all: hide_all,
    msgtype: _msgtype
  }
  return Module;
})();

var PhraseLock = (function() {
  var Module = {};
  var btn_lock_popup_tval;
  Module.PLOCK_SUCCESS = 0;
  Module.PLOCK_FAILED_QR = 1;
  Module.PLOCK_FAILED_PHRASE = 2;
  Module.PLOCK_FAILED_CAMERA = 3;
  Module.PLOCK_CANCEL = 4;

  function notify(msg, timeout) {
    var btn_lock = $('#btn-send-lock');
    clearTimeout(btn_lock_popup_tval);
    btn_lock.popup({
      title: '',
      content: msg,
      on: 'manual',
      variation: 'inverted',
      position: 'left center',
      distanceAway: 0,
      exclusive: true
    }).popup('show');
    btn_lock_popup_tval = setTimeout(function() {
      btn_lock.popup('hide');
      $('#btn-tx-send').blur();
    }, timeout || 5000);
  }

  Module.notify_if_need_unlock = function() {
    var locked = !($('#btn-send-lock i').hasClass('open'));
    if(locked) {
      notify(__t('Please unlock your wallet before sending coins.'));
      return true;
    }
    return false;
  }

  Module.notify_locked = function() {
    notify(__t('Locked'), 2000);
  }

  Module.notify_unlocked = function() {
    notify(__t('Unlocked'), 2000);
  }

  var passphrasse_modal_html = function() {
    return '<div id="passphrase-modal" class="ui basic modal" data-lang="' + getlang() + '"><i class="close icon def-close"></i>' +
      '<div class="ui icon header">' + __t('Input your passphrase') + '</div>' +
      '<div class="scrolling content">' +
        '<div id="passphrase-modal-seg" class="ui center aligned segment">' +
            '<div class="ui form">' +
              '<div class="field"><input class="center" type="password" name="input-passphrase" placeholder="' + __t('Passphrase') + '" spellcheck="false"></div>' +
            '</div>' +
        '</div>' +
      '</div>' +
      '<div class="actions">' +
        '<button class="ui basic cancel inverted button"><i class="remove icon"></i>' + __t('Cancel') + '</button>' +
        '<button class="ui basic ok inverted button"><i class="check icon"></i>' + __t('OK') + '</button>' +
      '</div>' +
    '</div>';
  }

  Module.showPhraseInput = function(cb) {
    var wallet = pastel.wallet;
    var lock_type = wallet.getLockShieldedType();
    if(lock_type == 1) {
      qrReaderModal.show(function(err, phrase) {
        if(err) {
          cb(Module.PLOCK_FAILED_CAMERA);
        } else if(pastel.wallet.unlockShieldedKeys(phrase)) {
          cb(Module.PLOCK_SUCCESS);
        } else {
          cb(Module.PLOCK_FAILED_QR);
        }
      }, __t('Scan your key card'));
    } else if(lock_type == 2) {
      $.fn.transition.settings.silent = true;
      if(!$('#passphrase-modal').length) {
        $('body').append(passphrasse_modal_html());
      } else {
        if($('#passphrase-modal').data() != getlang()) {
          $('#passphrase-modal').replaceWith(passphrasse_modal_html());
        }
      }
      $('#passphrase-modal').modal("setting", {
        closable: false,
        autofocus: true,
        onShow: function() {
          $('.ui.dimmer.modals').addClass('top-align');
          $('#passphrase-modal-seg input[name="input-passphrase"]').off('keydown').on('keydown', function(evt) {
            if(evt.which == 13 || evt.keyCode == 13) {
              $('#passphrase-modal .ui.ok.button').click();
            }
          });
        },
        onApprove: function() {
          console.log('approve');
          var phrase = $('#passphrase-modal-seg input[name="input-passphrase"]').val();
          if(pastel.wallet.unlockShieldedKeys(phrase)) {
            cb(Module.PLOCK_SUCCESS);
          } else {
            cb(Module.PLOCK_FAILED_PHRASE);
          }
        },
        onDeny: function() {
          console.log('deny');
          cb(Module.PLOCK_CANCEL);
        },
        onHidden: function() {
          $('#passphrase-modal-seg input[name="input-passphrase"]').val('');
          $('.ui.dimmer.modals').removeClass('top-align');
        }
      }).modal('show');
    }
  }

  var inactivity_time = 600000;
  var _inactivity_cb = function() {}
  var _notify_cb = function() {}
  var notify_postpone = false;

  var inactivity_called = false;
  var inactivity_internal = function() {
    if(inactivity_called) {
      return;
    }
    inactivity_called = true;
    _inactivity_cb();
    if(document.hidden) {
      notify_postpone = true;
    } else {
      notify_postpone = false;
      _notify_cb();
    }
  }
  var activity_tval = null;
  function reset_timer() {
    clearTimeout(activity_tval);
    activity_tval = null;
    inactivity_called = false;
    activity_tval = setTimeout(inactivity_internal, inactivity_time);
  }

  var stime, etime;
  function visibility_func() {
    if(document.hidden) {
      stime = new Date();
    } else {
      if(notify_postpone) {
        notify_postpone = false;
        _notify_cb();
      } else {
        etime = new Date();
        if(stime) {
          if(etime - stime >= inactivity_time) {
            inactivity_internal();
          }
        }
      }
    }
  }

  Module.enableInactivity = function(cb, notify_cb) {
    _inactivity_cb = cb;
    _notify_cb = notify_cb;
    clearTimeout(activity_tval);
    stime = null;
    etime = null;
    notify_postpone = false;
    var evts = ['mousemove', 'keypress'];
    for(var i in evts) {
      var evt = evts[i];
      window.removeEventListener(evt, reset_timer, true);
      window.addEventListener(evt, reset_timer, true);
    }
    window.removeEventListener('visibilitychange', visibility_func, true);
    window.addEventListener('visibilitychange', visibility_func, true);
  }

  Module.disableInactivity = function() {
    _inactivity_cb = function() {}
    _notify_cb = function() {}
    clearTimeout(activity_tval);
    stime = null;
    etime = null;
    notify_postpone = false;
    var evts = ['mousemove', 'keypress'];
    for(var i in evts) {
      var evt = evts[i];
      window.removeEventListener(evt, reset_timer, true);
    }
    window.removeEventListener('visibilitychange', visibility_func, true);
  }

  return Module;
})();

var LangSelector = (function() {
  function show(sellang) {
    var elm_langsel = document.getElementById('lang-selector');
    if(!elm_langsel) {
      var elm = document.createElement('div');
      elm.id = 'lang-selector';
      elm_langsel = document.body.appendChild(elm);
      elm_langsel.innerHTML =
      '<div id="selectlang" class="ui accordion">' +
        '<div class="title">' +
          '<i class="dropdown ui small icon tabindex" tabindex="-1" data-tabindex="-1"></i><span class="langtitle">' + __t('Language') + '</span>' +
        '</div>' +
        '<div class="content">' +
          '<div class="ui form">' +
            '<div class="grouped fields">' +
              '<div class="field">' +
                '<div class="ui radio checkbox">' +
                  '<input type="radio" name="lang" value="en">' +
                  '<label>English</label>' +
                '</div>' +
              '</div>' +
              '<div class="field">' +
                '<div class="ui radio checkbox">' +
                  '<input type="radio" name="lang" value="ja">' +
                  '<label>日本語</label>' +
                '</div>' +
              '</div>' +
            '</div>' +
          '</div>' +
        '</div>' +
      '</div>';
      $('#selectlang').accordion({
        selector: {
          trigger: '.title'
        }
      });
      $('#selectlang .checkbox').checkbox({
        onChecked: function() {
          var lang = $('#selectlang input[name="lang"]:checked').val();
          var stor  = new Stor();
          stor.set_lang(lang);
          stor = null;
          if(jsViewUpdate && setlang) {
            setlang(lang);
            $('#selectlang .langtitle').text(__t('Language'));
            jsViewUpdate();
          } else {
            location.reload();
          }
        }
      });
      $('#selectlang .checkbox').click(function() {
        $('#selectlang').accordion('close', 0);
      });
      if(sellang) {
        checklang(sellang);
      }
    }
  }
  function checklang(lang) {
    $('#selectlang input[name="lang"]').val([lang]);
  }
  var Module = {
    show: show,
    checklang: checklang
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

window.onerror = function(e){
  if(e) {
    if(e.indexOf('karax') >= 0) {
      location.reload();
    }
  }
}
