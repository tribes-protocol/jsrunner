import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

class Jsrunner {
  final MethodChannel _channel = const MethodChannel('jsrunner');
  final _uuid = const Uuid();
  final _callbacks = <String, StreamController<dynamic>>{};
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
        final msg = WebkitMessage.fromMap(
          Map<String, dynamic>.from(call.arguments),
        );
        _didReceiveMessage.add(msg);

        final data = msg.data;
        final response = _Response(
          data['uuid'],
          data['value'],
          data['error'] == null
              ? null
              : JsrunnerResponseError(
                  data['error']['message'] as String,
                  data['error']['code'] as int?,
                ),
        );

        final callback = _callbacks[response.uuid];
        if (callback == null) {
          return;
        }

        final error = response.error;
        _callbacks.remove(response.uuid);

        if (error != null) {
          callback.addError(error);
        } else {
          callback.add(response.value as dynamic);
        }

        break;
    }
  }

  Future<T> call<T>(String funcName, [dynamic arguments]) async {
    final subject = StreamController<T>();
    final uuid = _uuid.v4();

    _callbacks[uuid] = subject;

    final args = <String, dynamic>{
      'request': jsonEncode({
        'uuid': uuid,
        'funcName': funcName,
        'args': arguments,
      }),
    };

    await _channel.invokeMethod('call', args);

    return subject.stream.first;
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

class JsrunnerResponseError implements Exception {
  String message;
  int? code;

  JsrunnerResponseError(this.message, this.code);

  @override
  String toString() {
    return [code?.toInt(), message].where((e) => e != null).join(': ');
  }
}

class _Response {
  String uuid;
  dynamic value;
  JsrunnerResponseError? error;

  _Response(this.uuid, this.value, this.error);
}
