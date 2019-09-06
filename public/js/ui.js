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
  var difflist = {};
  var sections = document.getElementsByClassName('section');
  Array.prototype.forEach.call(sections, function(section) {
    var rect = section.getBoundingClientRect();
    var section_id = section.getAttribute('id');
    difflist['#' + section_id] = Math.abs(rect.top);
  });
  var min_val = 0;
  var min_item = null;
  for(var key in difflist) {
    if(min_item == null || difflist[key] < min_val) {
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
