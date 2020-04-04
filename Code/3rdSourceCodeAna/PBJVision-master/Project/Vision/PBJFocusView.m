#import "PBJFocusView.h"

@interface PBJFocusView ()
{
    UIImageView *_focusRingView;
}

@end

@implementation PBJFocusView

#pragma mark - init

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.contentMode = UIViewContentModeScaleToFill;
        _focusRingView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"capture_focus"]];
        [self addSubview:_focusRingView];
        self.frame = _focusRingView.frame;
        self.layer.borderColor = [[UIColor greenColor] CGColor];
        self.layer.borderWidth = 2;
    }
    return self;
}

- (void)dealloc
{
    [self.layer removeAllAnimations];
}

#pragma mark -

- (void)startAnimation
{
    [self.layer removeAllAnimations];
    
    self.transform = CGAffineTransformMakeScale(1.4f, 1.4f);
    self.alpha = 0;
    
    [UIView animateWithDuration:0.4f delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
        self.transform = CGAffineTransformIdentity;
        self.alpha = 1;
    } completion:^(BOOL finished) {
        // 在这个时候, 输出  [self.layer animationKeys] 会得到 transform, opacity. 所以, animateWithDuration 里面做的还是对于 Animation 的管理工作.
        [UIView animateWithDuration:0.4f delay:0 options:UIViewAnimationOptionCurveLinear | UIViewAnimationOptionAutoreverse | UIViewAnimationOptionRepeat animations:^{
            self.transform = CGAffineTransformMakeScale(1.1f, 1.1f);
            self.alpha = 1;
        } completion:nil];
    }];
}

- (void)stopAnimation
{
    [self.layer removeAllAnimations];
    [UIView animateWithDuration:0.2f delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.transform = CGAffineTransformMakeScale(0.001f, 0.001f);
        self.alpha = 0;
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
    }];
}

@end
