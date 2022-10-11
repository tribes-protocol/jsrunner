import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

typedef JsFlutterHandler = Future<dynamic> Function(List<dynamic> args);

class Jsrunner {
  final MethodChannel _channel = const MethodChannel('jsrunner');
  final _uuid = const Uuid();
  final _callbacks = <String, StreamController<dynamic>>{};
  final _stateChanged = StreamController<WebViewStateChanged>.broadcast();
  final _didReceiveMessage = StreamController<WebkitMessage>.broadcast();
  final _handlers = <String, JsFlutterHandler>{};

  Stream<WebViewStateChanged> get stateChanged => _stateChanged.stream;
  Stream<WebkitMessage> get didReceiveMessage => _didReceiveMessage.stream;

  static Jsrunner shared = Jsrunner._();

  Jsrunner._() {
    _channel.setMethodCallHandler(_handleMessages);
  }

  void registerHandler(String funcName, JsFlutterHandler handler) {
    assert(_handlers[funcName] == null);
    _handlers[funcName] = handler;
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

        try {
          final data = msg.data;
          final callType = _CallType.fromString(data['type']);

          switch (callType) {
            case _CallType.request:
              await _handleRequestCallType(msg);
              break;

            case _CallType.response:
              _handleResponseCallType(msg);
              break;
          }
        } catch (e) {
          debugPrint('error on didReceiveMessge $e');
        }

        break;
    }
  }

  Future<void> _handleRequestCallType(WebkitMessage msg) async {
    final args = List<dynamic>.from(msg.data['args']);
    final handler = _handlers[msg.data['funcName']];

    if (handler == null) {
      await deliverResponseFromNative(
        funcName: msg.data['funcName'],
        uuid: msg.data['uuid'],
        error: "${msg.data['funcName']} Handler not found",
      );
      return;
    }

    try {
      final result = await handler(args);
      await deliverResponseFromNative(
        funcName: msg.data['funcName'],
        uuid: msg.data['uuid'],
        value: jsonEncode(result),
      );
    } catch (e) {
      await deliverResponseFromNative(
        funcName: msg.data['funcName'],
        uuid: msg.data['uuid'],
        error: "$e",
      );
      debugPrint('error on handleRequestCallType $e');
    }
  }

  void _handleResponseCallType(WebkitMessage msg) {
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
  }

  Future<T> callJS<T>(String funcName, [dynamic arguments]) async {
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

    await _channel.invokeMethod('callJS', args);

    return subject.stream.first;
  }

  Future<void> deliverResponseFromNative<T>({
    required String funcName,
    required String uuid,
    String? value,
    String? error,
  }) async {
    final args = <String, dynamic>{
      'response': jsonEncode({
        'uuid': uuid,
        'funcName': funcName,
        if (value != null) 'value': value,
        if (error != null) 'error': error,
      }),
    };

    await _channel.invokeMethod('respondToNative', args);
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

enum _CallType {
  response,
  request;

  factory _CallType.fromString(String value) {
    switch (value) {
      case 'response':
        return _CallType.response;

      case 'request':
        return _CallType.request;
    }
    throw Exception('Unknown _CallType: $value');
  }
}
