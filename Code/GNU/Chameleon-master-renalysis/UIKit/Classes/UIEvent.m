#import "UIEvent.h"
#import "UITouch.h"


/*
 Touch events are the most common and are delivered to the view in which the touch originally occurred.
 */
@implementation UIEvent

- (id)init
{
    if ((self=[super init])) {
        _timestamp = [NSDate timeIntervalSinceReferenceDate];
    }
    return self;
}

- (NSSet *)allTouches
{
    return nil;
}

- (NSSet *)touchesForView:(UIView *)view
{
    NSMutableSet *touches = [NSMutableSet setWithCapacity:1];
    for (UITouch *touch in [self allTouches]) {
        if (touch.view == view) {
            [touches addObject:touch];
        }
    }
    return touches;
}

- (NSSet *)touchesForWindow:(UIWindow *)window
{
    NSMutableSet *touches = [NSMutableSet setWithCapacity:1];
    for (UITouch *touch in [self allTouches]) {
        if (touch.window == window) {
            [touches addObject:touch];
        }
    }
    return touches;
}

- (NSSet *)touchesForGestureRecognizer:(UIGestureRecognizer *)gesture
{
    NSMutableSet *touches = [NSMutableSet setWithCapacity:1];
    for (UITouch *touch in [self allTouches]) {
        if ([touch.gestureRecognizers containsObject:gesture]) {
            [touches addObject:touch];
        }
    }
    return touches;
}

- (UIEventType)type
{
    return -1;
}

- (UIEventSubtype)subtype
{
    return UIEventSubtypeNone;
}

@end
