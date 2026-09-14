#import "GNECrashCapture.h"

#import "gne_signal.h"

#import <TargetConditionals.h>
#import <unistd.h>

static NSUncaughtExceptionHandler *GNEPreviousExceptionHandler = NULL;
static BOOL GNEExceptionHandlerInstalled = NO;

static NSString *GNECrashFilePath(void) {
  NSArray<NSString *> *paths = NSSearchPathForDirectoriesInDomains(
      NSApplicationSupportDirectory, NSUserDomainMask, YES);
  NSString *root = paths.firstObject;
  if (root.length == 0) {
    root = NSTemporaryDirectory();
  }
  NSString *dir = [root stringByAppendingPathComponent:@"native_crashes"];
  [[NSFileManager defaultManager] createDirectoryAtPath:dir
                            withIntermediateDirectories:YES
                                             attributes:nil
                                                  error:nil];
  return [dir stringByAppendingPathComponent:@"pending.json"];
}

static void GNEWriteNSException(NSException *exception) {
  NSMutableDictionary *payload = [NSMutableDictionary dictionary];
  payload[@"kind"] = @"nsException";
  payload[@"exceptionType"] = exception.name ?: @"NSException";
  payload[@"exceptionMessage"] = exception.reason ?: @"";
  payload[@"stackTrace"] = [exception.callStackSymbols componentsJoinedByString:@"\n"];
  payload[@"platform"] = @"ios";
#if TARGET_OS_SIMULATOR
  payload[@"arch"] = @"simulator";
#elif defined(__aarch64__)
  payload[@"arch"] = @"arm64";
#else
  payload[@"arch"] = @"unknown";
#endif
  payload[@"timestampMs"] = @((long long)([[NSDate date] timeIntervalSince1970] * 1000.0));
  payload[@"pid"] = @(getpid());

  NSData *data = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
  if (data == nil) {
    return;
  }
  [data writeToFile:GNECrashFilePath() atomically:YES];
}

static void GNEUncaughtExceptionHandler(NSException *exception) {
  GNEWriteNSException(exception);
  if (GNEPreviousExceptionHandler != NULL) {
    GNEPreviousExceptionHandler(exception);
  }
}

@implementation GNECrashCapture

+ (void)install {
  NSString *path = GNECrashFilePath();
  gne_install(path.fileSystemRepresentation, "ios");

  if (!GNEExceptionHandlerInstalled) {
    GNEPreviousExceptionHandler = NSGetUncaughtExceptionHandler();
    NSSetUncaughtExceptionHandler(&GNEUncaughtExceptionHandler);
    GNEExceptionHandlerInstalled = YES;
  }
}

+ (NSString *)peekPending {
  NSString *path = GNECrashFilePath();
  if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
    return nil;
  }
  return [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
}

+ (NSString *)takePending {
  NSString *path = GNECrashFilePath();
  NSString *contents = [self peekPending];
  if (contents != nil) {
    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
  }
  return contents.length > 0 ? contents : nil;
}

+ (void)crashNative {
  gne_crash_native();
}

@end
