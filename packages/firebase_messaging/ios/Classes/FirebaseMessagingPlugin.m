// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "FirebaseMessagingPlugin.h"
#import "Firebase/Firebase.h"


#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
@interface FLTFirebaseMessagingPlugin ()<FIRMessagingDelegate>
@end
#endif

@implementation FLTFirebaseMessagingPlugin {
    FlutterHeadlessDartRunner *_headlessRunner;
    FlutterMethodChannel *_callbackChannel;
    FlutterMethodChannel *_mainChannel;
    NSMutableArray *_eventQueue;
    int64_t _onLocationUpdateHandle;
    NSUserDefaults *_persistentState;
    NSObject<FlutterPluginRegistrar> *_registrar;
    NSDictionary *_launchNotification;
    BOOL _resumingFromBackground;
}

static const NSString *kEventType = @"event_type";
static const NSString *kMessageKey = @"msg";
static const NSString *kMsgIdKey = @"msg_id";
static const NSString *kCallbackMapping = @"message_id_callback_mapping";
static const NSString *kCallbackId = @"callbackId";

static const int _kMessageEvent = 1;
static const int _kResumeEvent = 2;
static const int _kRemoteEvent = 3;
static const int _kLaunchEvent = 4;
static FLTFirebaseMessagingPlugin *instance = nil;
static BOOL initialized = NO;

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
    @synchronized(self) {
        if (instance == nil) {
            NSLog(@"Registering with registrar");
            instance = [[FLTFirebaseMessagingPlugin alloc] init:registrar];
            [registrar addApplicationDelegate:instance];
        }
    }
}

- (instancetype)init:(NSObject<FlutterPluginRegistrar> *)registrar {
    self = [super init];
    NSAssert(self, @"super init cannot be nil");
    _persistentState = [NSUserDefaults standardUserDefaults];
    _eventQueue = [[NSMutableArray alloc] init];
    
    _headlessRunner = [[FlutterHeadlessDartRunner alloc] init];
    _registrar = registrar;
    
    _mainChannel = [FlutterMethodChannel methodChannelWithName:@"plugins.flutter.io/firebase_messaging"
                                               binaryMessenger:[registrar messenger]];
    [registrar addMethodCallDelegate:self channel:_mainChannel];
    
    _callbackChannel =
    [FlutterMethodChannel methodChannelWithName:@"plugins.flutter.io/firebase_messaging_background"
                                binaryMessenger:_headlessRunner];
    _resumingFromBackground = NO;
    if (![FIRApp defaultApp]) {
        [FIRApp configure];
    }
    [FIRMessaging messaging].delegate = self;
    
    return self;
}

- (void)startMessagingService:(int64_t)handle {
    NSLog(@"Initializing MessagingService");
    [self setCallbackDispatcherHandle:handle];
    FlutterCallbackInformation *info = [FlutterCallbackCache lookupCallbackInformation:handle];
    NSAssert(info != nil, @"failed to find callback");
    NSString *entrypoint = info.callbackName;
    NSString *uri = info.callbackLibraryPath;
    [_headlessRunner runWithEntrypointAndLibraryUri:entrypoint libraryUri:uri];
    [_registrar addMethodCallDelegate:self channel:_callbackChannel];
}

- (int64_t)getCallbackDispatcherHandle {
    id handle = [_persistentState objectForKey:@"callback_dispatcher_handle"];
    if (handle == nil) {
        return 0;
    }
    return [handle longLongValue];
}

- (void)setCallbackDispatcherHandle:(int64_t)handle {
    [_persistentState setObject:[NSNumber numberWithLongLong:handle]
                         forKey:@"callback_dispatcher_handle"];
}

- (NSMutableDictionary *)getListenerCallbackMapping {
    const NSString *key = kCallbackMapping;
    NSMutableDictionary *callbackDict = [_persistentState dictionaryForKey:key];
    if (callbackDict == nil) {
        callbackDict = @{};
        [_persistentState setObject:callbackDict forKey:key];
    }
    return [callbackDict mutableCopy];
}

- (void)setListenerCallbackMapping:(NSMutableDictionary *)mapping {
    const NSString *key = kCallbackMapping;
    NSAssert(mapping != nil, @"mapping cannot be nil");
    [_persistentState setObject:mapping forKey:key];
}

