import templates, strutils
proc layout_base*(debug: bool): string =
  const debug_script = """
<script type="text/javascript" src="/js/cipher.js"></script>
<script type="text/javascript" src="/js/base58.js"></script>
<script type="text/javascript" src="/js/coinlibs.js"></script>
<script type="text/javascript" src="/js/zopfli.raw.min.js"></script>
<script type="text/javascript" src="/js/rawinflate.min.js"></script>
<script type="text/javascript" src="/js/jquery-3.4.1.js"></script>
<script type="text/javascript" src="/semantic/semantic.js"></script>
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
""".indent(2).strip
  const release_script = """
<script type="text/javascript" src="/js/app.js"></script>
""".indent(2).strip
  var script: string
  if debug:
    script = debug_script
  else:
    script = release_script
  tmpli html"""
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
  <meta name="description" content="Pastel WALLET">
  <meta name="author" content="zenywallet">
  <meta name="keywords" content="wallet">
  <meta name="format-detection" content="telephone=no">
  <meta http-equiv="X-UA-Compatible" content="IE=edge">
  <meta name="msapplication-TileColor" content="#00aba9">
  <meta name="theme-color" content="#ffffff">
  <link rel="stylesheet" href="/semantic/semantic.min.css">
  <link rel="stylesheet" href="/css/base.css">
  <link rel="apple-touch-icon" sizes="180x180" href="/apple-touch-icon.png">
  <link rel="icon" type="image/png" sizes="32x32" href="/favicon-32x32.png">
  <link rel="icon" type="image/png" sizes="16x16" href="/favicon-16x16.png">
  <link rel="manifest" href="/site.webmanifest">
  <link rel="mask-icon" href="/safari-pinned-tab.svg" color="#5bbad5">
  $script
  <title>Pastel WALLET</title>
</head>
<body>
  <div id="main"></div>
  <section id="section0" class="section">
    <div class ="intro">
      <div class="caption">Pastel Wallet</div>
      <div class="ui active centered inline inverted loader"></div>
    </div>
  </section>
  <script type="text/javascript" src="/js/main.js"></script>
</body>
</html>
"""
