@JS("ZXing")
library zxingjs;

import 'dart:async';
import 'dart:html';
import 'dart:js';

import 'package:flutter/services.dart';
import 'package:js/js.dart';
import 'package:js/js_util.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

class BarcodeScanPlugin {
  Completer<String> _completer;
  BrowserMultiFormatReader _codeReader;

  static void registerWith(Registrar registrar) {
    final MethodChannel channel = MethodChannel(
      'de.mintware.barcode_scan',
      const StandardMethodCodec(),
      registrar.messenger
    );
    final BarcodeScanPlugin instance = new BarcodeScanPlugin();
    channel.setMethodCallHandler(instance.handleMethodCall);
  }

  Future<String> handleMethodCall(MethodCall call) async {
    _ensureMediaDevicesSupported();
    _createCSS();
    _addScript('assets/packages/barcode_scan_web/assets/corejs.js');
    _addScript('assets/packages/barcode_scan_web/assets/adapter.js');
    _addScript('assets/packages/barcode_scan_web/assets/zxingjs.js');
    _createHTML();
    document.querySelector('#toolbar p').addEventListener('click', (event) => _onCloseByUser());
    _startScanning();
    _completer = new Completer<String>();
    return _completer.future;
  }

  void _addScript(String src) {
    var script = document.createElement('script');
    script.setAttribute('type', 'text/javascript');
    script.setAttribute('src', src);
    document.head.append(script);
  }

  void _ensureMediaDevicesSupported() {
    if (window.navigator.mediaDevices == null) {
      throw PlatformException(
        code: 'CAMERA_ACCESS_NOT_SUPPORTED',
        message: "Camera access not supported by browser2"
      );
    }
  }

  void _createCSS() {
    var link = document.createElement('link');
    link.setAttribute('rel', 'stylesheet');
    link.setAttribute('href', 'assets/packages/barcode_scan_web/assets/styles.css');
    document.querySelector('head').append(link);
  }

  void _createHTML() {
    var containerDiv = document.createElement('div');
    containerDiv.id = 'container';
    containerDiv.innerHtml = '''
    <div id="toolbar">
      <p>X</p>
      <div id="clear"></div>
    </div>
    <div id="scanner">
      <video id="video"></video>
    </div>
    <div id="cover">
      <div id="topleft"></div>
      <div id="lefttop"></div>
      <div id="topright"></div>
      <div id="righttop"></div>
      <div id="bottomleft"></div>
      <div id="leftbottom"></div>
      <div id="bottomright"></div>
      <div id="rightbottom"></div>
    </div>
    ''';
    document.body.append(containerDiv);
  }

  void _startScanning() {
    _codeReader = new BrowserMultiFormatReader();
    var resultPromise = _codeReader.decodeOnceFromVideoDevice(null, 'video');
    resultPromise.then(allowInterop(this.onCodeScanned), allowInterop(this.reject));
  }

  void onCodeScanned(ScanResult scanResult) {
    if (!_completer.isCompleted) {
      _completer.complete(scanResult.text);
      _close();
    }
  }

  void _onCloseByUser() {
    _close();
    _completer.completeError(PlatformException(
      code: 'USER_CANCELED',
      message: 'User closed the scan window'
    ));
  }

  void _close() {
    _codeReader.reset();
    document.getElementById('container').remove();
  }

  void reject(reject) {
    _completer.completeError(PlatformException(
      code: 'PERMISSION_NOT_GRANTED',
      message: 'Permission to access the camera not granted'
    ));
    _close();
  }
}

@JS()
class BrowserMultiFormatReader {
  external Promise<ScanResult> decodeOnceFromVideoDevice(int deviceId, String videoElementId);
  external bool isMediaDevicesSupported();
  external void reset();
}

@JS()
@anonymous
class ScanResult {
  external String get text; 
}

@JS()
class Promise<T> {
  external Promise(void executor(void resolve(T result), Function reject));
  external Promise then(void onFulfilled(T result), [Function onRejected]);
}