# Copyright (c) 2019 zenywallet

const BaseCss* = """
@font-face {
  font-family: 'Josefin Sans';
  font-style: normal;
  font-weight: 300;
  src: url(/fonts/Josefin_Sans/static/JosefinSans-Light.woff2) format('woff2');
}
@font-face {
  font-family: 'Josefin Sans';
  font-style: normal;
  font-weight: 400;
  src: url(/fonts/Josefin_Sans/static/JosefinSans-Regular.woff2) format('woff2');
}
@font-face {
  font-family: 'Lato';
  font-style: normal;
  font-weight: 400;
  src: url(/fonts/Lato/Lato-Regular.woff2) format('woff2');
}
@font-face {
  font-family: 'Lato';
  font-style: normal;
  font-weight: 700;
  src: url(/fonts/Lato/Lato-Bold.woff2) format('woff2');
}
* {
  margin: 0;
  padding: 0;
}
html, body {
  height: 100%;
  background: #444; /* if you change the value, change receive address modal background */
}
html {
  -ms-overflow-style: none;
  scrollbar-width: none;
}
html::-webkit-scrollbar {
  display: none;
}
.section, #main {
  position: relative;
  width: 100%;
  height: 100%;
}
.section::after {
  position: absolute;
  bottom: 0;
  left: 0;
  content: '';
  width: 100%;
  height: 80%;
  background: -webkit-linear-gradient(top,rgba(0,0,0,0) 0,rgba(0,0,0,.8) 80%,rgba(0,0,0,.8) 100%);
  background: linear-gradient(to bottom,rgba(0,0,0,0) 0,rgba(0,0,0,.8) 80%,rgba(0,0,0,.8) 100%);
}
.section h1 {
  position: absolute;
  top: 50%;
  left: 50%;
  z-index: 2;
  -webkit-transform: translate(-50%, -50%);
  transform: translate(-50%, -50%);
  color: #fff;
  font : normal 300 64px/1 'Josefin Sans', sans-serif;
  text-align: center;
  white-space: nowrap;
}

#section0 { background: #4682b4; }
#section1 { background: #4682b4; }
#section2 { background: #8fbc8f; }
#section3 { background: #d2b48c; }
#section4 { background: #444; }

#section0, #section1, #section2, #section3 {
  min-height: 460px;
  height: 100vh;
  height: calc(var(--vh, 1vh) * 100);
}
#section4 {
  min-height: 100vh;
}
.section a.pagenext {
  position: absolute;
  left: 50%;
  bottom: -20px;
  z-index: 5;
  display: inline-block;
  margin-left: -24px;
  -webkit-transform: translate(0, -50%);
  transform: translate(0, -50%);
  color: #fff;
  font : normal 400 20px/1 'Josefin Sans', sans-serif;
  letter-spacing: .1em;
  text-decoration: none;
  transition: opacity .3s;
  outline : none;
  background-color: rgba(72,81,75,.4);
  border-radius: 8px;
  padding: 4px;
}
.section a.pagenext:hover {
  opacity: .5;
}
.section a.pagenext:focus {
  opacity: .5;
}
.section a.pagenext {
  padding-top: 50px;
}
.section a.pagenext span {
  position: absolute;
  top: 0;
  left: 50%;
  width: 24px;
  height: 24px;
  margin-left: -12px;
  border-left: 1px solid #fff;
  border-bottom: 1px solid #fff;
  -webkit-transform: rotate(-45deg);
  transform: rotate(-45deg);
  -webkit-animation: sdb 2s infinite;
  animation: sdb 2s infinite;
  box-sizing: border-box;
}
@-webkit-keyframes sdb {
  0% {
    -webkit-transform: rotate(-45deg) translate(0, 0);
  }
  20% {
    -webkit-transform: rotate(-45deg) translate(-10px, 10px);
  }
  40% {
    -webkit-transform: rotate(-45deg) translate(0, 0);
  }
}
@keyframes sdb {
  0% {
    transform: rotate(-45deg) translate(0, 0);
  }
  20% {
    transform: rotate(-45deg) translate(-10px, 10px);
  }
  40% {
    transform: rotate(-45deg) translate(0, 0);
  }
}
.notify-container {
  position: absolute;
  top: 7px;
  right: 7px;
  z-index: 10;
  pointer-events: none;
  height: calc(100% - 7px);
  overflow: hidden;
}
.notify-container .ui.message {
  width: 282px;
  min-width: 282px;
  min-height: 0;
}
.notify-container .ui.message .close {
  pointer-events: auto;
}
.notify-container .message .hidden {
  display: none;
}
.intro {
  position: relative;
  width: 100%;
  height: 100%;
}
.intro-head {
  position: relative;
  width: 100%;
  height: 202px;
  padding-top: 16px;
}
.intro-body {
  width: 100%;
  height: calc(100% - 232px);
}
.intro-body .seed-seg, .intro-body .mnemonic-seg {
  height: 100%;
  margin: 0 14px;
  bottom: 3px;
  min-width: 324px;
  z-index: 2;
  background: linear-gradient(0deg, rgba(136,136,136,.6), rgba(221,221,221,.6));
}
.intro-body .seed-seg {
  min-height: 400px;
}
.intro-body .mnemonic-seg {
  min-height: 383px;
}
.intro-body .medit-seg {
  position: absolute;
  top: 14px;
  z-index: 2;
  background: linear-gradient(-90deg, rgba(136,136,136,.6), rgba(221,221,221,.6));
  height: 274px;
  width: calc(100% - 28px);
}
.intro-body .medit-autocomp {
  position: absolute;
  bottom: 14px;
  z-index: 2;
  display: inline-block;
  height: calc(100% - 274px - 21px - 35px + 14px);
  width: calc(100% - 28px);
  overflow: auto;
}
.intro-body .medit-seg .form {
  position: relative;
  top: 0;
  height: 210px;
  width: 100%;
}
#minput {
  height: 98px;
  min-height: 98px;
  resize: none;
}
.medit-seg .ui[class*="right floated"].button {
  margin-left: 7px;
}
.medit-autocomp .ui.label > .icon {
  margin: 4px 0;
}
.medit-autocomp .ui.label {
  padding: 2px 4px;
}
.intro-body .keycard-seg {
  position: absolute;
  top: 14px;
  z-index: 2;
  background: linear-gradient(-90deg, rgba(136,136,136,.6), rgba(221,221,221,.6));
  width: calc(100% - 28px);
}
.intro-body .keycard-seg .center {
  text-align: center;
}
.intro-body .keycard-seg .ui[class*="right floated"].button {
  margin-left: 7px;
}
.intro-body .keycard-seg .ui.inverted.segment p {
  font-color: #dcddde;
  font-weight: 700;
  text-shadow: 1px 1px 2px #333;
  word-wrap: break-word;
}
.intro-body .keycard-seg .ui.inverted.segment {
  background-color: rgba(72,81,75,.3);
}
.intro-body .passphrase-seg {
  position: absolute;
  top: 14px;
  z-index: 2;
  background: linear-gradient(-90deg, rgba(136,136,136,.6), rgba(221,221,221,.6));
  width: calc(100% - 28px);
}
.intro-body .passphrase-seg .center, #passphrase-modal-seg .center {
  text-align: center;
}
.intro-body .passphrase-seg .ui.inverted.segment p {
  font-color: #dcddde;
  font-weight: 700;
  text-shadow: 1px 1px 2px #333;
  word-wrap: break-word;
}
.intro-body .passphrase-seg .ui.inverted.segment {
  background-color: rgba(72,81,75,.3);
}
.intro-body .passphrase-seg .ui.form input[type="text"], .intro-body .passphrase-seg .ui.form input[type="password"] {
  background: rgba(128, 128, 128, 0.6);
  color: #f0f0f0;
}
intro-body .passphrase-seg .ui.form input[type="text"]:focus, .intro-body .passphrase-seg .ui.form input[type="password"]:focus, intro-body .passphrase-seg .ui.form input[type="text"]::selection, .intro-body .passphrase-seg .ui.form input[type="password"]::selection {
  color: #fafafa;
}
.intro .caption {
  color: #fff;
  font : normal 300 44px/1 'Josefin Sans', sans-serif;
  text-align: center;
  white-space: nowrap;
  min-width: 320px;
  margin: 0 16px;
  padding-top: 4px;
}
.bt-scan-seed {
  position: absolute;
  top: 50%;
  left: 50%;
  -webkit-transform: translate(-50%, -50%);
  transform: translate(-50%, -50%);
  z-index: 6;
}
.ui.buttons .or::before {
  line-height: 1.65em;
}
#qrcanvas, #seed-seg .qrcamera-loader, #seed-seg .qrcamera-shutter, #qrcode-modal .qrcamera-loader, #qrcode-modal .qrcamera-shutter {
  position: absolute;
  top: 0;
  left: 0;
  margin: 7px 7px;
  width: calc(100% - 14px);
  height: calc(100% - 14px);
  border-radius: 12px;
  overflow: hidden;
  object-fit: cover;
}
#qrcanvas {
  z-index: 5;
  visibility: hidden;
}
.ui.dimmer.modals.top-align {
  justify-content: flex-start;
}
.ui.dimmer.qrcamera-loader {
  z-index: 7;
}
.ui.dimmer.qrcamera-shutter {
  z-index: 8;
}
.ui.segment > .ui.dimmer.qrcamera-loader, .ui.segment > .ui.dimmer.qrcamera-shutter {
  border-radius: 12px !important;
}
#bt-camchange {
  display: block;
  position: absolute;
  float: right;
  z-index: 4;
}
.method-selector {
  text-align: center;
}
.method-selector .title {
  color: #fff;
  font : normal 400 14px/1 'Josefin Sans', sans-serif;
  padding: 4px 10px 8px 10px;
  height: 65px;
  display: flex;
  justify-content: center;
  text-align: left;
}
.method-selector .button {
  width: 152px;
  z-index: 2;
}
.qr-scanning {
  position: absolute;
  top: 50%;
  left: 50%;
  -webkit-transform: translate(-50%, -50%);
  transform: translate(-50%, -50%);
  width: 100%;
  height: 100%;
  z-index: 6;
  display: none;
}
.qr-scanning div {
  position: absolute;
  border: 1px solid #fff;
  opacity: 0.8;
  border-radius: 50%;
  animation: qr-scanning 2s cubic-bezier(0, 0.2, 0.8, 1) infinite;
}
.qr-scanning div:nth-child(2) {
  animation-delay: -0.5s;
}
@keyframes qr-scanning {
  0% {
    top: 20%;
    left: 20%;
    width: 60%;
    height: 60%;
    opacity: 0.8;
  }
  100% {
    top: 5%;
    left: 5%;
    width: 90%;
    height: 90%;
    opacity: 0;
  }
}
.camtools {
  position: absolute;
  top: 14px;
  right: 14px;
  float: right;
  z-index: 7;
  background-color: rgba(136,136,136,0.6);
  visibility: hidden;
}
.ui.cards.seed-card-holder {
  position: relative;
  display: flex;
  flex-wrap: nowrap;
  justify-content: flex-start;
  overflow-x: auto;
  overflow-y: hidden;
  top: -7px;
  left: -7px;
  margin-left: auto !important;
  margin-top: auto !important;
  width: calc(100% + 14px);
  height: 374px;
  -webkit-overflow-scrolling: touch;
  padding-right: 7px;
  z-index: 4;
}
.ui.card.seed-card {
  position: relative;
  width: 220px;
  height: 340px;
  flex: 0 0 auto;
  z-index: 4;
  box-shadow: 1px 1px 7px #4b4861;
  background: linear-gradient(-110deg, rgba(200,200,200,0.9), rgba(255,255,255,0.9));
}
.ui.card.seed-card {
  border-radius: 9px;
}
.ui.card.seed-card  > :first-child {
  border-radius: 9px 9px 0 0 !important;
}
.ui.link.cards .card.seed-card:hover {
  background-color: rgba(255, 255, 255, 0.9);
}
.ui.card.seed-card .image {
  background-color: rgba(255, 255, 255, 0.7);
}
.seed-qrcode {
  margin: 16px 16px 11px 16px;
}
.seed-card .tag {
  float: right;
  margin-top: -3px;
  margin-right: -3px;
  font-family: "Courier New", Courier, Consolas, Monaco, monospace;
  font-weight: 800;
  color: #fff;
  text-shadow: 1px 1px 2px #1c1c1c;
}
.ui.card.seed-card > .content > .header {
  margin-top: -8px;
  z-index: 4;
}
.ui.card.seed-card > .content {
  font-size: 10px;
}
.ui.card.seed-card > .content .seed-body {
  margin-top: 9px;
  line-height: 20px;
}
.ui.card.seed-card > .content .seed {
  font-family: "Courier New", Courier, Consolas, Monaco, monospace;
  font-weight: 800;
  color: #fff;
  text-shadow: 1px 1px 2px #1c1c1c;
  letter-spacing: 0.1em
}
.ui.card.seed-card > .content, .ui.cards > .card > .content {
  padding: 10px 14px;
}
.ui.card.seed-card > .content .meta {
  font-size: 10px;
  line-height: 10px;
}
.seed-card .vector-label {
  display: inline;
  font-size: 10px;
  margin-right: 4px;
}
.ui.card.seed-card > .extra {
  padding: 3px 10px 4px;
  margin-top: -4px;
}
.ui.mini.input.vector-input {
  position: absolute;
  bottom: 4px;
  right: 10px;
  font-size: 11px;
  line-height: 20px;
  height: 20px;
  width: 134px;
}
.ui.mini.input.vector-input > input {
  width: 100%;
  padding: 0.4em 0.5em;
}
.ui.card.seed-card > .bt-seed-del {
  position: absolute;
  top: -7px;
  right: -9px;
  visibility: hidden;
  z-index: 5;
}
.ui.card.seed-card > .bt-seed-del .button {
  background-color: rgba(160, 160, 160, 0.5);
}
.ui.card.seed-card > .bt-seed-del .button:hover {
  background-color: rgba(160, 160, 160, 0.8);
}
.ui.link.cards .card.seed-card:hover .bt-seed-del {
  visibility: visible;
}

.ui.card.seed-card > .bt-seed-del .cut {
  position: relative;
  top: 2px;
  right: 1px;
  -webkit-transform: rotate(180deg);
  -moz-transform: rotate(180deg);
  -ms-transform: rotate(180deg);
  -o-transform: rotate(180deg);
  transform: rotate(180deg);
}
.seed-add-container {
  min-width: 100px;
}
.seed-add-container .bt-add-seed {
  position: relative;
  top: 50%;
  left: 50%;
  -webkit-transform: translate(-50%, -50%);
  transform: translate(-50%, -50%);
}
.wallet-body .seed-seg canvas {
  opacity: 0.4;
}
.ui.buttons.sendrecv > .button, .ui.buttons.settings > .button {
  z-index: 3;
}
.wallet-btns {
  text-align: center;
  padding-top: 12px;
}
.ui.buttons.sendrecv {
  width: 284px;
  min-width: 284px;
  margin: 0 14px;
}
i.send {
  color: #d57171;
}
i.receive {
  color: #23b195;
}
#wallet-balance {
  display: none;
  pointer-events: none;
}
#wallet-balance .balance, #wallet-balance .ui.label {
  pointer-events: auto;
}
#wallet-balance .ui.attached.label.send {
  background-color: rgba(213, 113, 113, 0.5);
  color: #eee;
  padding: 5px 0px 5px 6px;
  display: none;
}
#wallet-balance .ui.attached.label.receive {
  background-color: rgba(35, 177, 149, 0.5);
  color: #eee;
  padding: 5px 6px 5px 6px;
  display: none;
}
#wallet-balance .ui.attached.label.symbol {
  background-color: rgba(118, 118, 118, 0.5);
  color: #eee;
  padding: 5px 6px 5px 6px;
}
.wallet-head {
  position: relative;
  width: 100%;
  height: 144px;
}
.wallet-body {
    width: 100%;
    height: calc(100% - 180px);
}
.wallet-body .seed-seg {
  min-height: 275px;
}
.ui.attached.buttons.settings {
  margin-top: -2px;
}
.ui.buttons.settings > .button {
  font-weight: 400;
  background-color: transparent;
  color: #aaa;
}
.ui.buttons.settings > .button:hover {
  background: rgba(167,225,226,0.1);
}
.ui.buttons.settings > .button:focus {
  background: rgba(177,235,236,0.1);
}
#wallet-balance {
  position: absolute;
  top: 152px;
  left: 28px;
  z-index: 3;
  background: rgba(128,128,128,0.3);
  width: calc(100% - 56px);
  min-width: 284px;
  text-align: center;
  color: #fafafa;
  font: normal 400 20px/1 'arial', sans-serif;
}
.ui.segment.seed-seg {
  border: 1px solid rgba(214,216,218,.25);
}
.ui.basic.buttons > .ui.button.send {
  color: #eee !important;
  font-weight: 400;
  background: rgba(170,170,170,0.6) !important;
}
.ui.basic.buttons > .ui.button.receive {
  color: #eee !important;
  font-weight: 400;
  background: rgba(170,170,170,0.6) !important;
}
.ui.basic.buttons > .ui.button.send:hover, .ui.basic.buttons > .ui.button.receive:hover, .ui.basic.buttons > .ui.button:hover {
  background: rgba(190,190,190,0.6) !important;
}
.ui.basic.button:active, .ui.basic.buttons .button:active {
  background: rgba(190,190,190,0.6) !important;
}
.ui.basic.button:focus, .ui.basic.buttons > .ui.button:focus, .ui.basic.buttons > .ui.button.send:focus, .ui.basic.buttons > .ui.button.receive:focus {
  background: rgba(200,200,200,0.6) !important;
}
.ui.buttons.settings > .ui.button {
  padding-left: 30px;
}
.ui.buttons.settings > .ui.button span {
  padding-left: 4px;
}
#receive-address {
  position: absolute;
  top: 216px;
  left: 28px;
  z-index: 3;
  background: rgba(128,128,128,0.3);
  width: calc(100% - 56px);
  min-width: 284px;
  text-align: center;
  color: #fafafa;
  font: normal 400 13px/1 'arial', sans-serif;
  padding: 7px 0;
  display: none;
  pointer-events: none;
}
#receive-address .ui.label, #receive-address .ui.buttons, #address-text, #receive-address .ui.ball img {
  pointer-events: auto;
}
#receive-address .used .ui.ball img {
  pointer-events: none;
}
#receive-address .used .ui.ball, #receive-address .new .ui.ball {
  pointer-events: auto;
}
#receive-address .btn-close {
  position: absolute;
  right: 0em;
  top: 0.4em;
  color: rgba(0,0,0,.3);
}
#receive-address .btn-maximize {
  position: absolute;
  right: 1.5em;
  top: 0.4em;
  color: rgba(0,0,0,.3);
}
#receive-address .ui.label.recvaddress {
  background-color: rgba(35, 177, 149, 0.5);
  color: #eee;
  padding: 5px 6px 5px 6px;
}
#receive-address .ui.active.button {
  background: rgba(180,180,180,.8) !important;
}
#receive-address .ui.active.button:active {
  background: rgba(180,180,180,.8) !important;
}
#receive-address .ui.active.button:hover {
  background: rgba(190,190,190,.8) !important;
}
#receive-address .ui.active.button:focus {
  background: rgba(200,200,200,.8) !important;
}
#ball-info {
  position: absolute;
  top: 0;
  left: 0;
  -webkit-transform: translate(-50%, 0%);
  transform: translate(-50%, 0%);
  z-index: 3;
  text-align: center;
  color: #fafafa;
  font: normal 400 9px/1 'arial', sans-serif;
  background: rgba(128,128,128,0.3);
  padding: 4px 4px;
  display: none;
  white-space: nowrap;
}
.ui.cards.tradelogs {
  display: block;
  margin-top: 14px;
  min-width: 304px;
}
#tradelogs {
  margin-bottom: 120px;
}
.ui.cards.tradelogs > .card {
  width: 600px;
  background-color: rgba(255, 253, 250, 1);
}
.ui.cards.tradelogs > i.receive {
  color: #23b195;
}
.ui.cards.tradelogs > i.send {
  color: #d57171;
}
.ui.cards.tradelogs > .card > .content {
  padding: 0.5em 0.5em;
}
.ui.cards.tradelogs > .card > .content > .header {
  font-size: 1.18em;
  line-height: 1.18em;
  padding-bottom: 0.16em;
}
.ui.cards.tradelogs > .card > .extra.confirmed {
  background-color: rgba(243, 255, 243, 0.54);
  padding: 0.1em 0.5em 0.2em;
}
.ui.cards.tradelogs > .card > .extra.unconfirmed {
  background-color: rgba(255, 243, 243, 0.54);
  padding: 0.1em 0.5em 0.2em;
}
.ui.cards.tradelogs > .card .meta {
  font-size: 11px;
  line-height: 1.2em;
}
.ui.cards.tradelogs > .card .txid {
  margin-top: 0.8em;
  text-overflow: ellipsis;
  overflow: hidden;
  white-space: nowrap;
}
.ui.cards.tradelogs > .card > .content > .description span {
  margin-left: 1em;
}
.ui.buttons.settings.backpage {
  width: 100%;
  background-color: #4a4a4a;
}
.ui.cards.tradelogs > .card.metal {
  background-size: 50px 216px;
  background-image: -webkit-repeating-linear-gradient(left, hsla(0,0%,100%,0) 0%, hsla(0,0%,100%,0) 6%, hsla(0,0%,100%,.1) 7.5%, hsla(0,0%, 100%,0) 9%),
  -webkit-repeating-linear-gradient(left, hsla(0,0%,40%,0) 0%, hsla(0,0%,40%,0) 4%, hsla(0,0%,40%,.03) 4.5%, hsla(0,0%,40%,0) 6%),
  -webkit-repeating-linear-gradient(left, hsla(0,0%,100%,0) 0%, hsla(0,0%,100%,0) 1.2%, hsla(0,0%,100%,.15) 2.2%, hsla(0,0%,100%,0) 4%),
  -webkit-linear-gradient(-90deg, hsl(0,0%,88%) 0%, hsl(0,0%,94%) 40%, hsl(0,0%,84%) 53%, hsl(0,0%,96%) 100%);
}
.ui.cards.tradelogs > .card.metal2 {
  background: -webkit-radial-gradient(center, circle, rgba(255,255,255,.35), rgba(255,255,255,0) 20%, rgba(255,255,255,0) 21%), -webkit-radial-gradient(center, circle, rgba(0,0,0,.2), rgba(0,0,0,0) 20%, rgba(0,0,0,0) 21%), -webkit-radial-gradient(center, circle farthest-corner, #f0f0f0, #c0c0c0);
  background: -moz-radial-gradient(center, circle, rgba(255,255,255,.35), rgba(255,255,255,0) 20%, rgba(255,255,255,0) 21%), -webkit-radial-gradient(center, circle, rgba(0,0,0,.2), rgba(0,0,0,0) 20%, rgba(0,0,0,0) 21%), -webkit-radial-gradient(center, circle farthest-corner, #f0f0f0, #c0c0c0);
  background: -ms-radial-gradient(center, circle, rgba(255,255,255,.35), rgba(255,255,255,0) 20%, rgba(255,255,255,0) 21%), -webkit-radial-gradient(center, circle, rgba(0,0,0,.2), rgba(0,0,0,0) 20%, rgba(0,0,0,0) 21%), -webkit-radial-gradient(center, circle farthest-corner, #f0f0f0, #c0c0c0);
  background: -o-radial-gradient(center, circle, rgba(255,255,255,.35), rgba(255,255,255,0) 20%, rgba(255,255,255,0) 21%), -webkit-radial-gradient(center, circle, rgba(0,0,0,.2), rgba(0,0,0,0) 20%, rgba(0,0,0,0) 21%), -webkit-radial-gradient(center, circle farthest-corner, #f0f0f0, #c0c0c0);
  background: radial-gradient(center, circle, rgba(255,255,255,.35), rgba(255,255,255,0) 20%, rgba(255,255,255,0) 21%), -webkit-radial-gradient(center, circle, rgba(0,0,0,.2), rgba(0,0,0,0) 20%, rgba(0,0,0,0) 21%), -webkit-radial-gradient(center, circle farthest-corner, #f0f0f0, #c0c0c0);
  background-size: 10px 10px, 10px 10px, 100% 100%;
  background-position: 1px 1px, 0px 0px, center center;
}
.ui.cards.tradelogs > .card .image {
  opacity: 0.54;
}
#bottom-blink {
  position: absolute;
  display: none;
  bottom: 0;
  left: 0;
  width: 100%;
  height: 28px;
  background: linear-gradient(0deg, rgba(255,255,255,0.2) 0%, rgba(252,250,250,0.2) 23%, rgba(59,59,59,0.2) 100%, rgba(255,255,255,0.2) 100%);
  z-index: 5;
  pointer-events: none;
}
#receive-address .address {
  margin: 14px 7px 14px;
  height: 13px;
  word-wrap: break-word;
}
#receive-address .balls {
  display: inline-block;
  margin: 7px 7px;
  height: 52px;
}
#receive-address .used {
  display: inline-block;
  vertical-align: top;
  height: 52px;
  margin-right: 0;
  visibility: hidden;
  width: 0;
}
#receive-address .new {
  display: inline-block;
  vertical-align: top;
  height: 52px;
}
#receive-address .ui.basic.buttons .ui.button {
  color: rgba(238, 238, 238, .8) !important;
}
#receive-address .ui.icon.button {
  padding: 3px 3px 3px 3px;
  width: 34px;
  height: 34px;
}
#receive-address .ball {
  display: inline-block;
  margin: 8px 4px 0;
  width: 42px;
  height: 52px;
}
#receive-address img {
}
#receive-address .ball:after {
  content: '';
  border-top: 10.3923px solid transparent;
  border-right: 6px solid transparent;
  border-bottom: 6px solid transparent;
  border-left: 6px solid transparent;
  position: relative;
  top: -44px;
  left: -8px;
  float: right;
}
#receive-address .ball:hover:after {
  content: '';
  position: relative;
  border-top: 10.3923px solid rgba(255, 120, 120, 0.4);
  border-right: 6px solid transparent;
  border-bottom: 6px solid transparent;
  border-left: 6px solid transparent;
  position: relative;
  top: -44px;
  left: -8px;
  float: right;
}
#receive-address .ball.active:after {
  border-top: 10.3923px solid rgba(255, 120, 120, 1);
}
#recv-modal {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 120%;
  min-width: 320px;
  min-height: 667px;
  background-color: #fff;
  z-index: 4;
  text-align: center;
  display: none;
}
#recv-modal .close-arc {
  position: absolute;
  border: 0px solid #000;
  display: inline-block;
  min-width: 3em;
  min-height: 3em;
  padding: 0em;
  border-bottom-left-radius: 100%;
  background-color: rgba(200, 200, 200, 0.5);
  right: 0;
  top: 0;
  cursor: pointer;
  outline: none;
}
#recv-modal .close-arc:hover {
  background-color: rgba(210, 210, 210, 0.5);
}
#recv-modal .close-arc:focus {
  background-color: rgba(220, 220, 220, 0.5);
}
#recv-modal .btn-close-arc {
  position: absolute;
  right: 0.3em;
  top: 0.3em;
}
@media print {
  .close-arc {
    display: none;
  }
  .ui.popup.transition {
    visibility: hidden !important;
  }
}
#recv-modal .qrcode {
  margin-top: 3em;
}
#recv-modal .uri-container {
  display: inline-block;
  text-align: center;
}
#recv-qrcode-uri {
  margin: 7px 0;
  word-break: break-all;
  word-wrap: break-word;
  text-align: left;
  font-size: 7px;
  line-height: 1em;
}
.ui.popup {
  white-space: pre-wrap;
  word-break: break-word;
  max-width: 90%;
}
#recvaddr-form {
  text-align: left;
  margin-top: 1em;
}
#recvaddr-form .ui.input > input.right {
  text-align: right;
}
#recvaddr-form .ui.dropdown > .text, #recvaddr-form .ui.dropdown .menu > .item {
  font-size: 12px;
}
#recvaddr-form .ui.dropdown, #recvaddr-form .ui.input, #recvaddr-form .ui.textarea  {
  min-width: 296px;
}
#recvaddr-form .ui.dropdown > .text > .image, #recvaddr-form .ui.dropdown > .text > img {
  margin-right: 0.5em;
}
#recvaddr-form .ui.dropdown .menu > .item > .image, #recvaddr-form .ui.dropdown .menu > .item > img {
  margin-right: 0.5em;
}
#settings .ui.header {
  color: #f0f0f0;
  margin-top: 14px;
}
#settings .ui.dividing.header {
  border-bottom: 1px solid rgba(221,219,217,.55);
}
#settings .ui.checkbox label {
  color: #f0f0f0;
}
#settings-modal .content {
  text-align: center;
}
#send-coins {
  position: absolute;
  top: 216px;
  left: 28px;
  z-index: 3;
  background: rgba(128,128,128,0.3);
  width: calc(100% - 56px);
  min-width: 284px;
  min-height: 266px;
  color: #fafafa;
  font: normal 400 13px/1 'arial', sans-serif;
  padding: 7px 14px 14px;
  height: auto;
  max-height: calc(100vh - 288px);
  display: none;
  pointer-events: none;
}
#send-coins .ui.label, #send-coins .ui.buttons, #send-coins .ui.input, #send-coins label, #send-coins .content .header, #send-coins .description {
  pointer-events: auto;
}
#send-coins input::selection {
  background-color: rgba(100,100,100,.4);
  color: rgba(255,255,255,.87);
}
#send-coins .ui.label.sendcoins {
  text-align: center;
  background-color: rgba(213, 113, 113, 0.5);
  color: #eee;
  padding: 5px 6px 5px 6px;
}
#send-coins .ui.form label {
  text-align: left;
  color: rgba(238, 238, 238, .8);
}
#send-coins .ui.form input[type="text"] {
  background: rgba(128, 128, 128, 0.6);
  color: #f0f0f0;
}
#send-coins .btn-tx-send {
  background: rgba(113, 120, 54, 0.5);
}
#send-coins .btn-tx-send.loading {
  background: rgba(217, 231, 120, 0.8);
}
#send-coins .btn-tx-send:hover, #send-coins .btn-tx-send:focus {
  background: rgba(217, 231, 120, 0.8);
}
#send-coins .btn-close {
  position: absolute;
  right: 0em;
  top: 0.4em;
  color: rgba(0,0,0,.3);
}
.btn-close {
  cursor: pointer;
}
#send-coins .btn-maximize {
  position: absolute;
  right: 1.5em;
  top: 0.4em;
  color: rgba(0,0,0,.3);
}
#send-coins .ui.input > input.center {
  text-align: center;
}
#send-coins .ui.input > input.right {
  text-align: right;
}
#send-coins .ui.buttons.utxoctrl {
  display: block;
  position: absolute;
  top: -17.6px;
  right: 0;
}
#send-coins .ui.form input[name="amount"] {
  border-top-right-radius: 0;
}
#send-coins .utxoctrl .ui.button {
  padding: 3px 2px 3px 2px;
  color: #f0f0f0;
}
#send-coins .ui.basic.buttons .ui.button {
  color: rgba(238, 238, 238, .8) !important;
}
#send-coins .ui.basic.buttons.utxoctrl {
  border-top-left-radius: .28571429rem;
  border-top-right-radius: .28571429rem;
  border-bottom-left-radius: 0;
  border-bottom-right-radius: 0;
  border-bottom: 0;
}
#send-coins .ui.buttons.utxoctrl .button:first-child {
  border-bottom-left-radius: 0;
}
#send-coins .ui.buttons.utxoctrl .button:last-child {
 border-bottom-right-radius: 0;
}
#send-coins .ui.buttons.utxoctrl .ui.button.sendutxos {
  pointer-events: none;
  width: 60px;
}
#send-coins .btn-send-tools {
  margin-left: 33px;
}
#qrcanvas-modal {
  position: absolute;
  top: 0;
  left: 0;
  margin: 7px 7px;
  width: calc(100% - 14px);
  height: calc(100% - 14px);
  border-radius: 12px;
  overflow: hidden;
  object-fit: cover;
  z-index: 5;
}
#qrreader-seg {
  height: calc(100vh - 252px);
  margin: 16px 0;
  bottom: 30px;
  min-width: 296px;
  min-height: 393px;
  object-fit: cover;
  background: linear-gradient(0deg, rgba(136,136,136,0.6), rgba(221,221,221,0.6));
}
#qrcode-modal.ui.modal {
  min-height: 550px;
  min-width: 324px;
}
#qrcode-modal.ui.modal .scrolling.content {
  width: 100%;
  max-height: calc(100vh - 240px);
  min-height: 400px;
  overflow: hidden;
}
#qrcode-modal.ui.modal .ui.header, #qrcode-modal.ui.modal .content, #qrcode-modal.ui.modal .actions,
#passphrase-modal.ui.modal .ui.header, #passphrase-modal.ui.modal .content, #passphrase-modal.ui.modal .actions {
  min-width: 324px;
}
@media only screen and (max-width:767px) {
.ui.modal>.header {
  padding:.75rem 1rem!important;
}
}
#passphrase-modal-seg {
  margin: 16px 0;
  bottom: 30px;
  min-width: 296px;
  object-fit: cover;
  background: linear-gradient(0deg, rgba(136,136,136,0.6), rgba(221,221,221,0.6));
}
#passphrase-modal-seg .ui.form input[type="text"], #passphrase-modal-seg .ui.form input[type="password"] {
    background: rgba(43, 51, 45, 0.6);
    color: #f0f0f0;
}
#passphrase-modal-seg .ui.form input[type="text"]:focus, #passphrase-modal-seg .ui.form input[type="password"]:focus, #passphrase-modal-seg .ui.form input[type="text"]::selection, #passphrase-modal-seg .ui.form input[type="password"]::selection {
    color: #fafafa;
}
#passphrase-modal.ui.modal {
  min-width: 324px;
}
#passphrase-modal.ui.modal .scrolling.content {
  width: 100%;
  max-height: 80px;
  min-height: 80px;
  overflow: hidden;
}
#passphrase-modal {
  margin-top: 120px;
}
#send-coins .ui.list {
  text-align: left;
}
#send-coins .content .header, #send-coins .ui.list > .item .description {
  color: rgba(238, 238, 238, .8);
  margin-bottom: 2px;
}
#send-coins .ui.list.uri-options {
  height: auto;
  min-height: 0;
  max-height: calc(100vh - 550px);
  overflow-y: auto;
  overflow-x: hidden;
  scrollbar-color: rgba(77, 77, 77, 0.5) rgba(100, 100, 100, 0.3);
  scrollbar-width: thin;
  -webkit-overflow-scrolling: touch;
  word-wrap: break-word;
  overflow-wrap: break-word;
}
#send-coins .ui.list.uri-options .header {
  font-size: .92857143em;
}
#clipboard {
  position: absolute;
  visibility: hidden;
  bottom: 0;
  right: 0;
  z-index: 0;
  background-color: rgba(100, 100, 100, .2);
  border: none;
  font-size: 9px;
  width: 100px;
  height: 10px;
  color: #eee;
  text-align: right;
}
#connection-monitor {
  position: absolute;
  top: 0;
  right: 0;
  color: rgba(145, 118, 54, .7);
}
#selectlang {
  position: absolute;
  top: 0;
  right: 24px;
  z-index: 3;
  width: 70px;
  padding: 0 4px;
}
#selectlang.active {
  background-color: rgba(72,81,75,.4);
  border-radius: 8px;
}
#selectlang .title, #selectlang .content, #selectlang .ui.checkbox label {
  color: #eee;
  font-size: 11px;
  line-height: 11px;
}
#selectlang .content {
  margin-left: 4px;
}
#selectlang .title .icon {
  line-height: 9px;
}
#selectlang .ui.checkbox label {
  padding-top: 3px;
}
#selectlang .content {
  margin-top: -10px;
}
#selectlang .title .dropdown.small.icon {
  font-size: 9px;
  line-height: 9px;
  margin-right: 0;
}
.ui.form .field.warning input[type="text"] {
  background: #a4831e;
  border-color: #ffe78f;
  color: #f5eccb;
  border-radius: '';
  -webkit-box-shadow: none;
  box-shadow: none;
}
@media screen and (max-width: 350px) {
.intro-body .seed-seg, .intro-body .mnemonic-seg, .intro-body .wallet-body {
  margin: 0 4px;
  min-width: 312px;
}
.wallet-body {
  height: calc(100% - 149px);
}
#wallet-balance, #send-coins, #receive-address {
  left: 18px;
  width: calc(100% - 36px);
}
#wallet-balance {
  top: 122px;
}
#send-coins, #receive-address {
  top: 186px;
}
#send-coins {
  padding: 7px 7px 14px;
}
.ui.buttons.sendrecv {
  margin: 0 14px;
}
.ui.container.wallet-btns, .ui.container.method-selector {
  margin-left: 4px !important;
  margin-right: 4px !important;
}
#recvaddr-form .ui.dropdown > .text, #recvaddr-form .ui.dropdown .menu > .item {
  font-size: 10px;
}
#receive-address .address {
  font-size: 11px;
}
#recv-modal .qrcode {
  margin-top: 2em;
}
.intro .caption {
  font: normal 300 24px/1 'Josefin Sans', sans-serif;
}
.wallet-head {
  position: relative;
  width: 100%;
  height: 114px;
}
}
@media screen and (max-width: 320px) {
#selectlang {
  left: 227px;
}
#connection-monitor {
  left: 300px;
}
}
@media screen and (max-height: 600px) {
.intro .caption {
  font : normal 300 12px/1 'Josefin Sans', sans-serif;
  text-align: center;
  width: 100%;
  position: absolute;
  top: 0;
  left: 0;
  margin: 6px 0;
  padding: 0;
}
.wallet-head {
  position: relative;
  width: 100%;
  height: 74px;
}
.wallet-btns {
  margin-top: -2px;
}
.wallet-body {
  height: calc(100% - 114px);
}
#wallet-balance {
  top: 76px;
}
#send-coins, #receive-address {
  top: 130px;
}
#section1 .intro-head {
  height: 102px;
}
#section2 .intro-head {
  height: 126px;
}
.method-selector .title {
  color: #fff;
  font : normal 400 14px/1 'Josefin Sans', sans-serif;
  padding: 8px 10px 8px 10px;
  height: 42px;
  display: flex;
  justify-content: center;
  text-align: left;
}
.method-selector .button {
  width: 152px;
  z-index: 2;
}
#section2 .method-selector .title {
  height: 67px;
}
#section1 .intro-body {
  height: calc(100% - 104px);
}
#section2 .intro-body {
  height: calc(100% - 128px);
}
.intro-body .seed-seg {
  min-height: 275px;
}
.intro-body .mnemonic-seg {
  min-height: 343px;
}
.intro-body .medit-autocomp {
  position: absolute;
  bottom: 14px;
  z-index: 2;
  display: inline-block;
  height: calc(100% - 274px - 21px - 35px + 14px + 7px);
}
.ui.cards.seed-card-holder {
  top: -10px;
}
.ui.cards > .card.seed-card {
  margin: .2em .5em;
}
.ui.card.seed-card > .bt-seed-del {
  top: 0;
  right: -9px;
}
}
"""
