#import "UIBackgroundTask.h"

@implementation UIBackgroundTask

- (id)initWithExpirationHandler:(void(^)(void))handler
{
    if ((self = [super init])) {
        _expirationHandler = [handler copy];
        _taskIdentifier = [self hash];  // may not be the best idea in the world
    }

    return self;
}


@end
