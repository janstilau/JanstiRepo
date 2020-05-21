#import "UIApplication.h"

@interface UIBackgroundTask : NSObject

- (id)initWithExpirationHandler:(void(^)(void))handler;

@property (copy, nonatomic, readonly) void (^expirationHandler)(void);
@property (nonatomic, readonly) UIBackgroundTaskIdentifier taskIdentifier;

@end
