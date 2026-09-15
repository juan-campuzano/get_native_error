#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface GNECrashCapture : NSObject

+ (void)install;
+ (nullable NSString *)peekPending;
+ (nullable NSString *)takePending;
+ (NSArray<NSString *> *)peekPendingList;
+ (NSArray<NSString *> *)takePendingList;
+ (void)deletePendingAtIndex:(NSInteger)index;
+ (void)markHealthyExit;
+ (void)crashNative;

@end

NS_ASSUME_NONNULL_END
