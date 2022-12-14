import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    Jsrunner.shared.registerHandler('testMethod', (args) async {
      return 'FROM dart => $args';
    });

    _loadExampleHtml();

    debugPrint('state init\'ed');
  }

  Future<void> _loadExampleHtml() async {
    // final html = await rootBundle.loadString('lib/example.html');
    final js = await rootBundle.loadString('lib/example.js');
    //  await Jsrunner.shared.loadHTML(html);

    await Jsrunner.shared.evalJavascript(js);
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
              TextButton(
                onPressed: () => _callFailureJS(),
                child: const Text('Call Failure Code'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _callJS() async {
    final result = await Jsrunner.shared.callJS("randomFunc", [
      1,
      "hello",
      [3, "x"]
    ]);
    debugPrint(' --> result: $result');
  }

  Future<void> _callFailureJS() async {
    final result = await Jsrunner.shared.callJS("failureFunc", [
      "hish",
    ]);
    debugPrint('failure result: $result');
  }
}
