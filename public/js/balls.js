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
  unconfs: [],
  create_balls_task: [],
  balls_r: 0,
  bodies: [],
  bodies_idx: {},
  too_much_balls_enable: false,
  too_much_balls: null,
  too_much_balls_fluffy: null,
  prev_setsend_count: 0,
  bodies_away: []
};

var UtxoBalls = UtxoBalls || {};
UtxoBalls.click_cb = function(address) {}
UtxoBalls.mouseup = function(evt) {}
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

  function create_bodies_idx(body, forcetype) {
    switch(body.ballType) {
      case 0:
        var utxo = body.utxo;
        var idx = (forcetype || body.ballType) + '-' + utxo.txid + '-' + utxo.n + '-' + utxo.address + '-' + utxo.value;
        return idx;
      case 1:
        var unconf = body.unconf;
        var idx = (forcetype || body.ballType) + '-' + unconf.txid + '-' + unconf.n + '-' + unconf.address + '-' + unconf.value;
        return idx;
      case 2:
        var idx = (forcetype || body.ballType);
        return idx;
      default:
        return 'unknown';
    }
  }
  function add_bodies_idx(body) {
    var idx = create_bodies_idx(body);
    Ball.bodies_idx[idx] = body;
  }
  function remove_bodies_idx(body) {
    var idx = create_bodies_idx(body);
    delete Ball.bodies_idx[idx];
  }
  function remove_all_bodies_idx() {
    Ball.bodies_idx = {};
  }

  function create_utxo_ball(utxo) {
    var address = sanitize(utxo.address);
    var s = Math.ceil(Ball.balls_r * utxo.cr);
    var s_max = w > h ? h / 6 : w / 6;
    if(s > s_max) {
      s = s_max;
    }
    var x = Math.round(Math.random() * (w - s) + s / 2);
    var y = Math.round(Math.random() * (200 - s) + s / 2);
    var ball = Bodies.circle(x, y, s / 2, {
      ballType: 0,
      label: 'ball',
      address: address,
      value: utxo.value_d,
      utxo: utxo,
      restitution: 0.3,
      frictionAir: 0.03,
      fluffy: fluffy3,
      collisionFilter: {
        category: fluffy3,
        mask: defaultCategory | fluffy3
      },
      render: {
        sprite: {
          texture: Ball.get(address, 64),
          xScale: s / 64,
          yScale: s / 64,
          imgsize: 64
        }
      }
    });
    return ball;
  }

  function create_unconf_ball(unconf) {
    var address = sanitize(unconf.address);
    var s = Math.ceil(Ball.balls_r * unconf.cr);
    var s_max = w > h ? h / 6 : w / 6;
    if(s > s_max) {
      s = s_max;
    }
    var x = Math.round(Math.random() * (w - s) + s / 2);
    var y = Math.round(Math.random() * (200 - s) + s / 2);
    var ball = Bodies.circle(x, y, s / 2, {
      ballType: 1,
      label: 'ball',
      address: address,
      value: unconf.value_d,
      unconf: unconf,
      restitution: 0.3,
      frictionAir: 0.03,
      fluffy: fluffy1,
      collisionFilter: {
        category: fluffy1,
        mask: defaultCategory | fluffy1
      },
      render: {
        sprite: {
          texture: Ball.get(address, 64),
          xScale: s / 64,
          yScale: s / 64,
          imgsize: 64
        }
      }
    });
    return ball;
  }

  function create_balls_worker() {
    clearTimeout(create_balls_worker_tval);
    clearTimeout(check_too_much_balls_tval);
    clearTimeout(scale_checker_tval);
    clearTimeout(check_out_balls_tval);
    var task = Ball.create_balls_task.shift();
    if(task) {
      if(task.type == 11) {
        for(var i in Ball.bodies) {
          var ball = Ball.bodies[i];
          if(ball.ballType == 0) {
            ball.ballMark = 1;
          }
        }
      } else if(task.type == 12) {
        for(var i = Ball.bodies.length - 1; i >= 0; i--) {
          var ball = Ball.bodies[i];
          if(ball.ballType == 0 && ball.ballMark == 1) {
            Matter.Composite.remove(world, ball);
            remove_bodies_idx(ball);
            Ball.bodies.splice(i, 1);
          }
        }
      } else if(task.type == 13) {
        var idx1 = create_bodies_idx({ballType: 1, unconf: task.utxo});
        var ball = Ball.bodies_idx[idx1];
        if(ball) {
          remove_bodies_idx(ball);
          ball.ballType = 0;
          ball.ballMark = 0;
          ball.utxo = task.utxo;
          add_bodies_idx(ball);
          setFluffy(ball, fluffy3);
        } else {
          var idx = create_bodies_idx({ballType: 0, utxo: task.utxo});
          var ball = Ball.bodies_idx[idx];
          if(ball) {
            ball.ballMark = 0;
          } else {
            var ball = create_utxo_ball(task.utxo);
            if(Ball.too_much_balls) {
              var tb = Ball.too_much_balls;
              var r = tb.circleRadius / 3 * (Math.random() - 0.5);
              Body.setPosition(ball, {x: tb.position.x + r, y: tb.position.y - tb.circleRadius / 2});
              Body.setVelocity(ball, {x: r, y: -5});
              Body.setAngularVelocity(ball, Math.PI / 6 * (Math.random() - 0.5));
            }
            Ball.bodies.push(ball);
            add_bodies_idx(ball);
            World.add(world, ball);
          }
        }
      } else if(task.type == 15) {
        var idx = create_bodies_idx({ballType: 0, utxo: task.utxo});
        var ball = Ball.bodies_idx[idx];
        if(ball) {
          remove_bodies_idx(ball);
          for(var i = Ball.bodies.length - 1; i >= 0; i--) {
            if(Ball.bodies[i] == ball) {
              Ball.bodies.splice(i, 1);
              break;
            }
          }
        }
        ball = create_utxo_ball(task.utxo);
        Ball.bodies.push(ball);
        add_bodies_idx(ball);
        World.add(world, ball);
      } else if(task.type == 19) {
        var idx = create_bodies_idx({ballType: 1, unconf: task.unconf});
        ball = Ball.bodies_idx[idx];
        if(ball) {
          remove_bodies_idx(ball);
          for(var i = Ball.bodies.length - 1; i >= 0; i--) {
            if(Ball.bodies[i] == ball) {
              Ball.bodies.splice(i, 1);
              break;
            }
          }
        }
        ball = create_unconf_ball(task.unconf);
        Ball.bodies.push(ball);
        add_bodies_idx(ball);
        World.add(world, ball);
      } else if(task.type == 16) {
        for(var i in Ball.bodies) {
          var ball = Ball.bodies[i];
          if(ball.ballType == 1) {
            ball.ballMark = 1;
          }
        }
      } else if(task.type == 17) {
        for(var i = Ball.bodies.length - 1; i >= 0; i--) {
          var ball = Ball.bodies[i];
          if(ball.ballType == 1 && ball.ballMark == 1) {
            if(ball.unconf.txtype == 1) {
              remove_bodies_idx(ball);
              ball.ballType = 0;
              ball.ballMark = 0;
              ball.utxo = ball.unconf;
              add_bodies_idx(ball);
              setFluffy(ball, fluffy3);
            } else {
              Ball.bodies_away.push(ball);
              remove_bodies_idx(ball);
              Ball.bodies.splice(i, 1);
              setTimeout(function() {
                Matter.Composite.remove(world, Ball.bodies_away.shift());
              }, 6000);
            }
          }
        }
      } else if(task.type == 18) {
        var idx0 = create_bodies_idx({ballType: 0, utxo: task.unconf});
        var ball = Ball.bodies_idx[idx0];
        if(ball) {
          remove_bodies_idx(ball);
          ball.ballType = 1;
          ball.ballMark = 0;
          ball.unconf = task.unconf;
          add_bodies_idx(ball);
          setFluffy(ball, fluffy1);
        } else {
          var idx = create_bodies_idx({ballType: 1, unconf: task.unconf});
          var ball = Ball.bodies_idx[idx];
          if(ball) {
            ball.ballMark = 0;
          } else {
            var ball = create_unconf_ball(task.unconf);
            if(task.unconf.ref) {
              var ref = task.unconf.ref;
              var idx_ref = create_bodies_idx({ballType: 1, unconf: ref});
              var ball_ref = Ball.bodies_idx[idx_ref];
              if(ball_ref) {
                setTimeout(function() {
                  var rx = 5 * (Math.random() - 0.5);
                  var ry = 5 * (Math.random() - 0.5);
                  ball.fluffy_free = true;
                  setFluffyCollisionAll(ball);
                  fluffy_frees.push(ball);
                  fluffy_free_worker_start();
                  Body.setPosition(ball, {x: ball_ref.position.x, y: ball_ref.position.y});
                  Body.setVelocity(ball, {x: rx, y: ry});
                  Body.setAngularVelocity(ball, Math.PI / 6 * (Math.random() - 0.5));
                  World.add(world, ball);
                }, 1000);
              Ball.bodies.push(ball);
              add_bodies_idx(ball);
              }
            } else {
              Ball.bodies.push(ball);
              add_bodies_idx(ball);
              World.add(world, ball);
            }
          }
        }
      } else if(task.type == 20) {
        setsend(Ball.prev_setsend_count);
      }
      create_balls_worker_tval = setTimeout(create_balls_worker, 10);
    } else {
      check_too_much_balls_tval = setTimeout(check_too_much_balls, 3000);
      check_out_balls_tval = setTimeout(check_out_balls, 5000);
    }
  }

  function update_balls_r() {
    var utxos = Ball.utxos;
    var unconfs = Ball.unconfs;
    if(utxos.length > 0 || unconfs.length > 0) {
      var ave = 0.0;
      var sd = 0.0;
      var len = utxos.length + unconfs.length;
      if(len > 1) {
        for(var i in utxos) {
          ave += utxos[i].r;
        }
        for(var i in unconfs) {
          ave += unconfs[i].r;
        }
        ave /= len;
        for(var i in utxos) {
          var d = utxos[i].r - ave;
          sd += d * d;
        }
        for(var i in unconfs) {
          var d = unconfs[i].r - ave;
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
          for(var i in unconfs) {
            var cr = 36 + 28 * (unconfs[i].r - ave) / (1.5 * sd);
            if(cr > 64) {
              cr = 64;
            } else if(cr < 8) {
              cr = 8;
            }
            unconfs[i].cr = cr;
          }
        } else {
          for(var i in utxos) {
            utxos[i].cr = 36;
          }
          for(var i in unconfs) {
            unconfs[i].cr = 36;
          }
        }
      } else {
        for(var i in utxos) {
          utxos[i].cr = 36;
        }
        for(var i in unconfs) {
          unconfs[i].cr = 36;
        }
      }
      var ss = 0;
      for(var i in utxos) {
        var cr = utxos[i].cr;
        ss += cr * cr;
      }
      for(var i in unconfs) {
        var cr = unconfs[i].cr;
        ss += cr * cr;
      }
      Ball.balls_r = Math.sqrt(((w * h) / 3) / ss);
    }
  }

  // create_balls_task
  // 11 - mark all
  // 12 - remove marked
  // 13 - add ball
  // 14 - remove ball
  // 15 - reset utxo location
  // 16 - mark unconf all
  // 17 - remove unconf marked
  // 18 - add unconf ball
  // 19 - reset unconf location
  function update_balls(utxos, cb) {
    if(utxos == null) {
      var utxos = Ball.utxos;
      var unconfs = Ball.unconfs;
      Ball.too_much_balls_enable = false;
      update_balls_r();
      for(var i in utxos) {
        Ball.create_balls_task.push({type: 15, utxo: utxos[i]});
      }
      for(var i in unconfs) {
        Ball.create_balls_task.push({type: 19, unconf: unconfs[i]});
      }
      Ball.create_balls_task.push({type: 20});
    } else {
      Ball.create_balls_task.push({type: 11});
      utxos = utxos.slice(0, 140);
      for(var i in utxos) {
        var utxo = utxos[i];
        utxo.value_d = conv_coin(sanitize(utxo.value))
        utxo.s = parseFloat(utxo.value);
        utxo.r = Math.sqrt(utxo.s);
      }
      Ball.utxos = utxos;
      update_balls_r();
      for(var i in utxos) {
        Ball.create_balls_task.push({type: 13, utxo: utxos[i]});
      }
      Ball.create_balls_task.push({type: 12});
    }
    create_balls_worker();
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

        var fluffy = Ball.too_much_balls_fluffy || fluffy3;
        var ball = Bodies.circle(x, 140, s2 / 2, {
          ballType: 2,
          label: 'ball',
          address: null,
          value: null,
          restitution: 0.3,
          frictionAir: 0.03,
          fluffy: fluffy,
          collisionFilter: {
            category: fluffy,
            mask: defaultCategory | fluffy
          },
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
        add_bodies_idx(ball);
        Ball.too_much_balls = ball;
        World.add(world, ball);
      }
    } else {
      if(Ball.too_much_balls_enable) {
        if(Ball.too_much_balls) {
          for(var i = Ball.bodies.length - 1; i >= 0; i--) {
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
      if(b.fluffy != fluffy3) {
        if(check_out(b)) {
          find = true;
          resetPosition(b);
          break;
        }
      }
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

  function unconfs(data) {
    console.log('unconfs=', JSON.stringify(data));
    var mytxs = {};
    for(var txid in data.txs) {
      var tx = data.txs[txid];
      var send_addrs = {};
      for(var txa in tx.data) {
        var v = tx.data[txa]
        for(var i in v) {
          if(i == 0) {
            send_addrs[txa] = 1;
          }
        }
      }
      if(Object.keys(send_addrs).length > 0) {
        mytxs[txid] = send_addrs;
      }
    }
    var unconf_list = [];
    var unconf_pop_list = [];
    Ball.create_balls_task.push({type: 16});
    for(var addr in data.addrs) {
      var val = data.addrs[addr];
      if(val.spents) {
        for(i in val.spents) {
          var spent = val.spents[i];
          var item = {txtype: 0, address: addr, txid: spent.txid, n: spent.n, value: spent.value,
            value_d: conv_coin(sanitize(spent.value)), change: val.change, index: val.index,
            xpub_idx: val.xpub_idx, trans_time: spent.trans_time, txid_out: spent.txid_out};
          unconf_list.push(item);
        }
      }
      if(val.txouts) {
        for(i in val.txouts) {
          var txout = val.txouts[i];
          var item = {txtype: 1, address: addr, txid: txout.txid, n: txout.n, value: txout.value,
            value_d: conv_coin(sanitize(txout.value)), change: val.change, index: val.index,
            xpub_idx: val.xpub_idx, trans_time: txout.trans_time};
          if(mytxs[txout.txid]) {
            unconf_pop_list.push(item);
          } else {
            unconf_list.push(item);
          }
        }
      }
    }
    var mark = {};
    for(var i in unconf_pop_list) {
      var itemp = unconf_pop_list[i];
      var send_addrs = mytxs[itemp.txid];
      for(var j in unconf_list) {
        var item = unconf_list[j];
        if(mark[j]) {
          continue;
        }
        if(item.txtype == 0 && send_addrs[item.address] && item.txid_out == itemp.txid) {
          mark[j] = 1;
          itemp.ref = item;
          break;
        }
      }
    }
    for(var i in unconf_pop_list) {
      var itemp = unconf_pop_list[i];
      if(!itemp.ref) {
        var send_addrs = mytxs[itemp.txid];
        for(var j in unconf_list) {
          var item = unconf_list[j];
          if(item.txtype == 0 && send_addrs[item.address] && item.txid_out == itemp.txid) {
            itemp.ref = item;
            break;
          }
        }
      }
    }
    unconf_list = unconf_list.concat(unconf_pop_list);
    Ball.unconfs = unconf_list;
    update_balls_r();
    for(var i in unconf_list) {
      Ball.create_balls_task.push({type: 18, unconf: unconf_list[i]});
    }
    Ball.create_balls_task.push({type: 17});
    create_balls_worker();
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

  mouse.element.removeEventListener('mousewheel', mouse.mousewheel);
  mouse.element.removeEventListener('DOMMouseScroll', mouse.mousewheel);

  var touch_device_flag = ('ontouchstart' in window);
  var dragging = false;
  var dragging_body = null;
  Events.on(mouseConstraint, 'startdrag', function(e) {
    if(e.body.address) {
      var bc = e.body.utxo || e.body.unconf;
      if(bc.change == 0) {
        UtxoBalls.click_cb(e.body.address);
      } else {
        e.body.fluffy_free = true;
        setFluffyCollisionAll(e.body);
        fluffy_frees.push(e.body);
        fluffy_free_worker_start();
        Body.setAngularVelocity(e.body, 1.0);
      }
    }
    if(e.body.fluffy) {
      clearTimeout(e.body.fluffyback_tval);
      setFluffyCollisionAll(e.body);
    }
    if(touch_device_flag && !dragging) {
      show_ball_info(e.body);
      delay_hide_ball_info(4000);
    }
    dragging_body = e.body;
    dragging = true;
  });

  Events.on(mouseConstraint, 'enddrag', function(e) {
    if(e.body.fluffy) {
      e.body.fluffyback_tval = setTimeout(function() {
        setFluffyCollisionBack(e.body);
      }, 4000);
    }
    dragging = false;
    dragging_body = null;
  });

  var fluffy_frees = [];
  var fluffy_free_tval = null;
  var fluffy_free_active = false;
  function fluffy_free_worker() {
    var b = fluffy_frees.shift();
    while(b && !b.fluffy_free) {
      b = fluffy_frees.shift();
    }
    if(b) {
      b.fluffy_free = false;
      setFluffyCollisionBack(b);
      setTimeout(fluffy_free_worker, 100);
    } else {
      engine.world.gravity.y = 1;
      fluffy_free_active = false;
    }
  }

  function fluffy_free_worker_start() {
    if(!fluffy_free_active) {
      fluffy_free_active = true;
      engine.world.gravity.y = 0.5;
      setTimeout(fluffy_free_worker, 200);
    }
    clearTimeout(fluffy_free_tval);
    fluffy_free_tval = setTimeout(function() {
      fluffy_free_worker();
    }, 1000);
  }

  Events.on(engine, 'collisionStart', function(event) {
    if(dragging_body) {
      for(var i in event.pairs) {
        var pair = event.pairs[i];
        if(pair.bodyA == dragging_body && pair.bodyB.fluffy) {
          pair.bodyB.fluffy_free = true;
          setFluffyCollisionAll(pair.bodyB);
          fluffy_frees.push(pair.bodyB);
          fluffy_free_worker_start();
        } else if(pair.bodyB == dragging_body && pair.bodyA.fluffy) {
          pair.bodyA.fluffy_free = true;
          setFluffyCollisionAll(pair.bodyA);
          fluffy_frees.push(pair.bodyA);
          fluffy_free_worker_start();
        }
      }
    }
  });

  document.removeEventListener('mouseup', UtxoBalls.mouseup, false);
  UtxoBalls.mouseup = function(evt) {
    mouseConstraint.mouse.button = -1;
  }
  document.addEventListener('mouseup', UtxoBalls.mouseup, false);

  var cur_ball_id = -1;
  var ball_info_tval = null;
  $('#wallet-seg').mouseout(function() {
    $('#ball-info').fadeOut(800);
  });
  function show_ball_info(ball) {
    if(cur_ball_id != ball.id && ball.address && ball.value) {
      cur_ball_id = ball.id;
      var bc = ball.utxo || ball.unconf;
      var text = '';
      if(bc && bc.change == 1) {
        text = 'Change-' + Number(bc.index) + '<br>' + ball.value;
      } else {
        text = ball.address + '<br>' + ball.value;
      }
      $('#ball-info').html(text).css({left: ball.position.x + 28, top: ball.position.y - 100 - ball.circleRadius * 2 / 3}).stop(true, true).fadeTo(400, 1);
    } else if(cur_ball_id == ball.id) {
      $('#ball-info').css({left: ball.position.x + 28, top: ball.position.y - 100 - ball.circleRadius * 2 / 3});
    }
  }

  function hide_ball_info() {
    if(cur_ball_id != -1) {
      cur_ball_id = -1;
      $('#ball-info').fadeOut(800);
    }
  }
  function delay_hide_ball_info(delay) {
    clearTimeout(ball_info_tval);
    ball_info_tval = setTimeout(function() {
      if(cur_ball_id != -1) {
        cur_ball_id = -1;
        $('#ball-info').fadeOut(800);
      }
    }, delay || 5000);
  }
  Events.on(mouseConstraint, 'mousemove', function(e) {
    var foundPhysics = Matter.Query.point(Ball.bodies, e.mouse.position);
    if(foundPhysics.length == 1 && !dragging) {
      var ball = foundPhysics[0];
      show_ball_info(ball);
    } else {
      hide_ball_info();
    }
    delay_hide_ball_info();
  });

  Events.on(mouseConstraint, 'mousedown', function(e) {
    console.log('mousedown');
    if(window.getSelection) {
      if(window.getSelection().empty) {
        window.getSelection().empty();
      } else if(window.getSelection().removeAllRanges) {
        window.getSelection().removeAllRanges();
      }
    }
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

  function setFluffyCollisionAll(ball) {
    ball.fluffy_all = true;
    ball.collisionFilter.category = fluffy1 | fluffy2 | fluffy3;
    ball.collisionFilter.mask = defaultCategory | fluffy1 | fluffy2 | fluffy3;
  }

  function setFluffyCollisionBack(ball) {
    ball.fluffy_all = false;
    ball.collisionFilter.category = ball.fluffy;
    ball.collisionFilter.mask = defaultCategory | ball.fluffy;
  }

  function setsend(count) {
    console.log('setsend', Ball.prev_setsend_count, count);
    Ball.prev_setsend_count = count;
    var cnt = 0;
    var valid_cnt = 0;
    var utxos = Ball.utxos;
    for(var i in utxos) {
      var idx = create_bodies_idx({ballType: 0, utxo: utxos[i]});
      var ball = Ball.bodies_idx[idx];
      if(ball) {
        if(cnt < count) {
          setFluffy(ball, fluffy2);
          valid_cnt++;
        } else {
          setFluffy(ball, fluffy3);
        }
        cnt++;
      }
    }
    if(count > cnt) {
      Ball.too_much_balls_fluffy = fluffy2;
      if(Ball.too_much_balls) {
        setFluffy(Ball.too_much_balls, fluffy2);
      }
    } else {
      Ball.too_much_balls_fluffy = fluffy3;
      if(Ball.too_much_balls) {
        setFluffy(Ball.too_much_balls, fluffy3);
      }
    }
    return valid_cnt;
  }

  Events.on(engine, 'beforeUpdate', function(event) {
    var time = engine.timing.timestamp;
    for(var i in Ball.bodies) {
      var b = Ball.bodies[i];
      if(!b.rnd) {
        b.rnd = Math.random();
      }
      if(!b.fluffy_free) {
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
    for(var i in Ball.bodies_away) {
      Body.setVelocity(Ball.bodies_away[i], {x: 0, y: -2});
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

  if(UtxoBalls.resize_func) {
    clearTimeout(UtxoBalls.resize_tval);
    window.removeEventListener('resize', UtxoBalls.resize_func);
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
  window.addEventListener('resize', UtxoBalls.resize_func);

  if(UtxoBalls.visibility_func) {
    window.removeEventListener('visibilitychange', UtxoBalls.visibility_func, false);
  }
  UtxoBalls.visibility_func = function() {
    console.log(document.hidden, document.visibilityState);
    if(document.hidden) {
      stop();
    } else {
      start();
    }
  }
  window.addEventListener('visibilitychange', UtxoBalls.visibility_func, false);
  if(UtxoBalls.device_gamma_func) {
    window.removeEventListener('deviceorientation', UtxoBalls.device_gamma_func);
  }
  UtxoBalls.device_gamma_func = function(evt) {
    if(evt.gamma) {
      var rad = evt.gamma * Math.PI / 180;
      var gx = Math.sin(rad);
      var gy = Math.cos(rad);
      engine.world.gravity.x = gx;
      engine.world.gravity.y = gy;
    }
  }
  window.addEventListener('deviceorientation', UtxoBalls.device_gamma_func);

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
      update_balls: update_balls,
      unconfs: unconfs,
      setsend: setsend
    };
  } else {
    var obj = UtxoBalls.result_obj;
    obj.engine = engine;
    obj.runner = runner;
    obj.render = render;
    obj.canvas = render.canvas;
    obj.stop = stop;
    obj.update_balls = update_balls;
    obj.unconfs = unconfs;
    obj.setsend = setsend;
  }
  return UtxoBalls.result_obj;
}
