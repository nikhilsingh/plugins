import 'dart:async';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

const _PLUGIN_PATH = "plugins.flutter.io/firebase_messaging";
const _METHOD_CHANNEL_NAME = "$_PLUGIN_PATH/methods";
const _EVENT_CHANNEL_NAME = "$_PLUGIN_PATH/events";


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

class FirebaseMessaging {

  /// See [status].  Background updates are unavailable and the user cannot enable them again. For example, this status can occur when parental controls are in effect for the current user.
  static const int STATUS_RESTRICTED = 0;

  /// See [status].  The user explicitly disabled background behavior for this app or for the whole system.
  static const int STATUS_DENIED = 1;

  /// See [status].  Background updates are available for the app.
  static const int STATUS_AVAILABLE = 2;

  /// See [finish].  New data was successfully downloaded.
  static const int FETCH_RESULT_NEW_DATA = 0;

  /// See [finish].  There was no new data to download.
  static const int FETCH_RESULT_NO_DATA = 1;

  /// See [finish].  An attempt to download data was made but that attempt failed.
  static const int FETCH_RESULT_FAILED = 2;

  static const MethodChannel _methodChannel =
  const MethodChannel(_METHOD_CHANNEL_NAME);

  static const EventChannel _eventChannel =
  const EventChannel(_EVENT_CHANNEL_NAME);

  static Stream<dynamic> _eventsFetch;

  static Future<int> configure(
      IosNotificationSettings config, Function callback) {
    if (_eventsFetch == null) {
      _eventsFetch = _eventChannel.receiveBroadcastStream();

      _eventsFetch.listen((dynamic v) {
        callback();
      });
    }
    Completer completer = new Completer<int>();

    _methodChannel
        .invokeMethod('configure', config.toMap())
        .then((dynamic status) {
      completer.complete(status);
    }).catchError((dynamic e) {
      completer.completeError(e.details);
    });

    return completer.future;
  }

  /// Start the background-fetch API.
  ///
  /// Your `callback` Function provided to [configure] will be executed each time a background-fetch event occurs. NOTE the [configure] method automatically calls [start]. You do not have to call this method after you first [configure] the plugin.
  ///
  static Future<int> start() {
    Completer completer = new Completer<int>();
    _methodChannel.invokeMethod('start').then((dynamic status) {
      completer.complete(status);
    }).catchError((dynamic e) {
      completer.completeError(e.details);
    });
    return completer.future;
  }

  /// Stop the background-fetch API from firing fetch events.
  ///
  /// Your `callback` provided to [configure] will no longer be executed.
  static Future<int> stop() async {
    int status = await _methodChannel.invokeMethod('stop');
    return status;
  }

  static Future<int> get status async {
    int status = await _methodChannel.invokeMethod('status');
    return status;
  }

  static Future<bool> subscribeToTopic(String topic) async {
    bool status = await _methodChannel.invokeMethod('subscribe', <dynamic>[topic]);
    return status;
  }

  static Future<bool> unsubscribeToTopic(String topic) async {
    bool status = await _methodChannel.invokeMethod('unsubscribe', <dynamic>[topic]);
    return status;
  }

  static void finish([int fetchResult]) {
    if (fetchResult == null) {
      fetchResult = FETCH_RESULT_NEW_DATA;
    }
    _methodChannel.invokeMethod('finish', fetchResult);
  }

  static Future<bool> registerHeadlessTask(Function callback) async {
    Completer completer = new Completer<bool>();

    // Two callbacks:  the provided headless-task + _headlessRegistrationCallback
    List<int> args = [
      PluginUtilities.getCallbackHandle(_headlessCallbackDispatcher)
          .toRawHandle(),
      PluginUtilities.getCallbackHandle(callback).toRawHandle()
    ];

    _methodChannel
        .invokeMethod('registerHeadlessTask', args)
        .then((dynamic success) {
      completer.complete(true);
    }).catchError((Error error) {
      String message = error.toString();
      print('[FirebaseMessaging registerHeadlessTask] ‼️ ${message}');
      completer.complete(false);
    });
    return completer.future;
  }
}

/// Headless Callback Dispatcher
///
void _headlessCallbackDispatcher() {
  WidgetsFlutterBinding.ensureInitialized();
  const MethodChannel _headlessChannel =
  MethodChannel("$_PLUGIN_PATH/headless", JSONMethodCodec());

  _headlessChannel.setMethodCallHandler((MethodCall call) async {
    final dynamic args = call.arguments;

    // Run the headless-task.
    try {
      final Function callback = PluginUtilities.getCallbackFromHandle(
          CallbackHandle.fromRawHandle(args['callbackId']));
      if (callback == null) {
        print(
            '[FirebaseMessaging _headlessCallbackDispatcher] ERROR: Failed to get callback from handle: $args');
        return;
      }
      callback();
    } catch (e, stacktrace) {
      print('[FirebaseMessaging _headlessCallbackDispather] ‼️ Callback error: ' +
          e.toString());
      print(stacktrace);
    }
  });
  // Signal to native side that the client dispatcher is ready to receive events.
  _headlessChannel.invokeMethod('initialized');
}
