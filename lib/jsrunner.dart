import 'dart:async';

import 'package:flutter/services.dart';

class Jsrunner {
  final MethodChannel _channel = const MethodChannel('jsrunner');
  final _stateChanged = StreamController<WebViewStateChanged>.broadcast();
  final _didReceiveMessage = StreamController<WebkitMessage>.broadcast();

  Stream<WebViewStateChanged> get stateChanged => _stateChanged.stream;
  Stream<WebkitMessage> get didReceiveMessage => _didReceiveMessage.stream;

  static Jsrunner shared = Jsrunner._();

  Jsrunner._() {
    _channel.setMethodCallHandler(_handleMessages);
  }

  Future<void> _handleMessages(MethodCall call) async {
    switch (call.method) {
      case 'stateChanged':
        _stateChanged.add(
          WebViewStateChanged.fromMap(
            Map<String, dynamic>.from(call.arguments),
          ),
        );
        break;

      case 'didReceiveMessage':
        _didReceiveMessage.add(
          WebkitMessage.fromMap(Map<String, dynamic>.from(call.arguments)),
        );
        break;
    }
  }

  Future<void> setOptions({
    required List<String> restrictedSchemes,
    required String webkitHandler,
  }) async {
    final args = <String, dynamic>{
      'restrictedSchemes': restrictedSchemes,
    };

    await _channel.invokeMethod('setOptions', args);
  }

  Future<void> evalJavascript(String script) async {
    final args = <String, dynamic>{
      'script': script,
    };

    await _channel.invokeMethod('evalJavascript', args);
  }

  Future<void> loadHTML(
    String html, {
    String? baseUrl,
  }) async {
    final args = <String, dynamic>{
      'html': html,
    };

    if (baseUrl != null) {
      args['baseUrl'] = baseUrl;
    }

    await _channel.invokeMethod('loadHTML', args);
  }

  Future<void> loadUrl(String url) async {
    final args = <String, dynamic>{
      'url': url,
    };

    await _channel.invokeMethod('loadUrl', args);
  }
}

enum WebViewState {
  didStart,
  didFinish;

  factory WebViewState.fromString(String value) {
    switch (value) {
      case 'didStart':
        return WebViewState.didStart;

      case 'didFinish':
        return WebViewState.didFinish;
    }
    throw Exception('Unknown WebViewState: $value');
  }
}

class WebViewStateChanged {
  final WebViewState type;
  final String url;

  WebViewStateChanged(this.type, this.url);

  factory WebViewStateChanged.fromMap(Map<String, dynamic> map) {
    WebViewState t = WebViewState.fromString(map['type']);
    return WebViewStateChanged(t, map['url']);
  }
}

class WebkitMessage {
  final String name;
  final dynamic data;

  WebkitMessage(this.name, this.data);

  factory WebkitMessage.fromMap(Map<String, dynamic> map) {
    return WebkitMessage(map["name"], map["data"]);
  }
}
