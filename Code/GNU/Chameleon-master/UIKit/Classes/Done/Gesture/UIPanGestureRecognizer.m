#import "UIPanGestureRecognizer.h"
#import "UIGestureRecognizerSubclass.h"
#import "UITouchEvent.h"
#import "UITouch.h"

@implementation UIPanGestureRecognizer {
    CGPoint _translation;
    CGPoint _velocity;
    NSTimeInterval _lastMovementTime;
}

- (id)initWithTarget:(id)target action:(SEL)action
{
    if ((self=[super initWithTarget:target action:action])) {
        _minimumNumberOfTouches = 1;
        _maximumNumberOfTouches = NSUIntegerMax;
        _translation = CGPointZero;
        _velocity = CGPointZero;
    }
    return self;
}

- (CGPoint)translationInView:(UIView *)view
{
    return _translation;
}

- (void)setTranslation:(CGPoint)translation inView:(UIView *)view
{
    _velocity = CGPointZero;
    _translation = translation;
}

/*
 这就是, 为什么要把 _translation 设置为 0 的原因.
 程序里面, 一般是根据 gesture 的偏移, 一点点的做效果.
 但是 gesture 里面记录的是, 从 gesture 一开始的偏移量.
 程序里面, 显式把这个值进行归零, 使得下一次得到这个值, 是很小的一个值, 这样才能保持程序的正确性.
 */
- (BOOL)_translate:(CGPoint)delta withEvent:(UIEvent *)event
{
    const NSTimeInterval timeDiff = event.timestamp - _lastMovementTime;

    if (!CGPointEqualToPoint(delta, CGPointZero) && timeDiff > 0) {
        _translation.x += delta.x;
        _translation.y += delta.y;
        _velocity.x = delta.x / timeDiff;
        _velocity.y = delta.y / timeDiff;
        _lastMovementTime = event.timestamp;
        return YES;
    } else {
        return NO;
    }
}

- (void)reset
{
    [super reset];
    _translation = CGPointZero;
    _velocity = CGPointZero;
}

- (CGPoint)velocityInView:(UIView *)view
{
    return _velocity;
}


/*
 Gesture 的内部逻辑, 也是通过几个 touch 函数, 进行状态的改变.
 */
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (self.state == UIGestureRecognizerStatePossible) {
        if ([event isKindOfClass:[UITouchEvent class]]) {
            UITouchEvent *touchEvent = (UITouchEvent *)event;
            if (touchEvent.touchEventGesture != UITouchEventGestureBegin) {
                self.state = UIGestureRecognizerStateFailed;
            }
        }
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    if ([event isKindOfClass:[UITouchEvent class]]) {
        UITouchEvent *touchEvent = (UITouchEvent *)event;
        if (touchEvent.touchEventGesture == UITouchEventGesturePan) {
            if (self.state == UIGestureRecognizerStatePossible) {
                //  记录上一次
                _lastMovementTime = touchEvent.timestamp;
                [self setTranslation:touchEvent.translation inView:touchEvent.touch.view];
                self.state = UIGestureRecognizerStateBegan;
            } else if ([self _translate:touchEvent.translation withEvent:event]) {
                self.state = UIGestureRecognizerStateChanged;
            }
        }
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (self.state == UIGestureRecognizerStateBegan || self.state == UIGestureRecognizerStateChanged) {
        if ([event isKindOfClass:[UITouchEvent class]]) {
            UITouchEvent *touchEvent = (UITouchEvent *)event;
            [self _translate:touchEvent.translation withEvent:touchEvent];
            self.state = UIGestureRecognizerStateEnded;
        } else {
            self.state = UIGestureRecognizerStateCancelled;
        }
    }
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (self.state == UIGestureRecognizerStateBegan || self.state == UIGestureRecognizerStateChanged) {
        self.state = UIGestureRecognizerStateCancelled;
    }
}

@end
