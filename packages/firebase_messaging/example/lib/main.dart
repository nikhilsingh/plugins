// Copyright 2017 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

void callback(FirebaseMessage m, MessageEvent e) async {
  print('Message $m Event: $e');
  final SendPort send =
  IsolateNameServer.lookupPortByName('messaging_send_port');
  send?.send(e.toString());
}


class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  ReceivePort port = ReceivePort();
  String messagingState = 'N/A';
  final List<MessageEvent> triggers = <MessageEvent>[
    MessageEvent.message,
    MessageEvent.resume,
    MessageEvent.remote,
    MessageEvent.launch
  ];

  @override
  void initState() {
    super.initState();
    IsolateNameServer.registerPortWithName(
        port.sendPort, 'messaging_send_port');
    port.listen((dynamic data) {
      print('Event: $data');
      setState(() {
        messagingState = data;
      });
    });
    initPlatformState();

  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    print('Initializing...');
    await MessagingManager.initialize(new IosNotificationSettings(),callback);
    print('Initialization done');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
          appBar: AppBar(
            title: const Text('Flutter Firebase Messaging Example'),
          ),
          body: Container(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text('Current state: $messagingState'),
                    Center(
                      child: RaisedButton(
                          child: const Text('Unregister'),
                          onPressed: () =>
                              MessagingManager.deinitMessaging()),
                    )
                    ,
                    Center(
                        child: RaisedButton(
                            child: const Text('Topic'),
                            onPressed: () =>
                                MessagingManager.subscribeToTopic("IlEFVS78rcW8HDASlvzfh0ZXert1"))),

                  ]))),
    );
  }
}

Future<void> main() async {
  runApp(MyApp());
}


