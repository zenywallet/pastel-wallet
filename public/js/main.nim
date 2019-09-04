# Copyright (c) 2019 zenywallet
# nim js -d:release main.nim

include karax / prelude
import jsffi except `&`
import strutils
import unicode
import sequtils

{.emit: """
var camDevice = (function() {
  var cam_ids = [];
  var sel_cam = null;
  var sel_cam_index = 0;
  navigator.mediaDevices.enumerateDevices().then(function(devices) {
    devices.forEach(function(device) {
      if(device.kind == 'videoinput') {
        cam_ids.push(device);
      }
    });
  });
  return {
    next: function() {
      if(cam_ids.length > 0) {
        if(sel_cam == null) {
          sel_cam_index = cam_ids.length - 1;
          sel_cam = cam_ids[sel_cam_index].deviceId;
        } else {
          sel_cam_index++;
          if(sel_cam_index >= cam_ids.length) {
            sel_cam_index = 0;
          }
          sel_cam = cam_ids[sel_cam_index].deviceId;
        }
      }
      return sel_cam;
    },
    count: function() {
      return cam_ids.length;
    }
  };
})();

var qrReader = (function() {
  var mode_show = true;
  var video = null;
  var qr_instance = null;

  function video_status_change() {
    if(mode_show) {
      $('.bt-scan-seed').css('visibility', 'hidden');
      $('.camtools').css('visibility', 'visible');
      $('.qr-scanning').show();
    } else {
      $('.qr-scanning').hide();
      $('.camtools').css('visibility', 'hidden');
      $('.bt-scan-seed').css('visibility', 'visible');
    }
  }

  function video_stop() {
    mode_show = false;
    video_status_change();
  }

  function cb_done(data) {
    console.log(data);
  }

  function stop_qr_instance(cb) {
    if(qr_instance) {
      setTimeout(function() {
        if(qr_instance) {
          qr_instance.stop();
          qr_instance = null;
          if(video) {
            video.removeAttribute('src');
            video.load();
          }
          if(cb) {
            cb();
          }
        }
      }, 1);
    } else {
      if(cb) {
        cb();
      }
    }
  }

  return {
    show: function() {
      stop_qr_instance(function() {
        mode_show = true;
        var scandata = "";
        var cb_once = 0;
        var qr = new QCodeDecoder();
        qr_instance = qr;
        var qr_stop = function() {
          setTimeout(function() {
            qr.stop();
            video_stop();
          }, 1);
        }
        if(qr.isCanvasSupported() && qr.hasGetUserMedia()) {
          video = document.querySelector('#qrvideo');
          video.onloadstart = video_status_change;
          video.autoplay = true;

          function resultHandler(err, result) {
            if(err) {
              qr_stop();
              return;
            }
            if(scandata == result) {
              if(cb_once) {
                return;
              }
              cb_once = 1;
              qr_stop();
              cb_done(result);
            }
            scandata = result;
          }
          qr.setSourceId(camDevice.next());
          qr.decodeFromCamera(video, resultHandler);
        }
      });
    },
    hide: function() {
      mode_show = false;
      stop_qr_instance();
    }
  }
})();
""".}

#var document {.importc, nodecl.}: JsObject
#var console {.importc, nodecl.}: JsObject
proc jq(selector: cstring): JsObject {.importcpp: "$$(#)".}
proc replace*(s, a, b: cstring): cstring {.importcpp, nodecl.}
proc join*(s: cstring): cstring {.importcpp, nodecl.}
proc includes*(s: seq[cstring], a: cstring): bool {.importcpp, nodecl.}
var camDevice {.importc, nodecl.}: JsObject

type ImportType {.pure.} = enum
  SeedCard
  Mnemonic

var currentImportType = ImportType.SeedCard

proc importTypeButtonClass(importType: ImportType): cstring =
  if importType == currentImportType:
    "ui olive button"
  else:
    "ui grey button"

proc importSelector(importType: ImportType): proc() =
  result = proc() =
    currentImportType = importType

var showScanSeedBtn = true
var showScanning = true
var showCamTools = true

proc showQr(): proc() =
  result = proc() =
    asm """
      qrReader.show();
    """

proc camChange(): proc() =
  result = proc() =
    asm """
      qrReader.show();
    """

proc camClose(): proc() =
  result = proc() =
    asm """
      qrReader.hide();
    """

proc appMain(): VNode =
  result = buildHtml(tdiv):
    section(id="section1", class="section"):
      tdiv(class="intro"):
        tdiv(class="intro-head"):
          tdiv(class="caption"): text "Pastel Wallet"
          tdiv(class="ui container method-selector"):
            tdiv(class="title"): text "Import the master seed to start your wallet."
            tdiv(class="ui buttons"):
              button(class=importTypeButtonClass(ImportType.SeedCard), onclick=importSelector(ImportType.SeedCard)):
                italic(class="qrcode icon")
                text "Seed card"
              tdiv(class="or")
              button(class=importTypeButtonClass(ImportType.Mnemonic), onclick=importSelector(ImportType.Mnemonic)):
                italic(class="list alternate icon")
                text "Mnemonic"
        tdiv(class="intro-body"):
          if currentImportType == ImportType.SeedCard:
            tdiv(class="ui enter aligned segment"):
              if showScanning:
                tdiv(class="qr-scanning"):
                  tdiv()
                  tdiv()
              if showScanSeedBtn:
                tdiv(class="ui teal labeled icon button bt-scan-seed", onclick=showQr()):
                  text "Scan seed card with camera"
                  italic(class="camera icon")
              if showCamTools:
                tdiv(class="ui small basic icon buttons camtools"):
                  button(class="ui button", onclick=camChange()):
                    italic(class="camera icon")
                  button(class="ui button", onclick=camClose()):
                    italic(class="window close icon")
              video(id="qrvideo")
          else:
            tdiv(class="ui enter aligned segment")

proc afterScript() =
  jq("#section0").remove()

setRenderer appMain, "main", afterScript



#            tdiv(class="ui small basic icon buttons"):
#              button(id="bt-camchange", class="ui button"):
#                italic(class="retweet icon")
