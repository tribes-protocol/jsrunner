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

        final response = _Response.fromMap(Map<String, dynamic>.from(msg.data));
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

class _ResponseError implements Exception {
  String message;
  int? code;

  _ResponseError(this.message, this.code);

  factory _ResponseError.fromMap(Map<String, dynamic> map) {
    return _ResponseError(map['message'] as String, map['code'] as int?);
  }
}

class _Response {
  String uuid;
  dynamic value;
  _ResponseError? error;

  _Response(this.uuid, this.value, this.error);

  factory _Response.fromMap(Map<String, dynamic> map) {
    return _Response(
      map['uuid'],
      map['value'],
      map['error'] == null ? null : _ResponseError.fromMap(map['error']),
    );
  }
}
