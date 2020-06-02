#import "UISwipeGestureRecognizer.h"
#import "UIGestureRecognizerSubclass.h"
#import "UITouchEvent.h"

@implementation UISwipeGestureRecognizer

- (id)initWithTarget:(id)target action:(SEL)action
{
    if ((self=[super initWithTarget:target action:action])) {
        _direction = UISwipeGestureRecognizerDirectionRight;
        _numberOfTouchesRequired = 1;
    }
    return self;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (self.state == UIGestureRecognizerStatePossible) {
        if ([event isKindOfClass:[UITouchEvent class]]) {
            UITouchEvent *touchEvent = (UITouchEvent *)event;
            if (touchEvent.touchEventGesture == UITouchEventGestureSwipe) {
                if (_direction == UISwipeGestureRecognizerDirectionLeft && touchEvent.translation.x > 0) {
                    self.state = UIGestureRecognizerStateRecognized;
                } else if (_direction == UISwipeGestureRecognizerDirectionRight && touchEvent.translation.x < 0) {
                    self.state = UIGestureRecognizerStateRecognized;
                } else if (_direction == UISwipeGestureRecognizerDirectionUp && touchEvent.translation.y > 0) {
                    self.state = UIGestureRecognizerStateRecognized;
                } else if (_direction == UISwipeGestureRecognizerDirectionDown && touchEvent.translation.y < 0) {
                    self.state = UIGestureRecognizerStateRecognized;
                } else {
                    self.state = UIGestureRecognizerStateFailed;
                }
            } else {
                self.state = UIGestureRecognizerStateFailed;
            }
        }
    }
}

@end
