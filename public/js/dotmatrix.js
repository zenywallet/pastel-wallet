var DotMatrix = (function() {
  function Color() {
    if(!(this instanceof Color)) {
      return new Color();
    }

    var _r, _g, _b, _a;

    this.rgba = function(color_array) {
      _r = color_array[0];
      _g = color_array[1];
      _b = color_array[2];
      _a = color_array[3];

      return this;
    }

    this.rgb = function(red, green, blue) {
      _r = red;
      _g = green;
      _b = blue;
      _a = 0xff;

      return this;
    }

    this.string = function() {
      return '#' + ('0' + _r.toString(16)).substr(-2)
        + ('0' + _g.toString(16)).substr(-2)
        + ('0' + _b.toString(16)).substr(-2);
    }

    this.red = function() {
      return _r;
    }
    this.green = function() {
      return _g;
    }
    this.blue = function() {
      return _b;
    }
    this.alpha = function() {
      return _a;
    }
  }


  var SIZE = 96;
  var BG_COLOR = 0xffeeeeee;
  var STEP_SIZE = Math.PI / 50;
  var TWO_PI = Math.PI * 2;

  function hexToBytes(hex) {
    for (var bytes = [], c = 0; c < hex.length; c += 2) {
      bytes.push(parseInt(hex.substr(c, 2), 16));
    }
    return bytes;
  }

  function bytesToHex(bytes) {
    for (var hex = [], i = 0; i < bytes.length; i++) {
      hex.push((bytes[i] >>> 4).toString(16));
      hex.push((bytes[i] & 0xF).toString(16));
    }
    return hex.join("");
  }

  function UIntToColor(uint_color)
  {
    var a = (uint_color >> 24) & 0xff;
    var r = (uint_color >> 16) & 0xff;
    var g = (uint_color >> 8) & 0xff;
    var b = (uint_color >> 0) & 0xff;
    return Color().rgba([r, g, b, a]);
  }

  function ColorToUInt(color)
  {
    return (color.alpha() << 24) | (color.red() << 16) |
      (color.green() << 8) | (color.blue() << 0);
  }

  function getColorDistance(e1, e2)
  {
    var rmean = (e1.red() + e2.red()) / 2;
    var r = e1.red() - e2.red();
    var g = e1.green() - e2.green();
    var b = e1.blue() - e2.blue();
    return Math.sqrt((((512 + rmean) * r * r) >> 8) + 4 * g * g + (((767 - rmean) * b * b) >> 8));
  }

  function getComplementaryColor(colorToInvert)
  {
    var rgbaColor = ColorToUInt(colorToInvert);
    return UIntToColor(0xFFFFFF00 ^ rgbaColor);
  }

  var DotMatrix = {};

  DotMatrix.getImage = function(hash_data, size = SIZE, round = 0) {
    var hash;
    if (typeof hash_data === 'string') {
      var hash = new Uint8Array(hexToBytes(hash_data));
    } else {
      var hash = hash_data;
    }
    var canvas = document.createElement('canvas');
    canvas.width  = size;
    canvas.height = size;

    if (hash.length != 16) {
      return canvas.toDataURL('image/png');
    }
    var ctx = canvas.getContext('2d');
    var gb_color = UIntToColor(BG_COLOR);

    var blue = (hash[13] & 0x01f) << 3;
    var green = (hash[14] & 0x01f) << 3;
    var red = (hash[15] & 0x01f) << 3;
    var color = Color().rgb(red, green, blue);
    if (getColorDistance(color, gb_color) <= 64.0) {
      color = getComplementaryColor(color);
    }

    var blue2 = (hash[9] & 0x01f) << 3;
    var green2 = (hash[10] & 0x01f) << 3;
    var red2 = (hash[12] & 0x01f) << 3;
    var color2 = Color().rgb(red2, green2, blue2);
    if (getColorDistance(color2, color) <= 64.0) {
      color2 = getComplementaryColor(color2);
    }

    ctx.fillStyle = color2.string();
    ctx.beginPath();
    ctx.fillRect(0, 0, size, size);
    ctx.closePath();
    ctx.fill();

    ctx.fillStyle = color.string();
    for (var y = 0; y < 5; y++) {
      for (var x = 0; x < 5; x++) {
        var index = y * 5 + x;
        var radius;
        if ((index & 1) == 0) {
          radius = hash[index/2] & 0x0F;
        } else {
          radius = (hash[index/2] >> 4) & 0x0F;
        }
        radius *= size / SIZE

        ctx.beginPath();
        ctx.arc(x * size / 5 + size / 10, y * size / 5 + size / 10, radius, 0, 360 * Math.PI / 180, true);
        ctx.closePath();
        ctx.fill();
      }
    }

    if(round) {
      ctx.beginPath();
      ctx.globalCompositeOperation = "destination-in";
      ctx.arc(size / 2, size / 2, size / 2, 0, Math.PI * 2, false);
      ctx.closePath();
      ctx.fill()
    }

    return canvas.toDataURL('image/png');
  }

  return DotMatrix;
})();
