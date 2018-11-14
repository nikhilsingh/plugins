// Copyright 2017 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:firebase_messaging/FirebaseMessaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = new FlutterLocalNotificationsPlugin();

Future onSelectNotification(String payload) async {
  if (payload != null) {
    print('notification payload: ' + payload);
  }
}

/// This "Headless Task" is run when app is terminated.
void firebaseMessagingHeadlessTask() async {
  print('[FirebaseMessaging] Headless event received.');

  var initializationSettingsAndroid =
  new AndroidInitializationSettings('app_icon');
  var initializationSettingsIOS = new IOSInitializationSettings(registerUNUserNotificationCenterDelegate: false);
  var initializationSettings = new InitializationSettings(
      initializationSettingsAndroid, initializationSettingsIOS);
  flutterLocalNotificationsPlugin = new FlutterLocalNotificationsPlugin();
  flutterLocalNotificationsPlugin.initialize(initializationSettings,
      selectNotification: onSelectNotification);

  var androidPlatformChannelSpecifics = new AndroidNotificationDetails(
      'your channel id', 'your channel name', 'your channel description',
      importance: Importance.Max, priority: Priority.High);
  var iOSPlatformChannelSpecifics = new IOSNotificationDetails();
  var platformChannelSpecifics = new NotificationDetails(
      androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);
  flutterLocalNotificationsPlugin.show(
      0, 'Msg Title', "Decrypted", platformChannelSpecifics,
      payload: "Test");
  FirebaseMessaging.finish();
}

void main() {
  // Enable integration testing with the Flutter Driver extension.
  // See https://flutter.io/testing/ for more info.
  runApp(new MyApp());

  // Register to receive BackgroundFetch events after app is terminated.
  // Requires {stopOnTerminate: false, enableHeadless: true}
  FirebaseMessaging.registerHeadlessTask(firebaseMessagingHeadlessTask);
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    initPlatformState();
  }



  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    print('Initializing...');
    var initializationSettingsAndroid =
    new AndroidInitializationSettings('app_icon');
    var initializationSettingsIOS = new IOSInitializationSettings(registerUNUserNotificationCenterDelegate: false);
    var initializationSettings = new InitializationSettings(
        initializationSettingsAndroid, initializationSettingsIOS);
    flutterLocalNotificationsPlugin = new FlutterLocalNotificationsPlugin();
    flutterLocalNotificationsPlugin.initialize(initializationSettings,
        selectNotification: onSelectNotification);

    FirebaseMessaging.configure(IosNotificationSettings(), () async {
      print('[FirebaseMessaging] Event received');
      // IMPORTANT:  You must signal completion of your fetch task or the OS can punish your app
      // for taking too long in the background.
      FirebaseMessaging.finish();
    }).then((status) {
      print('[FirebaseMessaging] Initialization done');
    }).catchError((Error e) {
      print('[FirebaseMessaging] ERROR: $e');
    });
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
                    Text('Current state:'),
                    Center(
                      child: RaisedButton(
                          child: const Text('Unregister'),
                          onPressed: () => FirebaseMessaging.unsubscribeToTopic(
                              "IlEFVS78rcW8HDASlvzfh0ZXert1")),
                    ),
                    Center(
                        child: RaisedButton(
                            child: const Text('Topic'),
                            onPressed: () => FirebaseMessaging.subscribeToTopic(
                                "IlEFVS78rcW8HDASlvzfh0ZXert1"))),
                  ]))),
    );
  }
}
