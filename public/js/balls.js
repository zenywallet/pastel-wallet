var Ball = Ball || {
  imageCache: {},
  getImage: function(name, size, label, nocache) {
    var cipher = pastel.cipher;
    if(nocache) {
      return DotMatrix.getImage(cipher.buf2hex(cipher.murmurhash((new TextEncoder).encode(name))), size, 1, label);
    }
    var id = name + '-' + size + '-' + label;
    if(!this.imageCache[id]) {
      this.imageCache[id] = DotMatrix.getImage(cipher.buf2hex(cipher.murmurhash((new TextEncoder).encode(name))), size, 1, label);
    }
    return this.imageCache[id];
  }
};

var UtxoBalls = function() {
  function sanitize(str) {
    if(/^[a-z0-9\.']+$/i.test(str)) {
      return String(str);
    }
    return '';
  }

  function conv_coin(uint64_val) {
    var strval = uint64_val.toString();
    var val = parseInt(strval, 10);
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

  var coin = coinlibs.coin;
  var network = coin.networks[pastel.config.network];
  var crypto = window.crypto || window.msCrypto;
  var pwa_mode = (window.matchMedia('(display-mode: standalone)').matches) || (window.navigator.standalone) || document.referrer.includes('android-app://');
  var touch_device_flag = ('ontouchstart' in window);
  var self = this;

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

  function simple() {
    _wallet_seg = _wallet_seg || document.getElementById('wallet-seg');
    _canvas = _canvas || document.querySelector('#wallet-seg canvas');
    var w = _wallet_seg.clientWidth - 14 * 2;
    var h = _wallet_seg.clientHeight - 14 * 2;
    _canvas.width = w;
    _canvas.height = h;
    var engine = Engine.create();
    var runner = Runner.create();
    var render = Render.create({
      element: _wallet_seg,
      engine: engine,
      runner: runner,
      canvas: _canvas,
      options: {
        width: w,
        height: h,
        wireframes: false,
        wireframeBackground: 'transparent',
        background: 'transparent'
      }
    });
    return render;
  }

  var _wallBodies = null;
  function craete_walls(w, h) {
    var wall_options = { isStatic: true, render: {
      fillStyle: 'transparent'
    }};
    var walls = [];
    walls.push(Bodies.rectangle(w / 2, -25 - 200, w, 50, wall_options));    // top
    walls.push(Bodies.rectangle(w / 2, h + 25, w, 50, wall_options));       // bottom
    walls.push(Bodies.rectangle(w + 25, h / 2, 50, h + 100, wall_options)); // right
    walls.push(Bodies.rectangle(-25, h / 2, 50, h + 100, wall_options));    // left
    return walls;
  }

  var defaultCategory = 0x0001;
  var fluffy1 = 0x0002;
  var fluffy2 = 0x0004;
  var fluffy3 = 0x0008;
  var fluffy4 = 0x0010;
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
  function setFluffyFree(ball, fluffy) {
    ball.fluffy = fluffy;
    ball.collisionFilter.category = defaultCategory;
    ball.collisionFilter.mask = fluffy;
  }

  var _ballInfos = {};
  var _ballBodies = [];
  var _ballBodiesIdx = {};
  var _ballBodiesAway = [];
  var _utxos = [];
  var _unconfs = [];

  var ballType = {
    utxo: 1,
    unconf: 2,
    too_much: 3
  };

  function create_bodies_idx(body) {
    switch(body.ballType) {
      case ballType.utxo:
      case ballType.unconf:
        var data = body.ballData;
        var idx = data.txid + '-' + data.n + '-' + data.address + '-' + data.value;
        return idx;
      case ballType.too_much:
        var idx = body.ballType;
        return idx;
      default:
        return 'unknown';
    }
  }
  function add_bodies_idx(body) {
    var idx = create_bodies_idx(body);
    _ballBodiesIdx[idx] = body;
  }
  function remove_bodies_idx(body) {
    var idx = create_bodies_idx(body);
    delete _ballBodiesIdx[idx];
  }

  function calc_ball_diameter(data) {
    var s = Math.ceil(cur_balls_r * data.cr);
    var s_max = _canvas.width > _canvas.height ? _canvas.height / 12 : _canvas.width / 12;
    if(s > s_max) {
      s = s_max;
    }
    return s;
  }
  function calc_ball_radius(data) {
    return calc_ball_diameter(data) / 2;
  }
  function create_ball(type, data, options) {
    var address = sanitize(data.address);
    var s = calc_ball_diameter(data);
    var x = options.x || Math.round(Math.random() * (_canvas.width - s) + s / 2);
    var y = options.y || Math.round(Math.random() * (s - 200) - s / 2);
    var fluffy =  options.fluffy || fluffy3;
    var ball = Bodies.circle(x, y, s / 2, {
      ballType: type,
      ballData: data,
      label: 'ball',
      address: address,
      value: data.value_d,
      restitution: 0.3,
      frictionAir: 0.03,
      angle: options.angle || 0,
      fluffy: fluffy,
      collisionFilter: {
        category: fluffy,
        mask: defaultCategory | fluffy
      },
      render: {
        sprite: {
          texture: Ball.getImage(address, 64),
          xScale: s / 64,
          yScale: s / 64,
          imgsize: 64
        }
      }
    });
    return ball;
  }
  function create_too_much_ball(options) {
    var s2 = _canvas.width >_canvas.height ? (_canvas.height / 6) : (_canvas.width / 6);
    if(s2 < 80) {
      s2 = 80;
    }
    var x = options.x || Math.round(Math.random() * (_canvas.width - s2) + s2 / 2);
    var y = options.y || -60;
    var fluffy = options.fluffy || fluffy3;
    var ball = Bodies.circle(x, y, s2 / 2, {
      ballType: ballType.too_much,
      ballData: null,
      label: 'ball',
      address: null,
      value: null,
      restitution: 0.3,
      frictionAir: 0.03,
      angle: options.angle || 0,
      fluffy: fluffy,
      collisionFilter: {
        category: fluffy,
        mask: defaultCategory | fluffy
      },
      render: {
        sprite: {
          texture: Ball.getImage(String(200), 160, __t('Too Much Balls'), true),
          xScale: s2 / 160,
          yScale: s2 / 160,
          imgsize: 160
        }
      }
    });
    return ball;
  }

  var utxo_ball_max = 140;
  var unconf_ball_max = 160;

  var valid_utxos = [];
  var valid_unconfs = [];
  var full_utxos = [];
  var full_unconfs = [];
  var full_unconfs_idx = {};
  var cur_balls_r = 0;
  var calc_balls_r = function() {
    if(valid_utxos.length > 0 || valid_unconfs.length > 0) {
      var ave = 0.0;
      var sd = 0.0;
      var len = valid_utxos.length + valid_unconfs.length;
      if(len > 1) {
        for(var i in valid_utxos) {
          ave += valid_utxos[Number(i)].r;
        }
        for(var i in valid_unconfs) {
          ave += valid_unconfs[Number(i)].r;
        }
        ave /= len;
        for(var i in valid_utxos) {
          var d = valid_utxos[Number(i)].r - ave;
          sd += d * d;
        }
        for(var i in valid_unconfs) {
          var d = valid_unconfs[Number(i)].r - ave;
          sd += d * d;
        }
        sd = Math.sqrt(sd / (len - 1));
        if(sd > 0) {
          for(var i in valid_utxos) {
            var cr = 36 + 28 * (valid_utxos[Number(i)].r - ave) / (1.5 * sd);
            if(cr > 64) {
              cr = 64;
            } else if(cr < 8) {
              cr = 8;
            }
            valid_utxos[Number(i)].cr = cr;
          }
          for(var i in valid_unconfs) {
            var cr = 36 + 28 * (valid_unconfs[Number(i)].r - ave) / (1.5 * sd);
            if(cr > 64) {
              cr = 64;
            } else if(cr < 8) {
              cr = 8;
            }
            valid_unconfs[Number(i)].cr = cr;
          }
        } else {
          for(var i in valid_utxos) {
            valid_utxos[Number(i)].cr = 36;
          }
          for(var i in valid_unconfs) {
            valid_unconfs[Number(i)].cr = 36;
          }
        }
      } else {
        for(var i in valid_utxos) {
          valid_utxos[Number(i)].cr = 36;
        }
        for(var i in valid_unconfs) {
          valid_unconfs[Number(i)].cr = 36;
        }
      }
      var ss = 0;
      for(var i in valid_utxos) {
        var cr = valid_utxos[Number(i)].cr;
        ss += cr * cr;
      }
      for(var i in valid_unconfs) {
        var cr = valid_unconfs[Number(i)].cr;
        ss += cr * cr;
      }
      var prev = cur_balls_r;
      var a = len > utxo_ball_max ? utxo_ball_max : len;
      var v = -9 / utxo_ball_max * a + 12;
      cur_balls_r = Math.sqrt(((_canvas.width * _canvas.height) / v) / ss);
      if(prev != cur_balls_r) {
        return true;
      }
    }
    return false;
  }

  var _ballTask = [];
  var taskType = {
    utxos: 1,
    unconfs: 2,
    utxos_start: 3,
    utxo: 4,
    utxos_end: 5,
    unconfs_start: 6,
    unconf: 7,
    unconfs_end: 8,
    too_much_utxos: 9,
    too_much_unconfs: 10,
    absorb: 11
  };
  var create_balls_worker_tval = null;
  function create_balls_worker() {
    clearTimeout(create_balls_worker_tval);
    clearTimeout(check_too_much_balls_tval);
    var task = _ballTask.shift();
    if(!task) {
      check_too_much_balls_tval = setTimeout(check_too_much_balls, 3000);
      return;
    }
    switch(task.type) {
      case taskType.utxos:
        _ballTask.push({type: taskType.utxos_start});
        var count = 0;
        var left = utxo_ball_max;
        if(valid_unconfs.length > utxo_ball_max) {
          left -= valid_unconfs.length - utxo_ball_max;
        }
        if(left > 0) {
          valid_utxos = task.data.slice(0, left);
        } else {
          valid_utxos = [];
        }
        full_utxos = task.data;
        var too_much = full_utxos.length > utxo_ball_max;
        for(var i in valid_utxos) {
          var utxo = valid_utxos[Number(i)];
          utxo.value_d = conv_coin(sanitize(utxo.value))
          utxo.s = parseFloat(utxo.value_d);
          utxo.r = Math.sqrt(utxo.s);
        }
        var r_changed = calc_balls_r();
        for(var i in valid_utxos) {
          _ballTask.push({type: taskType.utxo, data: valid_utxos[Number(i)]});
        }
        if(r_changed) {
          for(var i in valid_unconfs) {
            _ballTask.push({type: taskType.unconf, data: valid_unconfs[Number(i)]});
          }
        }
        _ballTask.push({type: taskType.utxos_end});
        if(too_much) {
          _ballTask.push({type: taskType.too_much_utxos});
        }
        break;
      case taskType.unconfs:
        _ballTask.push({type: taskType.unconfs_start});
        var count = 0;
        var valid_unconfs_tmp = [];
        var add_list = {};
        full_unconfs = task.data;
        for(var i in full_unconfs) {
          var idx = create_bodies_idx({ballType: ballType.utxo, ballData: full_unconfs[i]});
          var ball = _ballBodiesIdx[idx];
          if(ball) {
            valid_unconfs_tmp.push(full_unconfs[i]);
            add_list[i] = 1;
          }
          if(valid_unconfs_tmp.length >= unconf_ball_max) {
            break;
          }
        }
        for(var i = full_unconfs.length - 1; i >= 0; i--) {
          if(valid_unconfs_tmp.length >= unconf_ball_max) {
            break;
          }
          if(!add_list[i]) {
            valid_unconfs_tmp.push(full_unconfs[i]);
          }
        }
        valid_unconfs = valid_unconfs_tmp;
        full_unconfs_idx = {};
        for(var i in full_unconfs) {
          var data = full_unconfs[i];
          var idx = data.txid + '-' + data.n + '-' + data.address + '-' + data.value;
          full_unconfs_idx[idx] = data;
        }
        var too_much = full_unconfs.length > unconf_ball_max;
        for(var i in valid_unconfs) {
          var unconf = valid_unconfs[Number(i)];
          unconf.value_d = conv_coin(sanitize(unconf.value))
          unconf.s = parseFloat(unconf.value_d);
          unconf.r = Math.sqrt(unconf.s);
        }
        var r_changed = calc_balls_r();
        for(var i in valid_unconfs) {
          _ballTask.push({type: taskType.unconf, data: valid_unconfs[Number(i)]});
        }
        if(r_changed) {
          for(var i in valid_utxos) {
            _ballTask.push({type: taskType.utxo, data: valid_utxos[Number(i)]});
          }
        }
        _ballTask.push({type: taskType.unconfs_end});
        _ballTask.push({type: taskType.too_much_unconfs, data: too_much});
        break;
      case taskType.utxos_start:
        for(var i in _ballBodies) {
          var ball = _ballBodies[Number(i)];
          if(ball.ballType == ballType.utxo) {
            ball.mark_utxo = 1;
          }
        }
        break;
      case taskType.utxo:
        var idx = create_bodies_idx({ballType: ballType.utxo, ballData: task.data});
        var ball = _ballBodiesIdx[idx];
        if(ball) {
          ball.mark_utxo = 0;
          if(ball.circleRadius != calc_ball_radius(task.data)) {
            ball.ballData.cr = task.data.cr;
            var new_ball = create_ball(ball.ballType, ball.ballData, {
              fluffy: ball.fluffy,
              x: ball.position.x, y: ball.position.y, angle: ball.angle
            });
            for(var i in _ballBodies) {
              if(ball == _ballBodies[Number(i)]) {
                _ballBodies[Number(i)] = new_ball;
                break;
              }
            }
            add_bodies_idx(new_ball);
            Matter.Composite.remove(_world, ball);
            World.add(_world, new_ball);
          }
        } else {
          ball = create_ball(ballType.utxo, task.data, {fluffy: fluffy3});
          //ball.mark_utxo = 0;
          if(too_much_balls) {
            var tb = too_much_balls;
            var r = tb.circleRadius / 3 * (Math.random() - 0.5);
            Body.setPosition(ball, {x: tb.position.x + r, y: tb.position.y - tb.circleRadius / 2});
            Body.setVelocity(ball, {x: r, y: -5});
            Body.setAngularVelocity(ball, Math.PI / 6 * (Math.random() - 0.5));
          }
          _ballBodies.push(ball);
          add_bodies_idx(ball);
          World.add(_world, ball);
        }
        break;
      case taskType.utxos_end:
        for(var i = _ballBodies.length - 1; i >= 0; i--) {
          var ball = _ballBodies[Number(i)];
          if(ball.ballType == ballType.utxo && ball.mark_utxo == 1) {
            setFluffyFree(ball, fluffy4);
          }
        }
        updateSend_cb();
        break;
      case taskType.unconfs_start:
        for(var i in _ballBodies) {
          var ball = _ballBodies[Number(i)];
          if(ball.ballType == ballType.unconf) {
            ball.mark_unconf = 1;
          }
        }
        break;
      case taskType.unconf:
        var idx = create_bodies_idx({ballType: ballType.unconf, ballData: task.data});
        var ball = _ballBodiesIdx[idx];
        if(ball) {
          ball.mark_utxo = 0;
          ball.mark_unconf = 0;
          ball.ballType = ballType.unconf;
          if(task.data.txid_out) {
            ball.ballData.txid_out = task.data.txid_out;
          }
          if(task.data.ref) {
            ball.ballData.ref = task.data.ref;
          }
          if(ball.circleRadius != calc_ball_radius(task.data)) {
            ball.ballData.cr = task.data.cr;
            var new_ball = create_ball(ball.ballType, ball.ballData, {fluffy: fluffy1, x: ball.position.x, y: ball.position.y, angle: ball.angle});
            for(var i in _ballBodies) {
              if(ball == _ballBodies[Number(i)]) {
                _ballBodies[Number(i)] = new_ball;
                break;
              }
            }
            add_bodies_idx(new_ball);
            Matter.Composite.remove(_world, ball);
            World.add(_world, new_ball);
          } else {
            setFluffy(ball, fluffy1);
          }
        } else {
          ball = create_ball(ballType.unconf, task.data, {fluffy: fluffy1});
          if(task.data.ref) {
            var ref = task.data.ref;
            var idx_ref = create_bodies_idx({ballType: ballType.unconf, ballData: ref});
            var ball_ref = _ballBodiesIdx[idx_ref];
            if(ball_ref) {
              setTimeout(function() {
                var rx = 3 * (Math.random() - 0.5);
                var ry = Math.random() + 0.5;
                ball.fluffy_free = true;
                setFluffyCollisionAll(ball);
                fluffy_frees.push(ball);
                fluffy_free_worker_start();
                var cur_ball_ref = _ballBodiesIdx[idx_ref];
                if(cur_ball_ref) {
                  ball_ref = cur_ball_ref;
                }
                Body.setPosition(ball, {x: ball_ref.position.x, y: ball_ref.position.y + 5});
                Body.setVelocity(ball, {x: rx, y: ry});
                Body.setAngularVelocity(ball, Math.PI / 6 * (Math.random() - 0.5));
                World.add(_world, ball);
              }, 1000);
              _ballBodies.push(ball);
              add_bodies_idx(ball);
            } else {
              _ballBodies.push(ball);
              add_bodies_idx(ball);
              World.add(_world, ball);
            }
          } else {
            _ballBodies.push(ball);
            add_bodies_idx(ball);
            World.add(_world, ball);
          }
        }
        break;
      case taskType.unconfs_end:
        var utxo_update = false;
        for(var i = _ballBodies.length - 1; i >= 0; i--) {
          var ball = _ballBodies[Number(i)];
          if(ball.ballType == ballType.unconf && ball.mark_unconf == 1) {
            ball.mark_unconf = 0;
            utxo_update = true;
            if(ball.ballData.txtype == 1 && !ball.ballData.txid_out) {
              ball.mark_utxo = 0;
              ball.ballType = ballType.utxo;
              if(ball.fluffy == fluffy1) {
                var idx = create_bodies_idx(ball);
                if(full_unconfs_idx[idx]) {
                  setFluffyFree(ball, fluffy4);
                } else {
                  setFluffy(ball, fluffy3);
                }
              }
            } else {
              _ballBodiesAway.push(ball);
              remove_bodies_idx(ball);
              _ballBodies.splice(i, 1);
              setTimeout(function() {
                Matter.Composite.remove(_world, _ballBodiesAway.shift());
              }, 6000);
            }
          }
        }
        if(utxo_update) {
          console.log('request unspents');
          pastel.send({cmd: 'unspents'});
        }
        break;
      case taskType.too_much_utxos:
        break;
      case taskType.too_much_unconfs:
        if(task.data && full_unconfs.length > unconf_ball_max) {
          too_much_balls_fluffy = fluffy1;
          if(too_much_balls) {
            setFluffy(too_much_balls, fluffy1);
          }
        } else {
          too_much_balls_fluffy = fluffy3;
          if(too_much_balls) {
            setFluffy(too_much_balls, fluffy3);
          }
        }
        break;
      case taskType.absorb:
        var ball = task.data;
        Matter.Composite.remove(_world, ball);
        remove_bodies_idx(ball);
        for(var i = _ballBodies.length - 1; i >= 0; i--) {
          if(ball == _ballBodies[i]) {
            _ballBodies.splice(i, 1);
            break;
          }
        }
        break;
      default:
        break;
    }
    create_balls_worker_tval = setTimeout(create_balls_worker, 10);
  }

  this.setUtxos = function(data) {
    _utxos = data;
    _ballTask.push({type: taskType.utxos, data: data});
    self.start();
    create_balls_worker();

  }
  this.setUnconfs = function(data) {
    var mytxs = {};
    for(var txid in data.txs) {
      var tx = data.txs[txid];
      var send_addrs = {};
      for(var txa in tx.data) {
        var v = tx.data[txa];
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
    var spents_unconfs = {};
    for(var addr in data.addrs) {
      var val = data.addrs[addr];
      if(val.spents) {
        for(i in val.spents) {
          var spent = val.spents[Number(i)];
          var item = {txtype: 0, address: addr, txid: spent.txid, n: spent.n,
            value: spent.value, change: val.change, index: val.index,
            xpub_idx: val.xpub_idx, trans_time: spent.trans_time,
            txid_out: spent.txid_out};
          unconf_list.push(item);
          spents_unconfs[spent.txid + '-' + spent.n] = spent.txid_out;
        }
      }
    }
    for(var addr in data.addrs) {
      var val = data.addrs[addr];
      if(val.txouts) {
        for(i in val.txouts) {
          var txout = val.txouts[Number(i)];
          var item = {txtype: 1, address: addr, txid: txout.txid, n: txout.n,
            value: txout.value, change: val.change, index: val.index,
            xpub_idx: val.xpub_idx, trans_time: txout.trans_time};
          var unconf_tx = spents_unconfs[txout.txid + '-' + txout.n];
          if(unconf_tx) {
            item.txid_out = unconf_tx;
          }
          if(mytxs[txout.txid]) {
            unconf_pop_list.push(item);
          } else {
            unconf_list.push(item);
          }
        }
      }
    }

    var myaddrs = {};
    for(var addr in data.addrs) {
      myaddrs[addr] = 1;
    }
    for(var txid in data.txs) {
      var tx = data.txs[txid];
      var mycnt = 0;
      var external_tx_addrs = [];
      for(var txa in tx.data) {
        var v = tx.data[txa];
        for(var i in v) {
          if(myaddrs[txa]) {
            if(i == 0) {
              mycnt++;
            }
          } else {
            if(i == 1) {
              external_tx_addrs.push({txtype: i, address: txa, txid: txid, value: v[i], trans_time: tx.trans_time});
            }
          }
        }
      }
      if(mycnt > 0) {
        unconf_pop_list = unconf_pop_list.concat(external_tx_addrs);
      }
    }

    var mark = {};
    for(var i in unconf_pop_list) {
      var itemp = unconf_pop_list[Number(i)];
      var send_addrs = mytxs[itemp.txid];
      for(var j in unconf_list) {
        var item = unconf_list[Number(j)];
        if(mark[Number(j)]) {
          continue;
        }
        if(item.txtype == 0 && send_addrs[item.address] && item.txid_out == itemp.txid) {
          mark[Number(j)] = 1;
          itemp.ref = item;
          break;
        }
      }
    }
    for(var i in unconf_pop_list) {
      var itemp = unconf_pop_list[Number(i)];
      if(!itemp.ref) {
        var send_addrs = mytxs[itemp.txid];
        for(var j in unconf_list) {
          var item = unconf_list[Number(j)];
          if(item.txtype == 0 && send_addrs[item.address] && item.txid_out == itemp.txid) {
            itemp.ref = item;
            break;
          }
        }
      }
    }
    unconf_list = unconf_list.concat(unconf_pop_list);
    unconf_list.sort(function(a, b) {
      var cmp = a.trans_time - b.trans_time;
      if(cmp == 0) {
        if(a.xpub_idx != null && b.xpub_idx != null) {
          cmp = a.xpub_idx - b.xpub_idx;
          if(cmp == 0) {
            cmp = a.txtype - b.txtype;
            if(cmp == 0) {
              cmp = a.change - b.change;
              if(cmp == 0) {
                cmp = a.index - b.index;
                if(cmp == 0) {
                  cmp = a.txid - b.txid;
                  if(cmp == 0) {
                    cmp = a.n - b.n;
                  }
                }
              }
            }
          }
        } else if(a.xpub_idx == null && b.xpub_idx != null) {
          cmp = -1;
        } else if(a.xpub_idx != null && b.xpub_idx == null) {
          cmp = 1;
        } else {
          if(cmp == 0) {
            cmp = a.txtype - b.txtype;
            if(cmp == 0) {
              cmp = a.txid - b.txid;
            }
          }
        }
      }
      return cmp;
    });
    _unconfs = unconf_list;
    _ballTask.push({type: taskType.unconfs, data: unconf_list});
    self.start();
    create_balls_worker();
  }

  function resetPosition(ball) {
    var s = ball.circleRadius * 2;
    var x = Math.round(Math.random() * (_canvas.width - s) + s / 2);
    var y = Math.round(Math.random() * (s - 200) - s / 2);
    Body.setPosition(ball, {x: x, y: y});
  }

  function check_out(ball) {
    if(ball.position.x < - 25 || ball.position.x > _canvas.width + 25
      || ball.position.y < -25 || ball.position.y > _canvas.height + 25) {
      return true;
    }
    return false;
  }

  var check_out_balls_tval = null;
  function check_out_balls() {
    var find = false;
    for(var i in _ballBodies) {
      var b = _ballBodies[Number(i)];
      if(b.fluffy != fluffy3) {
        if(check_out(b)) {
          find = true;
          resetPosition(b);
          break;
        }
      }
      if(b.position.y > _canvas.height + 25) {
        find = true;
        if(b.position.y > 5000) {
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

  var dragging = false;
  var dragging_body = null;
  function disable_pointer_event() {
    $('#wallet-balance .balance, #wallet-balance .ui.label, #send-coins .ui.label, #send-coins .ui.buttons, #send-coins .ui.input, #receive-address .ui.label, #receive-address .ui.buttons, #address-text, #receive-address .ui.ball img').css('pointer-events', 'none');
  }
  function enable_pointer_event() {
    $('#wallet-balance .balance, #wallet-balance .ui.label, #send-coins .ui.label, #send-coins .ui.buttons, #send-coins .ui.input, #receive-address .ui.label, #receive-address .ui.buttons, #address-text, #receive-address .ui.ball img').css('pointer-events', 'auto');
  }

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
      _world.gravity.y = 1;
      fluffy_free_active = false;
    }
  }
  function fluffy_free_worker_start() {
    if(!fluffy_free_active) {
      fluffy_free_active = true;
      _world.gravity.y = 0.5;
      setTimeout(fluffy_free_worker, 200);
    }
    clearTimeout(fluffy_free_tval);
    fluffy_free_tval = setTimeout(function() {
      fluffy_free_worker();
    }, 1000);
  }

  var cur_ball_id = -1;
  var ball_info_tval = null;
  $('#wallet-seg').mouseout(function() {
    $('#ball-info').fadeOut(800);
  });
  function show_ball_info(ball) {
    if(cur_ball_id != ball.id && ball.address && ball.value) {
      cur_ball_id = ball.id;
      var data = ball.ballData;
      var text = '';
      if(data && data.change == 1) {
        text = __t('Change-') + Number(data.index) + '<br>' + ball.value;
      } else {
        text = ball.address + '<br>' + ball.value;
      }
      $('#ball-info').html(text).css({left: ball.position.x + 28, top: ball.position.y + 120 + (20 + ball.circleRadius * 2 / 3) * (ball.position.y < 100 ? 1 : -1)}).stop(true, true).fadeTo(400, 1);
    } else if(cur_ball_id == ball.id) {
      $('#ball-info').css({left: ball.position.x + 28, top: ball.position.y + 120 + (20 + ball.circleRadius * 2 / 3) * (ball.position.y < 100 ? 1 : -1)});
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


  var too_much_balls_enable = false;
  var too_much_balls = null;
  var too_much_balls_fluffy = null;
  var check_too_much_balls_tval = null;
  function check_too_much_balls() {
    if(full_utxos.length > utxo_ball_max || full_unconfs.length > unconf_ball_max) {
      if(!too_much_balls_enable) {
        too_much_balls_enable = true;
        var fluffy = fluffy3;
        var ball = create_too_much_ball({fluffy: fluffy});
        _ballBodies.push(ball);
        add_bodies_idx(ball);
        too_much_balls = ball;
        World.add(_world, ball);
        if(too_much_balls_fluffy != null && too_much_balls_fluffy != fluffy3) {
          var retry = 0;
          function worker() {
            if(ball.position.y > 120) {
              setFluffy(ball, too_much_balls_fluffy);
            } else {
              if(retry < 30) {
                setTimeout(worker, 100);
                retry++;
              }
            }
          }
          worker();
        }
      }
    } else {
      if(too_much_balls_enable) {
        if(too_much_balls) {
          for(var i = _ballBodies.length - 1; i >= 0; i--) {
            if(too_much_balls == _ballBodies[Number(i)]) {
             _ballBodies.splice(i, 1);
              break;
            }
          }
          Matter.Composite.remove(_world, too_much_balls);
          too_much_balls = null;
          too_much_balls_enable = false;
        }
      }
    }
  }

  var _render = null;
  var _world = null;
  var _canvas = null;
  var _wallet_seg = null;
  var _mouseConstraint = null;
  var _active = false;
  this.start = function() {
    if(!_render) {
      _render = simple();
      if(!_render) {
        return;
      }

      _world = _render.engine.world;
      Render.lookAt(_render, {
        min: { x: 0, y: 0 },
        max: { x: _canvas.width, y: _canvas.height }
      });

      _wallBodies = craete_walls(_canvas.width, _canvas.height);
      World.add(_world, _wallBodies);

      var mouse = Mouse.create(_canvas);
      mouse.element.removeEventListener('mousewheel', mouse.mousewheel);
      mouse.element.removeEventListener('DOMMouseScroll', mouse.mousewheel);
      var mouseConstraint = MouseConstraint.create(_render.engine, {
        mouse: mouse,
        constraint: {
          stiffness: 0.2,
          render: {
            visible: false
          }
        }
      });
      _mouseConstraint = mouseConstraint;
      Events.on(mouseConstraint, 'startdrag', function(e) {
        if(e.body.address) {
          if(e.body.ballData.change == 0) {
            click_cb(e.body.address);
            clearTimeout(e.body.fluffyback_tval);
            setFluffyCollisionAll(e.body);
          } else {
            e.body.fluffy_free = true;
            Body.setAngularVelocity(e.body, 1.0);
            setTimeout(function() {
              e.body.fluffy_free = false;
              clearTimeout(e.body.fluffyback_tval);
              setFluffyCollisionAll(e.body);
            }, 200);
          }
        } else if(e.body.fluffy) {
          clearTimeout(e.body.fluffyback_tval);
          setFluffyCollisionAll(e.body);
        }
        if(touch_device_flag && !dragging) {
          show_ball_info(e.body);
          delay_hide_ball_info(4000);
        }
        disable_pointer_event();
        dragging_body = e.body;
        dragging = true;
      });
      Events.on(mouseConstraint, 'enddrag', function(e) {
        if(e.body.fluffy) {
          e.body.fluffyback_tval = setTimeout(function() {
            setFluffyCollisionBack(e.body);
          }, 4000);
        }
        enable_pointer_event();
        dragging = false;
        dragging_body = null;
      });
      Events.on(mouseConstraint, 'mousemove', function(e) {
        var foundPhysics = Matter.Query.point(_ballBodies, e.mouse.position);
        if(foundPhysics.length == 1 && !dragging) {
          var ball = foundPhysics[0];
          show_ball_info(ball);
        } else {
          hide_ball_info();
        }
        delay_hide_ball_info();
      });
      Events.on(mouseConstraint, 'mousedown', function(e) {
        if(window.getSelection) {
          if(window.getSelection().empty) {
            window.getSelection().empty();
          } else if(window.getSelection().removeAllRanges) {
            window.getSelection().removeAllRanges();
          }
        }
      });
      World.add(_world, mouseConstraint);

      Events.on(_render.engine, 'beforeUpdate', function(event) {
        var time = _render.engine.timing.timestamp;
        var rect = {y: 137}; //_render.element.getBoundingClientRect();
        for(var i = _ballBodies.length - 1; i >= 0; i--) {
          var b = _ballBodies[Number(i)];
          if(!b.rnd) {
            b.rnd = Math.random();
          }
          if(!b.fluffy_free) {
            switch(b.fluffy) {
              case fluffy1:
                var vy = (rect.y - 200 + 64 - b.position.y) / 10 + (b.rnd + 0.5) * Math.sin((b.rnd * 1000 + time) * (0.001 + b.rnd * 2 / 1000));
                if(vy < -10) {
                  vy = -10;
                } else if (vy > 10) {
                  vy = 10;
                }
                Body.setVelocity(b, {x: 0, y: vy});
                Body.setAngularVelocity(b, (b.rnd * 2 - 1) / 30);
                break;
              case fluffy2:
                var vy = (rect.y + 64 - b.position.y) / 10 + (b.rnd + 0.5) * Math.sin((b.rnd * 1000 + time) * (0.001 + b.rnd * 3 / 1000));
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
          if(b.fluffy == fluffy4 && too_much_balls) {
            var vx = too_much_balls.position.x - b.position.x;
            var vy = too_much_balls.position.y - b.position.y;
            var vxa = Math.abs(vx);
            var vya = Math.abs(vy);
            var ratio = vxa > vya ? vxa : vya;
            var ratio2 = ratio / 6;
            var accel = ratio > 300 ? 1 : 300 / ratio;
            if(ratio > too_much_balls.circleRadius) {
              Body.setVelocity(b, {x: vx / ratio2 * accel, y: vy / ratio2 * accel});
            } else {
              if(ratio > too_much_balls.circleRadius / 2) {
                Body.setVelocity(b, {x: vx / ratio, y: vy / ratio});
              } else {
                _ballTask.push({type: taskType.absorb, data: b});
                create_balls_worker();
                Body.setVelocity(too_much_balls, {x: vx / ratio, y: vy / ratio + 4});
                Body.setAngularVelocity(too_much_balls, (vx > 0 ? 1 : -1) / 30);
              }
            }
          }
        }
        for(var i in _ballBodiesAway) {
          Body.setVelocity(_ballBodiesAway[Number(i)], {x: 0, y: -2});
        }
      });
      Events.on(_render.engine, 'collisionStart', function(event) {
        if(dragging_body) {
          for(var i in event.pairs) {
            var pair = event.pairs[Number(i)];
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

      Runner.run(_render.runner, _render.engine);
      Render.run(_render);
      check_out_balls();
      _active = true;
    }
  }

  this.stop = function() {
    if(_render) {
      clearTimeout(check_out_balls_tval);
      _active = false;
      Runner.stop(_render.runner);
      Render.stop(_render);
      _render = null;
      _world = null;
    }
  }

  this.resume = function() {
    if(_render) {
      Runner.run(_render.runner, _render.engine);
      Render.run(_render);
      check_out_balls();
      _active = true;
    }
  }

  this.pause = function() {
    if(_render) {
      clearTimeout(check_out_balls_tval);
      _active = false;
      Runner.stop(_render.runner);
      Render.stop(_render);
    }
  }

  var click_cb = function() {};
  this.click = function(cb) {
    click_cb = cb;
  }

  var updateSend_cb = function() {};
  this.updateSend = function(cb) {
    updateSend_cb = cb;
  }

  var prev_setsend_count = 0;
  this.setSend = function(count) {
    prev_setsend_count = count;
    var cnt = 0;
    var valid_cnt = 0;
    for(var i in full_utxos) {
      var idx = create_bodies_idx({ballType: ballType.utxo, ballData: full_utxos[Number(i)]});
      var ball = _ballBodiesIdx[idx];
      if(ball && ball.ballType == ballType.utxo) {
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
      too_much_balls_fluffy = fluffy2;
      if(too_much_balls) {
        setFluffy(too_much_balls, fluffy2);
      }
    } else {
      too_much_balls_fluffy = fluffy3;
      if(too_much_balls) {
        setFluffy(too_much_balls, fluffy3);
      }
    }
    return valid_cnt;
  }

  function reset_balls_position() {
    var prev_w = _canvas.width;
    var prev_h = _canvas.height;
    var w = _render.element.clientWidth - 14 * 2;
    var h = _render.element.clientHeight - 14 * 2;
    if(prev_w == w && prev_h == h) {
      return;
    }
    self.stop();
    self.start();
    calc_balls_r();
    w = _canvas.width;
    h = _canvas.height;

    for(var i in _ballBodies) {
      var ball = _ballBodies[Number(i)];
      var x = ball.position.x * w / prev_w;
      var y = ball.position.y * h / prev_h;
      if(x < 0) {
        x = 25 + 50 * Math.random();
      } else if(x > _canvas.width - 25) {
        x = _canvas.width - 25 - 50 * Math.random();
      }
      if(y < 15) {
        y = 15;
      } else if(y > _canvas.height - 25) {
        y = _canvas.height - 25;
      }
      var new_ball;
      if(ball.ballType == ballType.too_much) {
        new_ball = create_too_much_ball({fluffy: ball.fluffy, x: x, y: y, angle: ball.angle});
        too_much_balls = new_ball;
      } else {
        new_ball = create_ball(ball.ballType, ball.ballData, {fluffy: ball.fluffy, x: x, y: y, angle: ball.angle});
      }
      _ballBodies[Number(i)] = new_ball;
      add_bodies_idx(new_ball);
      Matter.Composite.remove(_world, ball);
      World.add(_world, new_ball);
    }
  }

  var resize_tval = null;
  function resize_func() {
    if(pwa_mode || !_render) {
      return;
    }
    clearTimeout(resize_tval);
    reset_balls_position();
    resize_tval = setTimeout(function() {
      reset_balls_position();
    }, 1400);
  }
  window.addEventListener('resize', resize_func);

  function device_gamma_func(evt) {
    if(_active && evt.gamma) {
      var rad = evt.gamma * Math.PI / 180;
      var gx = Math.sin(rad);
      var gy = Math.cos(rad);
      _world.gravity.x = gx;
      _world.gravity.y = gy;
    }
  }
  window.addEventListener('deviceorientation', device_gamma_func);

  var pause_state = false;
  function visibility_func() {
    if(document.hidden) {
      if(!pause_state) {
        pause_state = true;
        self.pause();
        window.removeEventListener('deviceorientation', device_gamma_func);
        window.removeEventListener('resize', resize_func);
      }
    } else {
      if(pause_state) {
        resize_func();
        self.resume();
        window.addEventListener('resize', resize_func);
        window.addEventListener('deviceorientation', device_gamma_func);
        pause_state = false;
      }
    }
  }
  window.addEventListener('visibilitychange', visibility_func);

  function mouseup_func() {
    if(_mouseConstraint) {
      _mouseConstraint.mouse.button = -1;
      visibility_func();
    }
  }
  document.addEventListener('mouseup', mouseup_func);
}
