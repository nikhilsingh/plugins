// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "FirebaseMessagingPlugin.h"
#import "Firebase/Firebase.h"

static NSString *const PLUGIN_PATH = @"plugins.flutter.io/firebase_messaging";
static NSString *const METHOD_CHANNEL_NAME              = @"methods";
static NSString *const EVENT_CHANNEL_NAME               = @"events";

static NSString *const ACTION_CONFIGURE                 = @"configure";
static NSString *const ACTION_START                     = @"start";
static NSString *const ACTION_STOP                      = @"stop";
static NSString *const ACTION_FINISH                    = @"finish";
static NSString *const ACTION_STATUS                    = @"status";
static NSString *const ACTION_SUBSCRIBE                 = @"subscribe";
static NSString *const ACTION_UNSUBSCRIBE               = @"unsubscribe";
static NSString *const ACTION_REGISTER_HEADLESS_TASK    = @"registerHeadlessTask";

#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
@interface FLTFirebaseMessagingPlugin ()<FIRMessagingDelegate,FlutterStreamHandler>
@end
#endif

@implementation FLTFirebaseMessagingPlugin {
    FlutterEventSink eventSink;
    NSMutableArray *cachedMessages;
}

static FLTFirebaseMessagingPlugin *instance = nil;
static BOOL initialized = NO;

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    NSString *methodPath = [NSString stringWithFormat:@"%@/%@", PLUGIN_PATH, METHOD_CHANNEL_NAME];
    FlutterMethodChannel* channel = [FlutterMethodChannel methodChannelWithName:methodPath binaryMessenger:[registrar messenger]];
    
    FLTFirebaseMessagingPlugin* instance = [[FLTFirebaseMessagingPlugin alloc] init];
    [registrar addApplicationDelegate:instance];
    [registrar addMethodCallDelegate:instance channel:channel];
    
    NSString *eventPath = [NSString stringWithFormat:@"%@/%@", PLUGIN_PATH, EVENT_CHANNEL_NAME];
    
    FlutterEventChannel* eventChannel = [FlutterEventChannel eventChannelWithName:eventPath binaryMessenger:[registrar messenger]];
    [eventChannel setStreamHandler:instance];
}

-(instancetype) init {
    self = [super init];
    if (![FIRApp defaultApp]) {
        [FIRApp configure];
    }
    [FIRMessaging messaging].delegate = self;
    return self;
}

//- (instancetype)init:(NSObject<FlutterPluginRegistrar> *)registrar {
//    self = [super init];
//    NSAssert(self, @"super init cannot be nil");
//    _persistentState = [NSUserDefaults standardUserDefaults];
//    _eventQueue = [[NSMutableArray alloc] init];
//
//    _headlessRunner = [[FlutterHeadlessDartRunner alloc] init];
//    _registrar = registrar;
//
//    _mainChannel = [FlutterMethodChannel methodChannelWithName:@"plugins.flutter.io/firebase_messaging"
//                                               binaryMessenger:[registrar messenger]];
//    [registrar addMethodCallDelegate:self channel:_mainChannel];
//
//    _callbackChannel =
//    [FlutterMethodChannel methodChannelWithName:@"plugins.flutter.io/firebase_messaging_background"
//                                binaryMessenger:_headlessRunner];
//    _resumingFromBackground = NO;
//    if (![FIRApp defaultApp]) {
//        [FIRApp configure];
//    }
//    [FIRMessaging messaging].delegate = self;
//
//    return self;
//}



- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    if ([self method:call.method is:ACTION_CONFIGURE]) {
        [self configure:call.arguments result:result];
    } else if ([self method:call.method is:ACTION_FINISH]) {
        [self finish:[call.arguments integerValue] result:result];
    }else if ([self method:call.method is:ACTION_SUBSCRIBE]) {
        NSArray *arguments = call.arguments;
        NSString *topic = arguments[0];
        [[FIRMessaging messaging] subscribeToTopic:topic];
        result(nil);
    }
    else if ([self method:call.method is:ACTION_UNSUBSCRIBE]) {
        NSArray *arguments = call.arguments;
        NSString *topic = arguments[0];
        [[FIRMessaging messaging] unsubscribeFromTopic:topic];
        result(nil);
    }
    else if ([self method:call.method is:ACTION_REGISTER_HEADLESS_TASK]) {
        result(@(YES));
    } else {
        result(FlutterMethodNotImplemented);
    }
}

