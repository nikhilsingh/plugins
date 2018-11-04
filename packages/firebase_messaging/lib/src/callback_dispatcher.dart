// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:firebase_messaging/src/messaging_manager.dart';
import 'package:firebase_messaging/src/firebase_message.dart';

void callbackDispatcher() {
  const MethodChannel _backgroundChannel =
  MethodChannel('plugins.flutter.io/firebase_messaging_background');
  WidgetsFlutterBinding.ensureInitialized();

  _backgroundChannel.setMethodCallHandler((MethodCall call) async {
    print("Callback Dispatcher Invoked: ${call.arguments}");
    final List<dynamic> args = call.arguments;
    final Function callback = PluginUtilities.getCallbackFromHandle(
        CallbackHandle.fromRawHandle(args[0]));
    assert(callback != null);
    final FirebaseMessage msg = new FirebaseMessage(true, Map<String, dynamic>.from(args[2]));
    final MessageEvent event = intToMessageEvent(args[1]);
    callback(msg, event);
  });
  print('FirebaseMessaging dispatcher started');
  _backgroundChannel.invokeMethod('FirebaseMessaging.initialized');
}