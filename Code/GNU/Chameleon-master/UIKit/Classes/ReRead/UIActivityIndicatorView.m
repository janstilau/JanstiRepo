#import "UIActivityIndicatorView.h"
#import "UIImage.h"
#import "UIGraphics.h"
#import "UIColor.h"
#import "UIFont.h"
#import "UIStringDrawing.h"
#import "UIBezierPath.h"
#import <QuartzCore/QuartzCore.h>

static CGSize UIActivityIndicatorViewStyleSize(UIActivityIndicatorViewStyle style)
{
    if (style == UIActivityIndicatorViewStyleWhiteLarge) {
        return CGSizeMake(37,37);
    } else {
        return CGSizeMake(20,20);
    }
}

// 根据 style 的不同, 生成不同的菊花照片.
static UIImage *UIActivityIndicatorViewFrameImage(UIActivityIndicatorViewStyle style, UIColor *toothColor, NSInteger frame, NSInteger numberOfFrames, CGFloat scale)
{
    const CGSize frameSize = UIActivityIndicatorViewStyleSize(style);
    const CGFloat radius = frameSize.width / 2.f;
    const CGFloat TWOPI = M_PI * 2.f;
    const CGFloat numberOfTeeth = 12;
    const CGFloat toothWidth = (style == UIActivityIndicatorViewStyleWhiteLarge)? 3.5 : 2;

    if (!toothColor) {
        toothColor = (style == UIActivityIndicatorViewStyleGray)? [UIColor grayColor] : [UIColor whiteColor];
    }
    
    UIGraphicsBeginImageContextWithOptions(frameSize, NO, scale);
    CGContextRef c = UIGraphicsGetCurrentContext();

    // first put the origin in the center of the frame. this makes things easier later
    CGContextTranslateCTM(c, radius, radius);

    // now rotate the entire thing depending which frame we're trying to generate
    CGContextRotateCTM(c, frame / (CGFloat)numberOfFrames * TWOPI);

    // draw all the teeth
    for (NSInteger toothNumber=0; toothNumber<numberOfTeeth; toothNumber++) {
        // set the correct color for the tooth, dividing by more than the number of teeth to prevent the last tooth from being too translucent
        const CGFloat alpha = 0.3 + ((toothNumber / numberOfTeeth) * 0.7);
        [[toothColor colorWithAlphaComponent:alpha] setFill];
        
        // position and draw the tooth
        CGContextRotateCTM(c, 1 / numberOfTeeth * TWOPI);
        [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(-toothWidth/2.f,-radius,toothWidth,ceilf(radius*.54f)) cornerRadius:toothWidth/2.f] fill];
    }
    
    // hooray!
    UIImage *frameImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return frameImage;
}

@implementation UIActivityIndicatorView {
    BOOL _animating;
    UIActivityIndicatorViewStyle _activityIndicatorViewStyle;
    BOOL _hidesWhenStopped;
}

- (id)initWithActivityIndicatorStyle:(UIActivityIndicatorViewStyle)style
{
    CGRect frame = CGRectZero;
    frame.size = UIActivityIndicatorViewStyleSize(style);
    // 固定大小.
    if ((self=[super initWithFrame:frame])) {
        _animating = NO;
        self.activityIndicatorViewStyle = style;
        self.hidesWhenStopped = YES;
        self.opaque = NO;
        self.contentMode = UIViewContentModeCenter;
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame
{
    if ((self = [self initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite])) {
        self.frame = frame;
    }
    return self;
}

// 根据自身的内容, 返回 size.
- (CGSize)sizeThatFits:(CGSize)aSize
{
    return UIActivityIndicatorViewStyleSize(self.activityIndicatorViewStyle);
}

- (void)setActivityIndicatorViewStyle:(UIActivityIndicatorViewStyle)style
{
    @synchronized (self) {
        if (_activityIndicatorViewStyle != style) {
            _activityIndicatorViewStyle = style;
            [self setNeedsDisplay];
            if (_animating) {
                [self startAnimating];	// this will reset the images in the animation if it was already animating
            }
        }
    }
}

- (UIActivityIndicatorViewStyle)activityIndicatorViewStyle
{
    @synchronized (self) {
        return _activityIndicatorViewStyle;
    }
}

- (void)setHidesWhenStopped:(BOOL)hides
{
    @synchronized (self) {
        _hidesWhenStopped = hides;

        if (_hidesWhenStopped) {
            self.hidden = !_animating;
        } else {
            self.hidden = NO;
        }
    }
}

- (BOOL)hidesWhenStopped
{
    @synchronized (self) {
        return _hidesWhenStopped;
    }
}

// 添加一个动画.
- (void)_startAnimation
{
    @synchronized (self) {
        const NSInteger numberOfFrames = 12;
        const CFTimeInterval animationDuration = 0.8;
        
        NSMutableArray *images = [[NSMutableArray alloc] initWithCapacity:numberOfFrames];
        
        for (NSInteger frameNumber=0; frameNumber<numberOfFrames; frameNumber++) {
            [images addObject:(__bridge id)UIActivityIndicatorViewFrameImage(_activityIndicatorViewStyle, self.color, frameNumber, numberOfFrames, self.contentScaleFactor).CGImage];
        }
        
        CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:@"contents"];
        animation.calculationMode = kCAAnimationDiscrete;
        animation.duration = animationDuration;
        animation.repeatCount = HUGE_VALF;
        animation.values = images;
        animation.removedOnCompletion = NO;
        animation.fillMode = kCAFillModeBoth;
        
        [self.layer addAnimation:animation forKey:@"contents"];
    }
}

- (void)_stopAnimation
{
    @synchronized (self) {
        [self.layer removeAnimationForKey:@"contents"];

        self.layer.contents = (id)UIActivityIndicatorViewFrameImage(self.activityIndicatorViewStyle, self.color, 0, 1, self.contentScaleFactor).CGImage;
        
        if (self.hidesWhenStopped) {
            self.hidden = YES;
        }
    }
}

- (void)startAnimating
{
    @synchronized (self) {
        _animating = YES;
        self.hidden = NO;
        // 在主线程做 UI 更新
        [self performSelectorOnMainThread:@selector(_startAnimation) withObject:nil waitUntilDone:NO];
    }
}

- (void)stopAnimating
{
    @synchronized (self) {
        _animating = NO;
        // 在主线程做 UI 更新
        [self performSelectorOnMainThread:@selector(_stopAnimation) withObject:nil waitUntilDone:NO];
    }
}

- (BOOL)isAnimating
{
    @synchronized (self) {
        return _animating;
    }
}

- (void)didMoveToWindow
{
    if (!self.isAnimating) {
        [self _stopAnimation];  // resets the contents to the first frame if needed
    }
}

@end