- (int64_t)getCallbackHandleForMsgId:(NSString *)identifier {
    NSMutableDictionary *mapping = [self getListenerCallbackMapping];
    id handle = [mapping objectForKey:identifier];
    if (handle == nil) {
        return 0;
    }
    return [handle longLongValue];
}

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
    NSString *method = call.method;
    
    if ([@"FirebaseMessaging.initializeService" isEqualToString:call.method]) {
        NSArray *arguments = call.arguments;
        
        NSAssert(arguments.count == 3,
                 @"Invalid argument count for 'FirebaseMessaging.initializeService'");
        UIUserNotificationType notificationTypes = 0;
        NSDictionary *permissions = arguments[2];
        if ([permissions[@"sound"] boolValue]) {
            notificationTypes |= UIUserNotificationTypeSound;
        }
        if ([permissions[@"alert"] boolValue]) {
            notificationTypes |= UIUserNotificationTypeAlert;
        }
        if ([permissions[@"badge"] boolValue]) {
            notificationTypes |= UIUserNotificationTypeBadge;
        }
        UIUserNotificationSettings *settings =
        [UIUserNotificationSettings settingsForTypes:notificationTypes categories:nil];
        [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
        
        [self startMessagingService:[arguments[0] longValue]];
        int64_t callbackHandle = [arguments[1] longLongValue];
        
        [self setCallbackHandleForListenerId:callbackHandle listenerId:kCallbackId];
        [[UIApplication sharedApplication] registerForRemoteNotifications];
        result(@(YES));
    } else if ([@"FirebaseMessaging.deinitialize" isEqualToString:call.method]) {
        NSArray *arguments = call.arguments;
        result(@([self deinitialize:arguments]));
    }
    else if ([@"FirebaseMessaging.initialized" isEqualToString:call.method]) {
        //NSArray *arguments = call.arguments;
        @synchronized(self) {
            initialized = YES;
            // Send the geofence events that occurred while the background
            // isolate was initializing.
            if (_launchNotification != nil) {
                [self sendMessageEvent:_launchNotification eventType: _kLaunchEvent];
                _launchNotification = NULL;
            }
            while ([_eventQueue count] > 0) {
                NSLog(@"DUMPING QUEUE");
                NSDictionary* event = _eventQueue[0];
                [_eventQueue removeObjectAtIndex:0];
                NSString* msgId = [event objectForKey:kMsgIdKey];
                NSDictionary* msg = [event objectForKey:kMessageKey];
                int type = [[event objectForKey:kEventType] intValue];
                [self sendMessageEvent:msg eventType: type];
            }
            
        }
        result(nil);
    }
    else if ([@"FirebaseMessaging.subscribeToTopic" isEqualToString:method]) {
        NSArray *arguments = call.arguments;
        NSString *topic = arguments[0];
        [[FIRMessaging messaging] subscribeToTopic:topic];
        result(nil);
    } else if ([@"FirebaseMessaging.unsubscribeFromTopic" isEqualToString:method]) {
        NSArray *arguments = call.arguments;
        NSString *topic = arguments[0];
        [[FIRMessaging messaging] unsubscribeFromTopic:topic];
        result(nil);
    } else {
        result(FlutterMethodNotImplemented);
    }
}

- (BOOL)deinitialize:(NSArray *)arguments {
    NSLog(@"deinitialize: %@", arguments);
    [self removeCallbackHandleForListenerId:kCallbackId];
    return NO;
}


- (void)setCallbackHandleForListenerId:(int64_t)handle listenerId:(NSString *)identifier {
    NSMutableDictionary *mapping = [self getListenerCallbackMapping];
    [mapping setObject:[NSNumber numberWithLongLong:handle] forKey:identifier];
    [self setListenerCallbackMapping:mapping];
}

- (void)removeCallbackHandleForListenerId:(NSString *)identifier {
    NSMutableDictionary *mapping = [self getListenerCallbackMapping];
    [mapping removeObjectForKey:identifier];
    [self setListenerCallbackMapping:mapping];
}

- (void)sendMessageEvent:(NSDictionary *)userInfo eventType:(int)event{
    NSAssert([userInfo isKindOfClass:[NSDictionary class]], @"userInfo must be NSDictionary");
    int64_t handle = [self getCallbackHandleForMsgId:kCallbackId];
    NSMutableArray* message = [[NSMutableArray alloc] init];
    [message addObject:[NSNumber numberWithLongLong:handle]];
    [message addObject:[NSNumber numberWithInt:event]];
    [message addObject:userInfo];
    
    [_callbackChannel
     invokeMethod:@""
     arguments:message];
}

