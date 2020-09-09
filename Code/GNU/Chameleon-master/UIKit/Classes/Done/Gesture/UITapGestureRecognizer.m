#import "UITapGestureRecognizer.h"
#import "UIGestureRecognizerSubclass.h"
#import "UITouch.h"

@implementation UITapGestureRecognizer

- (id)initWithTarget:(id)target action:(SEL)action
{
    if ((self=[super initWithTarget:target action:action])) {
        _numberOfTapsRequired = 1;
        _numberOfTouchesRequired = 1;
    }
    return self;
}

- (BOOL)canBePreventedByGestureRecognizer:(UIGestureRecognizer *)preventingGestureRecognizer
{
    // this logic is here based on a note in the docs for -canBePreventedByGestureRecognizer:
    // it may not be correct :)
    if ([preventingGestureRecognizer isKindOfClass:[UITapGestureRecognizer class]]) {
        return (((UITapGestureRecognizer *)preventingGestureRecognizer).numberOfTapsRequired > self.numberOfTapsRequired);
    } else {
        return [super canBePreventedByGestureRecognizer:preventingGestureRecognizer];
    }
}

- (BOOL)canPreventGestureRecognizer:(UIGestureRecognizer *)preventedGestureRecognizer
{
    // this logic is here based on a note in the docs for -canPreventGestureRecognizer:
    // it may not be correct :)
    if ([preventedGestureRecognizer isKindOfClass:[UITapGestureRecognizer class]]) {
        return (((UITapGestureRecognizer *)preventedGestureRecognizer).numberOfTapsRequired <= self.numberOfTapsRequired);
    } else {
        return [super canPreventGestureRecognizer:preventedGestureRecognizer];
    }
}

// 通过 touch 的过程, 不断地更改自己的 state

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    if (touch.tapCount >= self.numberOfTapsRequired) {
        if (self.state == UIGestureRecognizerStatePossible) {
            self.state = UIGestureRecognizerStateBegan;
        } else if (self.state == UIGestureRecognizerStateBegan) {
            self.state = UIGestureRecognizerStateChanged;
        }
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (self.state == UIGestureRecognizerStateBegan || self.state == UIGestureRecognizerStateChanged) {
        self.state = UIGestureRecognizerStateCancelled;
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (self.state == UIGestureRecognizerStateBegan || self.state == UIGestureRecognizerStateChanged) {
        self.state = UIGestureRecognizerStateEnded;
    }
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (self.state == UIGestureRecognizerStateBegan || self.state == UIGestureRecognizerStateChanged) {
        self.state = UIGestureRecognizerStateCancelled;
    }
}

@end