-(void) finish:(NSInteger)fetchResult result:(FlutterResult)flutterResult {
    UIBackgroundFetchResult result = UIBackgroundFetchResultNewData;
    if (fetchResult == UIBackgroundFetchResultNewData
        || fetchResult == UIBackgroundFetchResultNoData
        || fetchResult == UIBackgroundFetchResultFailed) {
        result = fetchResult;
    }
    //    TSBackgroundFetch *fetchManager = [TSBackgroundFetch sharedInstance];
    //    [fetchManager finish:PLUGIN_PATH result:result];
    flutterResult(@(YES));
}

-(void) configure:(NSDictionary*)params result:(FlutterResult)result {
    //TSBackgroundFetch *fetchManager = [TSBackgroundFetch sharedInstance];
    
    //        if (status != UIBackgroundRefreshStatusAvailable) {
    //            NSLog(@"- %@ failed to start, status: %lu", PLUGIN_PATH, status);
    //            result([FlutterError errorWithCode: [NSString stringWithFormat:@"%lu", (long) status] message:nil details:@(status)]);
    //            return;
    //        }
    //        void (^handler)(void);
    //        handler = ^void(void){
    //            if (self->eventSink != nil) {
    //                self->eventSink(@(YES));
    //            }
    //        };
    //        [fetchManager addListener:PLUGIN_PATH callback:handler];
    //        [fetchManager start];
    
    UIUserNotificationType notificationTypes = 0;
    if ([params[@"sound"] boolValue]) {
        notificationTypes |= UIUserNotificationTypeSound;
    }
    if ([params[@"alert"] boolValue]) {
        notificationTypes |= UIUserNotificationTypeAlert;
    }
    if ([params[@"badge"] boolValue]) {
        notificationTypes |= UIUserNotificationTypeBadge;
    }
    UIUserNotificationSettings *settings =
    [UIUserNotificationSettings settingsForTypes:notificationTypes categories:nil];
    [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
    
    [[UIApplication sharedApplication] registerForRemoteNotifications];

    result(@(2));
}

- (BOOL) method:(NSString*)method is:(NSString*)action {
    return [method isEqualToString:action];
}

#pragma mark FlutterStreamHandler impl

- (FlutterError*)onListenWithArguments:(id)arguments eventSink:(FlutterEventSink)sink {
    eventSink = sink;
    if (cachedMessages != nil)
    {
        for (id obj in cachedMessages) {
            eventSink(obj);
        }
        cachedMessages = nil;
    }
    return nil;
}

- (FlutterError*)onCancelWithArguments:(id)arguments {
    eventSink = nil;
    return nil;
}

#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
// Receive data message on iOS 10 devices while app is in the foreground.
- (void)applicationReceivedRemoteMessage:(FIRMessagingRemoteMessage *)remoteMessage {
    [self didReceiveRemoteNotification:remoteMessage.appData];
}
#endif

- (void)didReceiveRemoteNotification:(NSDictionary *)userInfo {
    if (eventSink != nil)
    {
        eventSink(userInfo);
    }
    else
    {
        if (cachedMessages == nil)
        {
            cachedMessages = [[NSMutableArray alloc] initWithObjects:userInfo, nil];
        }
        else
        {
            [cachedMessages addObject:userInfo];
        }
    }
}

#pragma mark - AppDelegate

- (BOOL)application:(UIApplication *)application
didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    //    if (launchOptions != nil) {
    //        _launchNotification = launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey];
    //    }
    return YES;
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
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

- (BOOL)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    if (eventSink != nil)
    {
        eventSink(userInfo);
    }
    else
    {
        if (cachedMessages == nil)
        {
            cachedMessages = [[NSMutableArray alloc] initWithObjects:userInfo, nil];
        }
        else
        {
            [cachedMessages addObject:userInfo];
        }
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

