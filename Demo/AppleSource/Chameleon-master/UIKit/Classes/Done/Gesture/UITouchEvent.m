#import "UITouchEvent.h"
#import "UITouch.h"
#import "UIGestureRecognizer+UIPrivate.h"

@implementation UITouchEvent

- (id)initWithTouch:(UITouch *)touch
{
    if ((self=[super init])) {
        _touch = touch;
        _touchEventGesture = UITouchEventGestureNone;
    }
    return self;
}

- (NSTimeInterval)timestamp
{
    return _touch.timestamp;
}

- (NSSet *)allTouches
{
    return [NSSet setWithObject:_touch];
}

- (UIEventType)type
{
    return UIEventTypeTouches;
}

- (BOOL)isDiscreteGesture
{
    return (_touchEventGesture == UITouchEventGestureScrollWheel ||
            _touchEventGesture == UITouchEventGestureRightClick ||
            _touchEventGesture == UITouchEventGestureMouseMove ||
            _touchEventGesture == UITouchEventGestureMouseEntered ||
            _touchEventGesture == UITouchEventGestureMouseExited ||
            _touchEventGesture == UITouchEventGestureSwipe);
}

- (void)endTouchEvent
{
    for (UIGestureRecognizer *gesture in _touch.gestureRecognizers) {
        [gesture _endTrackingTouch:_touch withEvent:self];
    }
}

@end
