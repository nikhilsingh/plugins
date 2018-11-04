// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:platform/platform.dart';

import 'package:firebase_messaging/src/callback_dispatcher.dart';
import 'package:firebase_messaging/src/firebase_message.dart';

const int _kMessageEvent = 1;
const int _kResumeEvent = 2;
const int _kRemoteEvent = 3;
const int _kLaunchEvent = 3;

/// Valid message events
enum MessageEvent { message,resume, remote, launch }

// Internal.
int messageEventToInt(MessageEvent e) {
  switch (e) {
    case MessageEvent.message:
      return _kMessageEvent;
    case MessageEvent.resume:
      return _kResumeEvent;
    case MessageEvent.remote:
      return _kRemoteEvent;
    case MessageEvent.launch:
      return _kLaunchEvent;
    default:
      throw UnimplementedError();
  }
}

// Internal.
MessageEvent intToMessageEvent(int e) {
  switch (e) {
    case _kMessageEvent:
      return MessageEvent.message;
    case _kResumeEvent:
      return MessageEvent.resume;
    case _kRemoteEvent:
      return MessageEvent.remote;
    case _kLaunchEvent:
      return MessageEvent.launch;
    default:
      throw UnimplementedError();
  }
}


class MessagingManager {
  static const MethodChannel _channel =
  MethodChannel('plugins.flutter.io/firebase_messaging');
  static const MethodChannel _background =
  MethodChannel('plugins.flutter.io/firebase_messaging_background');

  /// Initialize the plugin and request relevant permissions from the user.
  static Future<void> initialize(IosNotificationSettings iOSSetting, void Function(FirebaseMessage msg, MessageEvent event)
  msgCallback) async {
    final CallbackHandle callback =
    PluginUtilities.getCallbackHandle(callbackDispatcher);

    await _channel.invokeMethod('FirebaseMessaging.initializeService',
        <dynamic>[callback.toRawHandle(),PluginUtilities.getCallbackHandle(msgCallback).toRawHandle(),iOSSetting.toMap()]);
  }

  final StreamController<IosNotificationSettings> _iosSettingsStreamController =
      StreamController<IosNotificationSettings>.broadcast();

  /// Stream that fires when the user changes their notification settings.
  ///
  /// Only fires on iOS.
  Stream<IosNotificationSettings> get onIosSettingsRegistered {
    return _iosSettingsStreamController.stream;
  }

  /// Promote the geofencing service to a foreground service.
  ///
  /// Will throw an exception if called anywhere except for a geofencing
  /// callback.
  static Future<void> promoteToForeground() async =>
      await _background.invokeMethod('FirebaseMessaging.promoteToForeground');

  /// Demote the geofencing service from a foreground service to a background
  /// service.
  ///
  /// Will throw an exception if called anywhere except for a geofencing
  /// callback.
  static Future<void> demoteToBackground() async =>
      await _background.invokeMethod('FirebaseMessaging.demoteToBackground');

  static Future<bool> subscribeToTopic(String topic) async => await _channel
      .invokeMethod('FirebaseMessaging.subscribeToTopic', <dynamic>[topic]);

  static Future<bool> unsubscribeToTopic(String topic) async => await _channel
      .invokeMethod('FirebaseMessaging.unsubscribeFromTopic', <dynamic>[topic]);

  /// Stop receiving geofence events for an identifier associated with a
  /// geofence region.
  static Future<bool> deinitMessaging() async => await _channel
      .invokeMethod('FirebaseMessaging.deinitialize');
}


///// Implementation of the Firebase Cloud Messaging API for Flutter.
/////
///// Your app should call [requestNotificationPermissions] first and then
///// register handlers for incoming messages with [configure].
//abstract class FirebaseMessaging {
//  /// Initialize the plugin and request relevant permissions from the user.
//  static Future<bool> initialize() async;
//
//  factory FirebaseMessaging() => _instance;
//
//  @visibleForTesting
//  FirebaseMessaging.private(MethodChannel channel, Platform platform)
//      : _channel = channel,
//        _platform = platform;
//
//  static final FirebaseMessaging _instance = FirebaseMessaging.private(
//      const MethodChannel(_METHOD_CHANNEL_NAME), const LocalPlatform());
//
//  final MethodChannel _channel;
//  final Platform _platform;
//
//  String _token;
//
//  /// On iOS, prompts the user for notification permissions the first time
//  /// it is called.
//  ///
//  /// Does nothing on Android.
//  void requestNotificationPermissions(
//      [IosNotificationSettings iosSettings = const IosNotificationSettings()]) {
//    if (!_platform.isIOS) {
//      return;
//    }
//    _channel.invokeMethod(
//        'requestNotificationPermissions', iosSettings.toMap());
//  }
//
//  final StreamController<IosNotificationSettings> _iosSettingsStreamController =
//      StreamController<IosNotificationSettings>.broadcast();
//
//  /// Stream that fires when the user changes their notification settings.
//  ///
//  /// Only fires on iOS.
//  Stream<IosNotificationSettings> get onIosSettingsRegistered {
//    return _iosSettingsStreamController.stream;
//  }
//
//  /// Sets up [MessageHandler] for incoming messages.
//  void configure() {
//    _channel.setMethodCallHandler(_handleMethod);
//    _channel.invokeMethod('configure');
//  }
//
//  final StreamController<String> _tokenStreamController =
//      StreamController<String>.broadcast();
//
//  /// Fires when a new FCM token is generated.
//  Stream<String> get onTokenRefresh {
//    return _tokenStreamController.stream;
//  }
//
//  /// Returns the FCM token.
//  Future<String> getToken() {
//    return _token != null ? Future<String>.value(_token) : onTokenRefresh.first;
//  }
//
//  /// Subscribe to topic in background.
//  ///
//  /// [topic] must match the following regular expression:
//  /// "[a-zA-Z0-9-_.~%]{1,900}".
//  void subscribeToTopic(String topic) {
//    _channel.invokeMethod('subscribeToTopic', topic);
//  }
//
//  /// Unsubscribe from topic in background.
//  void unsubscribeFromTopic(String topic) {
//    _channel.invokeMethod('unsubscribeFromTopic', topic);
//  }
//
//  Future<dynamic> _handleMethod(MethodCall call) async {
//    switch (call.method) {
//      case "onToken":
//        final String token = call.arguments;
//        if (_token != token) {
//          _token = token;
//          _tokenStreamController.add(_token);
//        }
//        return null;
//      case "onIosSettingsRegistered":
//        _iosSettingsStreamController.add(IosNotificationSettings._fromMap(
//            call.arguments.cast<String, bool>()));
//        return null;
//      default:
//        throw UnsupportedError("Unrecognized JSON message");
//    }
//  }
//}

class IosNotificationSettings {
  const IosNotificationSettings({
    this.sound = true,
    this.alert = true,
    this.badge = true,
  });

  IosNotificationSettings._fromMap(Map<String, bool> settings)
      : sound = settings['sound'],
        alert = settings['alert'],
        badge = settings['badge'];

  final bool sound;
  final bool alert;
  final bool badge;

  @visibleForTesting
  Map<String, dynamic> toMap() {
    return <String, bool>{'sound': sound, 'alert': alert, 'badge': badge};
  }

  @override
  String toString() => 'PushNotificationSettings ${toMap()}';
}
