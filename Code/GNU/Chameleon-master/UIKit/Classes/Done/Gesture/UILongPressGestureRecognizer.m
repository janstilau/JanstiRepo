#import "UILongPressGestureRecognizer.h"
#import "UIGestureRecognizerSubclass.h"
#import "UITouchEvent.h"
#import "UITouch.h"
#import "UIApplicationAppKitIntegration.h"

static CGFloat DistanceBetweenTwoPoints(CGPoint A, CGPoint B)
{
    CGFloat a = B.x - A.x;
    CGFloat b = B.y - A.y;
    return sqrtf((a*a) + (b*b));
}

@implementation UILongPressGestureRecognizer {
    CGPoint _beginLocation;
    BOOL _waiting;
}

- (id)initWithTarget:(id)target action:(SEL)action
{
    if ((self=[super initWithTarget:target action:action])) {
        _allowableMovement = 10;
        _minimumPressDuration = 0.5;
        _numberOfTapsRequired = 0;
        _numberOfTouchesRequired = 1;
    }
    return self;
}

- (void)_beginGesture
{
    _waiting = NO;
    if (self.state == UIGestureRecognizerStatePossible) {
        self.state = UIGestureRecognizerStateBegan;
        UIApplicationSendStationaryTouches();
    }
}

- (void)_cancelWaiting
{
    if (_waiting) {
        _waiting = NO;
        [[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(_beginGesture) object:nil];
    }
}

/*
 TouchBegin 的时候 注册一个延后操作, 在其他的事件发生的时候, 取消这个延后操作.
 */

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    if ([event isKindOfClass:[UITouchEvent class]]) {
        UITouchEvent *touchEvent = (UITouchEvent *)event;
        
        if (touchEvent.touchEventGesture == UITouchEventGestureRightClick) {
            self.state = UIGestureRecognizerStateBegan;
        } else if (touchEvent.touchEventGesture == UITouchEventGestureNone) {
            if (!_waiting && self.state == UIGestureRecognizerStatePossible && touchEvent.touch.tapCount >= self.numberOfTapsRequired) {
                _beginLocation = [touchEvent.touch locationInView:self.view];
                _waiting = YES;
                [self performSelector:@selector(_beginGesture) withObject:nil afterDelay:self.minimumPressDuration];
            }
        } else {
            self.state = UIGestureRecognizerStateFailed;
        }
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    const CGFloat distance = DistanceBetweenTwoPoints([touch locationInView:self.view], _beginLocation);
    
    /*
     在识别出长按之后, UIGestureRecognizerStateBegan, 如果移动了手指, 就会被认为是 cancel 了.
     */
    if (self.state == UIGestureRecognizerStateBegan || self.state == UIGestureRecognizerStateChanged) {
        if (distance <= self.allowableMovement) {
            self.state = UIGestureRecognizerStateChanged;
        } else {
            self.state = UIGestureRecognizerStateCancelled;
        }
    } else if (self.state == UIGestureRecognizerStatePossible && distance > self.allowableMovement) {
        self.state = UIGestureRecognizerStateFailed;
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (self.state == UIGestureRecognizerStateBegan || self.state == UIGestureRecognizerStateChanged) {
        self.state = UIGestureRecognizerStateEnded;
    } else {
        [self _cancelWaiting];
    }
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (self.state == UIGestureRecognizerStateBegan || self.state == UIGestureRecognizerStateChanged) {
        self.state = UIGestureRecognizerStateCancelled;
    } else {
        [self _cancelWaiting];
    }
}

- (void)reset
{
    [self _cancelWaiting];
    [super reset];
}

@end
