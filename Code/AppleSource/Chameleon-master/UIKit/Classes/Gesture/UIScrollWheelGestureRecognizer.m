#import "UIScrollWheelGestureRecognizer.h"
#import "UIGestureRecognizerSubclass.h"
#import "UITouchEvent.h"
#import "UITouch.h"

@implementation UIScrollWheelGestureRecognizer {
    CGPoint _translation;
}

- (CGPoint)translationInView:(UIView *)view
{
    return _translation;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (self.state == UIGestureRecognizerStatePossible) {
        if ([event isKindOfClass:[UITouchEvent class]]) {
            UITouchEvent *touchEvent = (UITouchEvent *)event;
            
            if (touchEvent.touchEventGesture == UITouchEventGestureScrollWheel) {
                _translation = touchEvent.translation;
                self.state = UIGestureRecognizerStateRecognized;
            } else {
                self.state = UIGestureRecognizerStateFailed;
            }
        }
    }
}

@end
