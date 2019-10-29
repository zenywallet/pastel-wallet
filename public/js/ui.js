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

function showRecvAddress() {
  if(!pastel.wallet || !pastel.utxoballs) {
    return;
  }
  var wallet = pastel.wallet;
  var addrs = wallet.getUnusedAddressList(5);
  $('#receive-address .new').hide();
  $('#receive-address .new').empty();
  for(var i in addrs) {
    var addr = addrs[i];
    $('#receive-address .new').append('<div class="circular ui icon mini button ball" data-idx="' + i + '"><img src="' + Ball.get(addr, 28) + '"></div>');
  }

  function ball_selector_event(sel) {
    $(sel).off('click').click(function() {
      var idx = $(this).data('idx');
      if(addrs[idx].length > 0) {
        $('#receive-address .ball').each(function() {
          $(this).removeClass('active');
        });
        $(this).addClass('active');
        $('#receive-address .address').stop(true, true).fadeOut(200, function() {
          $(this).text(addrs[idx]).fadeIn(400);
          if(idx != 5 && addrs[5].length > 0) {
            addrs[5] = "";
            $('#receive-address .used').stop().animate({opacity: 0}, 400).animate({width: 0}, 100);
          }
        });
      }
    });
  }

  var utxoballs_click = function(addr) {
    console.log('address=' + addr);
    if(addrs[5].length > 0) {
      addrs[5] = addr;
      $('#receive-address .used .ball').animate({opacity: 0}, 200, function() {
        $('#receive-address .used').animate({width: 0}, 100, function() {
          $('#receive-address .used .ball img').replaceWith('<img src="' + Ball.get(addr, 28) + '">');
          $('#receive-address .used').animate({width: 42}, 100, function() {
            $('#receive-address .ball').animate({opacity: 1}, 400);
            if($('#receive-address .used .ball').hasClass('active')) {
              $('#receive-address .address').stop(true, true).fadeOut(200, function() {
                if(addrs[5].length > 0) {
                  $(this).text(addrs[5]).fadeIn(400);
                }
              });
            }
          });
        });
      });
    } else {
      addrs[5] = addr;
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
      $('#receive-address .address').hide().text(addrs[0]).fadeIn(400);
      addrs.push("");
      pastel.utxoballs.click(utxoballs_click);
    }, 400);
  });
}

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
