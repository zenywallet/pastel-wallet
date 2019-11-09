var Ball = Ball || {};
Ball.cache = Ball.cache || {};
Ball.get = function(name, size, label) {
  var cipher = pastel.cipher;
  var id = name + size + label;
  if(!this.cache[id]) {
    this.cache[id] = DotMatrix.getImage(cipher.buf2hex(cipher.murmurhash((new TextEncoder).encode(name))), size, 1, label);
  }
  return this.cache[id];
}

var UtxoBalls = UtxoBalls || {};
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
    Events = Matter.Events,
    Query = Matter.Query;

  var engine = Engine.create();
  var world = engine.world;

  var w = target_elm.clientWidth - 14 * 2;
  var h = target_elm.clientHeight - 14 * 2;

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
  var network = coin.networks.bitzeny;
  var crypto = window.crypto || window.msCrypto;

  function sanitize(str) {
    if(/^[a-z0-9\.']+$/i.test(str)) {
      return String(str);
    }
    return '';
  }

  var bodies = [];
  var image_count = 0;
  for(var i = 0; i < 120; i++) {
    var s = Math.round(Math.random() * 28 + 8);
    var x = Math.round(Math.random() * (w - s) + s / 2);
    var y = Math.round(Math.random() * (200 - s) + s / 2);
    image_count++;
    if(image_count > 7) {
      image_count = 0;
    }

    var keyPair = coin.ECPair.makeRandom();
    var p2pkh = coin.payments.p2pkh({ pubkey: keyPair.publicKey, network: network });

    var ball = Bodies.circle(x, y, s / 2, {
      label: 'ball',
      address: sanitize(p2pkh.address),
      value: sanitize("123.456"),
      restitution: 0.3,
      render: {
        sprite: {
          texture: Ball.get(String(image_count), 64),
          xScale: s / 64,
          yScale: s / 64,
        }
      }
    });
    bodies.push(ball);
    World.add(world, ball);
  }

  setTimeout(function() {
    var s2 = 80;
    var x = Math.round(Math.random() * (w - s2) + s2 / 2);

    var keyPair = coin.ECPair.makeRandom();
    var p2pkh = coin.payments.p2pkh({ pubkey: keyPair.publicKey, network: network });

    var ball = Bodies.circle(x, 40, s2 / 2, {
      label: 'ball',
      address: sanitize(p2pkh.address),
      value: sanitize("123'456.789"),
      restitution: 0.3,
      render: {
        sprite: {
          texture: Ball.get(String(200), 160, 'Too Much Balls'),
          xScale: s2 / 160,
          yScale: s2 / 160,
        }
      }
    });
    bodies.push(ball);
    World.add(world, ball);
  }, 3000);

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

  var click_cb = function(address) {
    console.log(address);
  }

  var dragging = false;
  Events.on(mouseConstraint, "startdrag", function(e) {
    click_cb(e.body.address);
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
    var foundPhysics = Matter.Query.point(bodies, e.mouse.position);
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

  World.add(world, mouseConstraint);
  render.mouse = mouse;

  Render.lookAt(render, {
    min: { x: 0, y: 200 },
    max: { x: w, y: h + 200 }
  });

  return {
    engine: engine,
    runner: runner,
    render: render,
    canvas: render.canvas,
    stop: function() {
      Matter.Render.stop(render);
      Matter.Runner.stop(runner);
    },
    click: function(cb) {
      click_cb = cb;
    },
    click_cb: function() {
      return click_cb;
    }
  };
}

