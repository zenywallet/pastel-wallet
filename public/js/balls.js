var Ball = Ball || {
  cache: {},
  get: function(name, size, label, nocache) {
    var cipher = pastel.cipher;
    var id = name + size + label;
    if(nocache) {
      return DotMatrix.getImage(cipher.buf2hex(cipher.murmurhash((new TextEncoder).encode(name))), size, 1, label);
    }
    if(!this.cache[id]) {
      this.cache[id] = DotMatrix.getImage(cipher.buf2hex(cipher.murmurhash((new TextEncoder).encode(name))), size, 1, label);
    }
    return this.cache[id];
  },
  utxos: [],
  create_balls_task: [],
  balls_r: 0,
  bodies: [],
  too_much_balls_enable: false,
  too_much_balls: null
};

var UtxoBalls = UtxoBalls || {};
UtxoBalls.click_cb = function(address) {}
var create_balls_worker_tval = null;
var scale_checker_tval = null;
var check_too_much_balls_tval = null;
var check_out_balls_tval = null;

UtxoBalls.simple = function() {
  var target_elm = document.getElementById('wallet-seg');
  if(!target_elm) {
    return null;
  }

  var Engine = Matter.Engine,
    Render = Matter.Render,
    Runner = Matter.Runner,
    MouseConstraint = Matter.MouseConstraint,
    Mouse = Matter.Mouse,
    World = Matter.World,
    Bodies = Matter.Bodies,
    Body = Matter.Body,
    Events = Matter.Events,
    Query = Matter.Query;

  var engine = Engine.create();
  var world = engine.world;

  var w = target_elm.clientWidth - 14 * 2;
  var h = target_elm.clientHeight - 14 * 2;
  var rect = target_elm.getBoundingClientRect();

  $('#wallet-seg').empty();
  var render = Render.create({
    element: target_elm,
    engine: engine,
    options: {
      width: w,
      height: h,
      wireframes: false,
      wireframeBackground: 'transparent',
      background: 'transparent'
    }
  });

  Render.run(render);

  var runner = Runner.create();
  Runner.run(runner, engine);

  var coin = coinlibs.coin;
  var network = coin.networks[pastel.config.network];
  var crypto = window.crypto || window.msCrypto;

  function sanitize(str) {
    if(/^[a-z0-9\.']+$/i.test(str)) {
      return String(str);
    }
    return '';
  }

  function conv_coin(uint64_val) {
    strval = uint64_val.toString();
    val = parseInt(strval);
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

  function utxo_cmp(utxo1, utxo2) {
    if(utxo1.sequence == utxo2.sequence &&
      utxo1.txid == utxo2.txid &&
      utxo1.n == utxo2.n &&
      utxo1.address == utxo2.address &&
      utxo1.value == utxo2.value) {
      return true;
    }
    return false;
  }

  function create_balls_worker() {
    clearTimeout(check_too_much_balls_tval);
    clearTimeout(scale_checker_tval);
    clearTimeout(check_out_balls_tval);
    var task = Ball.create_balls_task.shift();
    if(task) {
      if(task.type == 0) {
        Matter.Composite.remove(world, task.ball);
      } else if(task.type == 1) {
        var utxo = task.utxo;
        var address = sanitize(utxo.address);
        var s = Math.ceil(Ball.balls_r * utxo.cr);
        var s_max = w > h ? h / 6 : w / 6;
        if(s > s_max) {
          s = s_max;
        }
        var x = Math.round(Math.random() * (w - s) + s / 2);
        var y = Math.round(Math.random() * (200 - s) + s / 2);
        var ball = Bodies.circle(x, y, s / 2, {
          label: 'ball',
          address: address,
          value: utxo.value,
          utxo: utxo,
          restitution: 0.3,
          frictionAir: 0.03,
          render: {
            sprite: {
              texture: Ball.get(address, 64),
              xScale: s / 64,
              yScale: s / 64,
              imgsize: 64
            }
          }
        });
        Ball.bodies.push(ball);
        World.add(world, ball);
      }
      create_balls_worker_tval = setTimeout(create_balls_worker, 10);
    } else {
      check_too_much_balls_tval = setTimeout(check_too_much_balls, 3000);
      check_out_balls_tval = setTimeout(check_out_balls, 5000);
    }
  }

  function update_balls(utxos, cb) {
    clearTimeout(create_balls_worker_tval);
    create_balls_worker_tval = null;
    var addlist = [];
    var removelist = [];

    if(utxos == null) {
      utxos = Ball.utxos;
      Ball.bodies = [];
      Ball.create_balls_task = [];
      var ss = 0;
      for(var i in utxos) {
        var utxo = utxos[i];
        Ball.create_balls_task.push({type: 1, utxo: utxos[i]});
        ss += utxo.s;
      }
      Ball.balls_r = Math.sqrt(((w * h) / 7) / ss);
      create_balls_worker();
      Ball.too_much_balls_enable = false;
    } else {
      utxos = utxos.slice(0, 140);
      if(Ball.utxos.length == 0) {
        var ss = 0;
        for(var i in utxos) {
          var utxo = utxos[i];
          utxo.value = conv_coin(sanitize(utxo.value))
          utxo.s = parseFloat(utxo.value);
          utxo.r = Math.sqrt(utxo.s);
          ss += utxo.s;
        }
        Ball.balls_r = Math.sqrt(((w * h) / 7) / ss);
      } else {
        for(var i in utxos) {
          var utxo = utxos[i];
          utxo.value = conv_coin(sanitize(utxo.value))
          utxo.s = parseFloat(utxo.value);
          utxo.r = Math.sqrt(utxo.s);
        }
      }

      var ave = 0.0;
      var sd = 0.0;
      var len = utxos.length;
      if(len > 1) {
        for(var i in utxos) {
          ave += utxos[i].r;
        }
        ave /= len;
        for(var i in utxos) {
          var d = utxos[i].r - ave;
          sd += d * d;
        }
        sd = Math.sqrt(sd / (len - 1));
        if(sd > 0) {
          for(var i in utxos) {
            var cr = 36 + 28 * (utxos[i].r - ave) / (1.5 * sd);
            if(cr > 64) {
              cr = 64;
            } else if(cr < 8) {
              cr = 8;
            }
            utxos[i].cr = cr;
          }
        } else {
          for(var i in utxos) {
            utxos[i].cr = 32;
          }
        }
      } else {
        for(var i in utxos) {
          utxos[i].cr = 32;
        }
      }

      for(var i in utxos) {
        var find = false;
        var a = utxos[i];
        for(var j in Ball.utxos) {
          var b = Ball.utxos[j];
          if(utxo_cmp(a, b)) {
            find = true;
            break;
          }
        }
        if(!find) {
          addlist.push(a);
        }
      }
      for(var i in Ball.utxos) {
        var find = false;
        var a = Ball.utxos[i];
        for(var j in utxos) {
          var b = utxos[j];
          if(utxo_cmp(a, b)) {
            find = true;
            break;
          }
        }
        if(!find) {
          removelist.push(a);
        }
      }
      Ball.utxos = utxos;
    }

    for(var i in removelist) {
      var r = removelist[i];
      for(var j = Ball.bodies.length - 1; j >= 0; j--) {
        var body = Ball.bodies[j];
        if(body.utxo) {
          if(utxo_cmp(r, body.utxo)) {
            Ball.create_balls_task.push({type: 0, ball: body});
            Ball.bodies.splice(j, 1);
          }
        }
      }
    }

    for(var i in addlist) {
      Ball.create_balls_task.push({type: 1, utxo: addlist[i]});
    }
    create_balls_worker_tval = setTimeout(create_balls_worker, 3000);
  }

  var scale_dec = 0.98;
  var scale_inc = 1.0 / scale_dec;

  function total_circle_area() {
    var ss = 0;
    for(var i in Ball.bodies) {
      var body = Ball.bodies[i];
      var s = body.circleRadius * 2;
      ss += s * s;
    }
    return ss;
  }

  function change_scale(flag) {
    var scale;
    if(flag > 0) {
      scale = scale_inc;
    } else {
      scale = scale_dec;
    }
    for(var i in Ball.bodies) {
      var body = Ball.bodies[i];
      Matter.Body.scale(body, scale, scale);
      var imgsize = body.render.sprite.imgsize;
      body.render.sprite.xScale = body.circleRadius * 2 / imgsize;
      body.render.sprite.yScale = body.circleRadius * 2 / imgsize;
    }
  }

  function scale_checker() {
    var over_high = false;
    var prev_area = 0;
    var prev_c_area = 0;

    function scale_worker() {
      var area = w * h;
      var area_low = area / 80;
      var area_high = area / 2.2;
      var c_area = total_circle_area();
      if(prev_area != area || prev_c_area != c_area) {
        over_high = false;
        prev_area = area;
        prev_c_area = c_area;
      }
      if(c_area > area_high) {
        over_high = true;
        change_scale(-1);
        scale_checker_tval = setTimeout(scale_checker, 300);
        return;
      } else if(c_area < area_low) {
        if(!over_high) {
          change_scale(1);
          scale_checker_tval = setTimeout(scale_checker, 300);
          return;
        }
      }
      scale_checker_tval = setTimeout(scale_checker, 3000);
    }
    scale_worker();
  }

  function check_too_much_balls() {
    if(Ball.bodies.length > 120) {
      if(!Ball.too_much_balls_enable) {
        Ball.too_much_balls_enable = true;
        var s2 = w > h ? (h / 6) : (w / 6);
        if(s2 < 80) {
          s2 = 80;
        }
        var x = Math.round(Math.random() * (w - s2) + s2 / 2);

        var ball = Bodies.circle(x, 140, s2 / 2, {
          label: 'ball',
          address: null,
          value: null,
          restitution: 0.3,
          frictionAir: 0.03,
          render: {
            sprite: {
              texture: Ball.get(String(200), 160, 'Too Much Balls', true),
              xScale: s2 / 160,
              yScale: s2 / 160,
              imgsize: 160
            }
          }
        });
        Ball.bodies.push(ball);
        Ball.too_much_balls = ball;
        World.add(world, ball);
      }
    } else {
      if(Ball.too_much_balls_enable) {
        if(Ball.too_much_balls) {
          for(var i in Ball.bodies) {
            if(Ball.too_much_balls == Ball.bodies[i]) {
              Ball.bodies.splice(i, 1);
              break;
            }
          }
          Matter.Composite.remove(world, Ball.too_much_balls);
          Ball.too_much_balls = null;
          Ball.too_much_balls_enable = false;
        }
      }
    }

    scale_checker_tval = setTimeout(scale_checker, 3000);
  }


  function resetPosition(ball) {
    var s = ball.circleRadius * 2;
    var x = Math.round(Math.random() * (w - s) + s / 2);
    var y = Math.round(Math.random() * (200 - s) + s / 2);
    Body.setPosition(ball, {x: x, y: y});
  }

  function check_out_balls() {
    var find = false;
    for(var i in Ball.bodies) {
      var b = Ball.bodies[i];
      if(b.position.y > h + 200 + 25) {
        find = true;
        if(b.position.y > 10000) {
          resetPosition(b);
          break;
        }
      }
    }
    if(find) {
      check_out_balls_tval = setTimeout(check_out_balls, 100);
    } else {
      check_out_balls_tval = setTimeout(check_out_balls, 5000);
    }
  }

  function check_out(ball) {
    if(ball.position.x < - 25 || ball.position.x > w + 25
      || ball.position.y < -25 || ball.position.y > h + 200 + 25) {
      return true;
    }
    return false;
  }

  var wall_options = { isStatic: true, render: {
    fillStyle: 'transparent'
  }};

  World.add(world, [
    Bodies.rectangle(w / 2, -25, w, 50, wall_options),                          // top
    Bodies.rectangle(w / 2, h + 200 + 25, w, 50, wall_options),                 // bottom
    Bodies.rectangle(w + 25, (h + 200) / 2, 50, (h + 200) + 100, wall_options), // right
    Bodies.rectangle(-25, (h + 200) / 2, 50, (h + 200) + 100, wall_options)     // left
  ]);

  var mouse = Mouse.create(render.canvas);
  var mouseConstraint = MouseConstraint.create(engine, {
    mouse: mouse,
    constraint: {
      stiffness: 0.2,
      render: {
        visible: false
      }
    }
  });

  mouse.element.removeEventListener("mousewheel", mouse.mousewheel);
  mouse.element.removeEventListener("DOMMouseScroll", mouse.mousewheel);

  var dragging = false;
  Events.on(mouseConstraint, "startdrag", function(e) {
    if(e.body.address) {
      UtxoBalls.click_cb(e.body.address);
    }
    dragging = true;
  });

  Events.on(mouseConstraint, "enddrag", function(e) {
    dragging = false;
  });

  var cur_id = -1;
  var tval = null;
  $('#wallet-seg').mouseout(function() {
    $('#ball-info').fadeOut(800);
  });
  Events.on(mouseConstraint, 'mousemove', function (e) {
    var foundPhysics = Matter.Query.point(Ball.bodies, e.mouse.position);
    if(foundPhysics.length == 1 && !dragging) {
      var ball = foundPhysics[0];
      if(cur_id != ball.id && ball.address && ball.value) {
        cur_id = ball.id;
        $('#ball-info').html(ball.address + '<br>' + ball.value).css({left: ball.position.x + 28, top: ball.position.y - 100 - ball.circleRadius * 2 / 3}).stop(true, true).fadeIn(400);
      } else if(cur_id == ball.id) {
        $('#ball-info').css({left: ball.position.x + 28, top: ball.position.y - 100 - ball.circleRadius * 2 / 3});
      }
    } else {
      if(cur_id != -1) {
        cur_id = -1;
        $('#ball-info').fadeOut(800);
      }
    }
    clearTimeout(tval);
    tval = setTimeout(function() {
      if(cur_id != -1) {
        cur_id = -1;
        $('#ball-info').fadeOut(800);
      }
    }, 5000);
  });

  var defaultCategory = 0x0001;
  var fluffy1 = 0x0002;
  var fluffy2 = 0x0004;
  var fluffy3 = 0x0008;

  function setFluffy(ball, fluffy) {
    ball.fluffy = fluffy;
    ball.collisionFilter.category = fluffy;
    ball.collisionFilter.mask = defaultCategory | fluffy;
  }

  Events.on(engine, 'beforeUpdate', function(event) {
    var time = engine.timing.timestamp;
    for(var i in Ball.bodies) {
      var b = Ball.bodies[i];
      if(!b.rnd) {
        b.rnd = Math.random();
      }
      if(b.rnd > 0.7) {
        setFluffy(b, fluffy1);
      } else if(b.rnd > 0.4) {
        setFluffy(b, fluffy2);
      } else {
        setFluffy(b, fluffy3);
      }
      if(b.fluffy) {
        switch(b.fluffy) {
          case fluffy1:
            var vy = (rect.y + 64 - b.position.y) / 10 + (b.rnd + 0.5) * Math.sin((b.rnd * 1000 + time) * (0.001 + b.rnd * 2 / 1000));
            if(vy < -10) {
              vy = -10;
            } else if (vy > 10) {
              vy = 10;
            }
            Body.setVelocity(b, {x: 0, y: vy});
            Body.setAngularVelocity(b, (b.rnd * 2 - 1) / 30);
            break;
          case fluffy2:
            var vy = (rect.y + 264 - b.position.y) / 10 + (b.rnd + 0.5) * Math.sin((b.rnd * 1000 + time) * (0.001 + b.rnd * 3 / 1000));
            if(vy < -10) {
              vy = -10;
            } else if (vy > 10) {
              vy = 10;
            }
            Body.setVelocity(b, {x: 0, y: vy});
            Body.setAngularVelocity(b, (b.rnd * 2 - 1) / 20);
            break;
        }
      }
    }
  });

  World.add(world, mouseConstraint);
  render.mouse = mouse;

  Render.lookAt(render, {
    min: { x: 0, y: 200 },
    max: { x: w, y: h + 200 }
  });

  function start() {
      //Matter.Runner.start(runner, engine);
      Matter.Runner.run(engine);
      Matter.Render.run(render);
      //for(var i in Ball.bodies) {
      //  var body = Ball.bodies[i];
      //  body.isStatic = false;
      //}
  }

  function stop() {
    Matter.Render.stop(render);
    Matter.Runner.stop(runner);
    //for(var i in Ball.bodies) {
    //  var body = Ball.bodies[i];
    //  body.isStatic = true;
    //}
  }

  if(!UtxoBalls.resize_func) {
    clearTimeout(UtxoBalls.resize_tval);
    window.removeEventListener("resize", UtxoBalls.resize_func);
  }
  UtxoBalls.resize_tval = null;
  UtxoBalls.resize_func = function() {
    clearTimeout(UtxoBalls.resize_tval);
    UtxoBalls.resize_tval = setTimeout(function() {
      stop();
      var simple = UtxoBalls.simple();
      simple.update_balls();
    }, 1400);
  }
  window.addEventListener("resize", UtxoBalls.resize_func);

  if(UtxoBalls.visibility_func) {
    window.removeEventListener("visibilitychange", UtxoBalls.visibility_func, false);
  }
  UtxoBalls.visibility_func = function() {
    console.log(document.hidden, document.visibilityState);
    if(document.hidden) {
      stop();
    } else {
      start();
    }
  }
  window.addEventListener("visibilitychange", UtxoBalls.visibility_func, false);

  if(!UtxoBalls.result_obj) {
    UtxoBalls.result_obj = {
      engine: engine,
      runner: runner,
      render: render,
      canvas: render.canvas,
      start: start,
      stop: stop,
      click: function(cb) {
        UtxoBalls.click_cb = cb;
      },
      click_cb: function() {
        return UtxoBalls.click_cb;
      },
      update_balls: update_balls
    };
  } else {
    var obj = UtxoBalls.result_obj;
    obj.engine = engine;
    obj.runner = runner;
    obj.render = render;
    obj.canvas = render.canvas;
    obj.stop = stop;
    obj.update_balls = update_balls;
  }
  return UtxoBalls.result_obj;
}
