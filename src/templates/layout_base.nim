# Copyright (c) 2019 zenywallet

import caprese/contents

const layout_debug* = staticHtmlDocument:
  buildHtml(html(lang="en")):
    head:
      meta(charset="utf-8")
      meta(name="viewport", content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no")
      meta(name="description", content="Pastel Wallet")
      meta(name="author", content="zenywallet")
      meta(name="keywords", content="wallet")
      meta(name="format-detection", content="telephone=no")
      meta(http-equiv="X-UA-Compatible", content="IE=edge")
      meta(name="msapplication-TileColor", content="#00aba9")
      meta(name="theme-color", content="#ffffff")
      meta(name="mobile-web-app-capable", content="yes")
      meta(name="apple-mobile-web-app-capable", content="yes")
      meta(http-equiv="Cache-Control", content="no-cache")
      meta(http-equiv="Expires", content="0")
      meta(name="twitter:card", content="summary")
      meta(name="Twitter:site", content="@zenywallet")
      meta(property="og:title", content="Pastel Wallet")
      meta(property="og:description", content="Seedカードで鍵を管理するタイプの新しいBitZenyのウォレット")
      meta(property="og:image", content="https://pastel.bitzeny.jp/img/og-image.png")
      meta(property="og:url", content="https://pastel.bitzeny.jp/")
      link(rel="stylesheet", href="/semantic/compact.css")
      link(rel="stylesheet", href="/css/base.css")
      link(rel="apple-touch-icon", sizes="180x180", href="/apple-touch-icon.png")
      link(rel="icon", type="image/png", sizes="32x32", href="/favicon-32x32.png")
      link(rel="icon", type="image/png", sizes="16x16", href="/favicon-16x16.png")
      link(rel="manifest", href="/site.webmanifest")
      link(rel="mask-icon", href="/safari-pinned-tab.svg", color="#5bbad5")
      script(type="text/javascript", src="/js/cipher.js")
      script(type="text/javascript", src="/js/base58.js")
      script(type="text/javascript", src="/js/uint64.min.js")
      script(type="text/javascript", src="/js/coinlibs.js")
      script(type="text/javascript", src="/js/rawdeflate.min.js")
      script(type="text/javascript", src="/js/rawinflate.min.js")
      script(type="text/javascript", src="/js/jquery-3.4.1.min.js")
      script(type="text/javascript", src="/semantic/compact.js")
      script(type="text/javascript", src="/js/jquery-qrcode.js")
      script(type="text/javascript", src="/js/stor.js")
      script(type="text/javascript", src="/js/matter.js")
      script(type="text/javascript", src="/js/dotmatrix.js")
      script(type="text/javascript", src="/js/balls.js")
      script(type="text/javascript", src="/js/encoding.js")
      script(type="text/javascript", src="/js/tradelogs.js")
      script(type="text/javascript", src="/js/wallet.js")
      script(type="text/javascript", src="/js/ui.js")
      script(type="text/javascript", src="/js/pastel.js")
      title: text "Pastel Wallet"
    body:
      tdiv(id="main"):
        tdiv(class="intro"):
          tdiv(class="intro-head"):
            tdiv(class="caption"): text "Pastel Wallet"
      script(type="text/javascript", src="/js/main.js")

const layout_release* = staticHtmlDocument:
  buildHtml(html(lang="en")):
    head:
      meta(charset="utf-8")
      meta(name="viewport", content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no")
      meta(name="description", content="Pastel Wallet")
      meta(name="author", content="zenywallet")
      meta(name="keywords", content="wallet")
      meta(name="format-detection", content="telephone=no")
      meta(http-equiv="X-UA-Compatible", content="IE=edge")
      meta(name="msapplication-TileColor", content="#00aba9")
      meta(name="theme-color", content="#ffffff")
      meta(name="mobile-web-app-capable", content="yes")
      meta(name="apple-mobile-web-app-capable", content="yes")
      meta(name="twitter:card", content="summary")
      meta(name="Twitter:site", content="@zenywallet")
      meta(property="og:title", content="Pastel Wallet")
      meta(property="og:description", content="Seedカードで鍵を管理するタイプの新しいBitZenyのウォレット")
      meta(property="og:image", content="https://pastel.bitzeny.jp/img/og-image.png")
      meta(property="og:url", content="https://pastel.bitzeny.jp/")
      link(rel="stylesheet", href="/semantic/compact.css")
      link(rel="stylesheet", href="/css/base.css")
      link(rel="apple-touch-icon", sizes="180x180", href="/apple-touch-icon.png")
      link(rel="icon", type="image/png", sizes="32x32", href="/favicon-32x32.png")
      link(rel="icon", type="image/png", sizes="16x16", href="/favicon-16x16.png")
      link(rel="manifest", href="/site.webmanifest")
      link(rel="mask-icon", href="/safari-pinned-tab.svg", color="#5bbad5")
      title: text "Pastel Wallet"
    body:
      tdiv(id="main"):
        tdiv(class="intro"):
          tdiv(class="intro-head"):
            tdiv(class="caption"): text "Pastel Wallet"
      script(type="text/javascript", src="/js/app.js")

const layout_maintenance* = staticHtmlDocument:
  buildHtml(html(lang="en")):
    head:
      meta(charset="utf-8")
      meta(name="viewport", content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no")
      meta(name="description", content="Pastel Wallet")
      meta(name="author", content="zenywallet")
      meta(name="keywords", content="wallet")
      meta(name="format-detection", content="telephone=no")
      meta(http-equiv="X-UA-Compatible", content="IE=edge")
      meta(name="msapplication-TileColor", content="#00aba9")
      meta(name="theme-color", content="#ffffff")
      meta(name="mobile-web-app-capable", content="yes")
      meta(name="apple-mobile-web-app-capable", content="yes")
      meta(http-equiv="Cache-Control", content="no-cache")
      meta(http-equiv="Expires", content="0")
      link(rel="stylesheet", href="/semantic/compact.css")
      link(rel="stylesheet", href="/css/base.css")
      link(rel="apple-touch-icon", sizes="180x180", href="/apple-touch-icon.png")
      link(rel="icon", type="image/png", sizes="32x32", href="/favicon-32x32.png")
      link(rel="icon", type="image/png", sizes="16x16", href="/favicon-16x16.png")
      link(rel="manifest", href="/site.webmanifest")
      link(rel="mask-icon", href="/safari-pinned-tab.svg", color="#5bbad5")
      script(type="text/javascript", src="/js/jquery-3.4.1.min.js")
      script(type="text/javascript", src="/semantic/compact.js")
      title: text "Pastel Wallet"
    body:
      tdiv(id="main"):
        tdiv(class="intro"):
          tdiv(class="intro-head"):
            tdiv(class="caption"): text "Pastel Wallet"
          tdiv(class="ui placeholder segment"):
            tdiv(class="ui icon header"):
              italic(class="coffee icon")
              text "Sorry, It is a break time."
            a(class="ui olive button", href="/"): text "Reload"
