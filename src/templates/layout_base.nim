import templates

proc layout_debug*(): string =
  tmpli html"""
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
  <meta name="description" content="Pastel Wallet">
  <meta name="author" content="zenywallet">
  <meta name="keywords" content="wallet">
  <meta name="format-detection" content="telephone=no">
  <meta http-equiv="X-UA-Compatible" content="IE=edge">
  <meta name="msapplication-TileColor" content="#00aba9">
  <meta name="theme-color" content="#ffffff">
  <meta name="mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-capable" content="yes">
  <meta http-equiv="Cache-Control" content="no-cache">
  <meta http-equiv="Expires" content="0">
  <meta name="twitter:card" content="summary">
  <meta name="Twitter:site" content="@zenywallet">
  <meta property="og:title" content="Pastel Wallet">
  <meta property="og:description" content="Seedカードで鍵を管理するタイプの新しいBitZenyのウォレット">
  <meta property="og:image" content="https://pastel.bitzeny.jp/img/og-image.png">
  <meta property="og:url" content="https://pastel.bitzeny.jp/">
  <link rel="stylesheet" href="/semantic/compact.css">
  <link rel="stylesheet" href="/css/base.css">
  <link rel="apple-touch-icon" sizes="180x180" href="/apple-touch-icon.png">
  <link rel="icon" type="image/png" sizes="32x32" href="/favicon-32x32.png">
  <link rel="icon" type="image/png" sizes="16x16" href="/favicon-16x16.png">
  <link rel="manifest" href="/site.webmanifest">
  <link rel="mask-icon" href="/safari-pinned-tab.svg" color="#5bbad5">
  <script type="text/javascript" src="/js/cipher.js"></script>
  <script type="text/javascript" src="/js/base58.js"></script>
  <script type="text/javascript" src="/js/uint64.min.js"></script>
  <script type="text/javascript" src="/js/coinlibs.js"></script>
  <script type="text/javascript" src="/js/zopfli.raw.min.js"></script>
  <script type="text/javascript" src="/js/rawinflate.min.js"></script>
  <script type="text/javascript" src="/js/jquery-3.4.1.min.js"></script>
  <script type="text/javascript" src="/semantic/compact.js"></script>
  <script type="text/javascript" src="/js/jquery-qrcode.js"></script>
  <script type="text/javascript" src="/js/stor.js"></script>
  <script type="text/javascript" src="/js/matter.js"></script>
  <script type="text/javascript" src="/js/dotmatrix.js"></script>
  <script type="text/javascript" src="/js/balls.js"></script>
  <script type="text/javascript" src="/js/encoding.js"></script>
  <script type="text/javascript" src="/js/tradelogs.js"></script>
  <script type="text/javascript" src="/js/wallet.js"></script>
  <script type="text/javascript" src="/js/ui.js"></script>
  <script type="text/javascript" src="/js/pastel.js"></script>
  <title>Pastel Wallet</title>
</head>
<body>
  <div id="main">
    <div class ="intro">
      <div class="intro-head">
        <div class="caption">Pastel Wallet</div>
      </div>
    </div>
  </div>
  <script type="text/javascript" src="/js/main.js"></script>
</body>
</html>
"""

proc layout_release*(): string =
  tmpli html"""
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
  <meta name="description" content="Pastel Wallet">
  <meta name="author" content="zenywallet">
  <meta name="keywords" content="wallet">
  <meta name="format-detection" content="telephone=no">
  <meta http-equiv="X-UA-Compatible" content="IE=edge">
  <meta name="msapplication-TileColor" content="#00aba9">
  <meta name="theme-color" content="#ffffff">
  <meta name="mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-capable" content="yes">
  <meta name="twitter:card" content="summary">
  <meta name="Twitter:site" content="@zenywallet">
  <meta property="og:title" content="Pastel Wallet">
  <meta property="og:description" content="Seedカードで鍵を管理するタイプの新しいBitZenyのウォレット">
  <meta property="og:image" content="https://pastel.bitzeny.jp/img/og-image.png">
  <meta property="og:url" content="https://pastel.bitzeny.jp/">
  <link rel="stylesheet" href="/semantic/compact.css">
  <link rel="stylesheet" href="/css/base.css">
  <link rel="apple-touch-icon" sizes="180x180" href="/apple-touch-icon.png">
  <link rel="icon" type="image/png" sizes="32x32" href="/favicon-32x32.png">
  <link rel="icon" type="image/png" sizes="16x16" href="/favicon-16x16.png">
  <link rel="manifest" href="/site.webmanifest">
  <link rel="mask-icon" href="/safari-pinned-tab.svg" color="#5bbad5">
  <title>Pastel Wallet</title>
</head>
<body>
  <div id="main">
    <div class ="intro">
      <div class="intro-head">
        <div class="caption">Pastel Wallet</div>
      </div>
    </div>
  </div>
  <script type="text/javascript" src="/js/app.js"></script>
</body>
</html>
"""

proc layout_maintenance*(): string =
  tmpli html"""
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
  <meta name="description" content="Pastel Wallet">
  <meta name="author" content="zenywallet">
  <meta name="keywords" content="wallet">
  <meta name="format-detection" content="telephone=no">
  <meta http-equiv="X-UA-Compatible" content="IE=edge">
  <meta name="msapplication-TileColor" content="#00aba9">
  <meta name="theme-color" content="#ffffff">
  <meta name="mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-capable" content="yes">
  <meta http-equiv="Cache-Control" content="no-cache">
  <meta http-equiv="Expires" content="0">
  <link rel="stylesheet" href="/semantic/compact.css">
  <link rel="stylesheet" href="/css/base.css">
  <link rel="apple-touch-icon" sizes="180x180" href="/apple-touch-icon.png">
  <link rel="icon" type="image/png" sizes="32x32" href="/favicon-32x32.png">
  <link rel="icon" type="image/png" sizes="16x16" href="/favicon-16x16.png">
  <link rel="manifest" href="/site.webmanifest">
  <link rel="mask-icon" href="/safari-pinned-tab.svg" color="#5bbad5">
  <script type="text/javascript" src="/js/jquery-3.4.1.min.js"></script>
  <script type="text/javascript" src="/semantic/compact.js"></script>
  <title>Pastel Wallet</title>
</head>
<body>
  <div id="main">
    <div class ="intro">
      <div class="intro-head">
        <div class="caption">Pastel Wallet</div>
      </div>
      <div class="ui placeholder segment">
        <div class="ui icon header">
          <i class="coffee icon"></i>
          Sorry, It is a break time.
        </div>
        <a class="ui olive button" href="/">Reload</a>
      </div>
    </div>
  </div>
</body>
</html>
"""