#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
// Receive data message on iOS 10 devices while app is in the foreground.
- (void)applicationReceivedRemoteMessage:(FIRMessagingRemoteMessage *)remoteMessage {
    [self didReceiveRemoteNotification:remoteMessage.appData];
}
#endif

- (void)didReceiveRemoteNotification:(NSDictionary *)userInfo {
    @synchronized(self) {
        NSLog(@"didReceiveRemoteNotification");
        if (initialized) {
            if (_resumingFromBackground) {
                [self sendMessageEvent:userInfo eventType:_kResumeEvent];
            } else {
                [self sendMessageEvent:userInfo eventType:_kMessageEvent];
            }
        } else {
            if (_resumingFromBackground) {
                NSDictionary *dict = @{
                                       kMsgIdKey : [[NSUUID UUID] UUIDString],
                                       kMessageKey: userInfo,
                                       kEventType: @(_kResumeEvent)
                                       };
                [_eventQueue addObject:dict];
            }
            else
            {
                NSDictionary *dict = @{
                                       kMsgIdKey: [[NSUUID UUID] UUIDString],
                                       kMessageKey: userInfo,
                                       kEventType: @(_kMessageEvent)
                                       };
                [_eventQueue addObject:dict];
            }
        }
    }
}

#pragma mark - AppDelegate

- (BOOL)application:(UIApplication *)application
didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    if (launchOptions != nil) {
        _launchNotification = launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey];
    }
    return YES;
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    _resumingFromBackground = YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    _resumingFromBackground = NO;
    // Clears push notifications from the notification center, with the
    // side effect of resetting the badge count. We need to clear notifications
    // because otherwise the user could tap notifications in the notification
    // center while the app is in the foreground, and we wouldn't be able to
    // distinguish that case from the case where a message came in and the
    // user dismissed the notification center without tapping anything.
    // TODO(goderbauer): Revisit this behavior once we provide an API for managing
    // the badge number, or if we add support for running Dart in the background.
    // Setting badgeNumber to 0 is a no-op (= notifications will not be cleared)
    // if it is already 0,
    // therefore the next line is setting it to 1 first before clearing it again
    // to remove all
    // notifications.
    application.applicationIconBadgeNumber = 1;
    application.applicationIconBadgeNumber = 0;
}

- (bool)application:(UIApplication *)application
didReceiveRemoteNotification:(NSDictionary *)userInfo
fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler {
//    [self selec]
//    [self performSelector:NSSelectorFromString(@"registerWithRegistry") withObject:self];
//    [GeneratedPluginRegistrant registerWithRegistry:self];
    if (initialized) {
      [self sendMessageEvent:userInfo eventType:_kRemoteEvent];
    } else {
            NSDictionary *dict = @{
                                   kMsgIdKey:[[NSUUID UUID] UUIDString],
                                   kMessageKey: userInfo,
                                   kEventType: @(_kRemoteEvent)
                                   };
            [_eventQueue addObject:dict];
    }
    
    completionHandler(UIBackgroundFetchResultNewData);
    return YES;
}

- (void)application:(UIApplication *)application
didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
#ifdef DEBUG
    [[FIRMessaging messaging] setAPNSToken:deviceToken type:FIRMessagingAPNSTokenTypeSandbox];
#else
    [[FIRMessaging messaging] setAPNSToken:deviceToken type:FIRMessagingAPNSTokenTypeProd];
#endif
    
   // [_channel invokeMethod:@"onToken" arguments:[[FIRInstanceID instanceID] token]];
}

- (void)application:(UIApplication *)application
didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings {
    NSDictionary *settingsDictionary = @{
                                         @"sound" : [NSNumber numberWithBool:notificationSettings.types & UIUserNotificationTypeSound],
                                         @"badge" : [NSNumber numberWithBool:notificationSettings.types & UIUserNotificationTypeBadge],
                                         @"alert" : [NSNumber numberWithBool:notificationSettings.types & UIUserNotificationTypeAlert],
                                         };
    //[_channel invokeMethod:@"onIosSettingsRegistered" arguments:settingsDictionary];
}

- (void)messaging:(nonnull FIRMessaging *)messaging
didReceiveRegistrationToken:(nonnull NSString *)fcmToken {
   // [_channel invokeMethod:@"onToken" arguments:fcmToken];
}

@end

