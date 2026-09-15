#import "GNECrashCapture.h"

#import "gne_signal.h"

#import <TargetConditionals.h>
#import <unistd.h>

static NSUncaughtExceptionHandler *GNEPreviousExceptionHandler = NULL;
static BOOL GNEExceptionHandlerInstalled = NO;

static NSString *GNECrashDirectory(void) {
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
  return dir;
}

static NSString *GNECrashFilePath(void) {
  return [GNECrashDirectory() stringByAppendingPathComponent:@"pending.json"];
}

static NSString *GNESessionMarkerPath(void) {
  return [GNECrashDirectory() stringByAppendingPathComponent:@"session.marker"];
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
  // JSON Lines: append one line per record so several crashes from the same
  // session are all preserved, matching the native signal writer.
  NSMutableData *line = [NSMutableData dataWithData:data];
  [line appendBytes:"\n" length:1];
  NSString *path = GNECrashFilePath();
  NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:path];
  if (handle == nil) {
    [line writeToFile:path atomically:YES];
    return;
  }
  @try {
    [handle seekToEndOfFile];
    [handle writeData:line];
  } @catch (__unused NSException *ignored) {
  } @finally {
    [handle closeFile];
  }
}

// Reads the crash file as JSON Lines, oldest first, ignoring blank lines.
static NSMutableArray<NSString *> *GNEReadLines(void) {
  NSMutableArray<NSString *> *lines = [NSMutableArray array];
  NSString *path = GNECrashFilePath();
  if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
    return lines;
  }
  NSString *contents =
      [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
  if (contents.length == 0) {
    return lines;
  }
  for (NSString *raw in [contents componentsSeparatedByString:@"\n"]) {
    NSString *trimmed = [raw stringByTrimmingCharactersInSet:
                                 [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length > 0) {
      [lines addObject:trimmed];
    }
  }
  return lines;
}

static void GNEWriteLines(NSArray<NSString *> *lines) {
  NSString *path = GNECrashFilePath();
  if (lines.count == 0) {
    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    return;
  }
  NSString *joined = [[lines componentsJoinedByString:@"\n"] stringByAppendingString:@"\n"];
  [joined writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

static void GNEUncaughtExceptionHandler(NSException *exception) {
  GNEWriteNSException(exception);
  if (GNEPreviousExceptionHandler != NULL) {
    GNEPreviousExceptionHandler(exception);
  }
}

static void GNEWriteAbnormalTermination(void) {
  NSMutableDictionary *payload = [NSMutableDictionary dictionary];
  payload[@"kind"] = @"abnormalTermination";
  payload[@"diagnosis"] =
      @"The previous session ended without running any handler, for example a "
      @"system OOM or a forced termination.";
  payload[@"platform"] = @"ios";
#if TARGET_OS_SIMULATOR
  payload[@"arch"] = @"simulator";
#elif defined(__aarch64__)
  payload[@"arch"] = @"arm64";
#else
  payload[@"arch"] = @"unknown";
#endif
  payload[@"timestampMs"] = @((long long)([[NSDate date] timeIntervalSince1970] * 1000.0));
  NSData *data = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
  if (data == nil) {
    return;
  }
  NSMutableData *line = [NSMutableData dataWithData:data];
  [line appendBytes:"\n" length:1];
  NSString *path = GNECrashFilePath();
  NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:path];
  if (handle == nil) {
    [line writeToFile:path atomically:YES];
    return;
  }
  @try {
    [handle seekToEndOfFile];
    [handle writeData:line];
  } @catch (__unused NSException *ignored) {
  } @finally {
    [handle closeFile];
  }
}

// Heuristic for deaths that run no handler (system OOM, forced termination).
// A leftover marker with no crash on disk means the previous session died
// silently. When a crash is present, that death is already explained.
static void GNEDetectAbnormalTermination(void) {
  NSFileManager *manager = [NSFileManager defaultManager];
  NSString *marker = GNESessionMarkerPath();
  NSString *crashPath = GNECrashFilePath();
  NSDictionary *attrs = [manager attributesOfItemAtPath:crashPath error:nil];
  BOOL hadCrash = (attrs != nil && [attrs fileSize] > 0);
  if ([manager fileExistsAtPath:marker] && !hadCrash) {
    GNEWriteAbnormalTermination();
  }
  NSString *stamp =
      @((long long)([[NSDate date] timeIntervalSince1970] * 1000.0)).stringValue;
  [stamp writeToFile:marker atomically:YES encoding:NSUTF8StringEncoding error:nil];
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

  static BOOL abnormalChecked = NO;
  if (!abnormalChecked) {
    abnormalChecked = YES;
    GNEDetectAbnormalTermination();
  }
}

+ (void)markHealthyExit {
  [[NSFileManager defaultManager] removeItemAtPath:GNESessionMarkerPath() error:nil];
}

+ (NSString *)peekPending {
  NSArray<NSString *> *lines = GNEReadLines();
  return lines.count > 0 ? lines.firstObject : nil;
}

+ (NSString *)takePending {
  NSMutableArray<NSString *> *lines = GNEReadLines();
  if (lines.count == 0) {
    return nil;
  }
  NSString *oldest = lines.firstObject;
  [lines removeObjectAtIndex:0];
  GNEWriteLines(lines);
  return oldest;
}

+ (NSArray<NSString *> *)peekPendingList {
  return GNEReadLines();
}

+ (NSArray<NSString *> *)takePendingList {
  NSArray<NSString *> *lines = GNEReadLines();
  [[NSFileManager defaultManager] removeItemAtPath:GNECrashFilePath() error:nil];
  return lines;
}

+ (void)deletePendingAtIndex:(NSInteger)index {
  NSMutableArray<NSString *> *lines = GNEReadLines();
  if (index < 0 || index >= (NSInteger)lines.count) {
    return;
  }
  [lines removeObjectAtIndex:(NSUInteger)index];
  GNEWriteLines(lines);
}

+ (void)crashNative {
  gne_crash_native();
}

+ (void)crashUncaughtException {
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    [NSException raise:NSInternalInconsistencyException
                format:@"Native crash reporter test"];
  });
}

@end
