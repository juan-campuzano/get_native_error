#import "GetNativeErrorPlugin.h"
#import "GNECrashCapture.h"

@implementation GetNativeErrorPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  [GNECrashCapture install];
  FlutterMethodChannel *channel =
      [FlutterMethodChannel methodChannelWithName:@"get_native_error"
                                  binaryMessenger:[registrar messenger]];
  GetNativeErrorPlugin *instance = [[GetNativeErrorPlugin alloc] init];
  [registrar addMethodCallDelegate:instance channel:channel];
}

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
  if ([call.method isEqualToString:@"install"]) {
    [GNECrashCapture install];
    result(nil);
  } else if ([call.method isEqualToString:@"peekPendingCrash"]) {
    result([GNECrashCapture peekPending]);
  } else if ([call.method isEqualToString:@"takePendingCrash"]) {
    result([GNECrashCapture takePending]);
  } else if ([call.method isEqualToString:@"peekPendingCrashes"]) {
    result([GNECrashCapture peekPendingList]);
  } else if ([call.method isEqualToString:@"takePendingCrashes"]) {
    result([GNECrashCapture takePendingList]);
  } else if ([call.method isEqualToString:@"deletePendingCrash"]) {
    NSInteger index = [call.arguments isKindOfClass:[NSNumber class]]
                          ? [(NSNumber *)call.arguments integerValue]
                          : -1;
    [GNECrashCapture deletePendingAtIndex:index];
    result(nil);
  } else if ([call.method isEqualToString:@"markHealthyExit"]) {
    [GNECrashCapture markHealthyExit];
    result(nil);
  } else if ([call.method isEqualToString:@"crashNative"]) {
    [GNECrashCapture crashNative];
    result(nil);
  } else {
    result(FlutterMethodNotImplemented);
  }
}

@end
