import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jsrunner/jsrunner.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final String _platformVersion = 'Unknown';

  @override
  void initState() {
    super.initState();

    Jsrunner.shared.stateChanged.listen((state) {
      debugPrint('stateChanged: $state');
    });

    Jsrunner.shared.didReceiveMessage.listen((message) {
      debugPrint('didReceiveMessage: $message');
    });

    Jsrunner.shared.loadHTML('<html>'
        '<head><script>'
        'window.x = window.webkit ? window.webkit.messageHandlers.native : window.native;'
        '</script></head>'
        '<body></body></html>');

    debugPrint('state init\'ed');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Running on: $_platformVersion\n'),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => _callJS(),
                child: const Text('Call Code'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _callJS() async {
    await Jsrunner.shared.evalJavascript(
      'window.x.postMessage(\'{ "name": "hello world" }\'); true;',
    );
  }
}
