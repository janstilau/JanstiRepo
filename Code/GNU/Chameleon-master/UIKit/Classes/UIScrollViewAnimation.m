#import "UIScrollViewAnimation.h"

CGFloat UILinearInterpolation(CGFloat t, CGFloat start, CGFloat end)
{
    if (t <= 0) {
        return start;
    } else if (t >= 1) {
        return end;
    } else {
        return t * end + (1 - t) * start;
    }
}

CGFloat UIQuadraticEaseOut(CGFloat t, CGFloat start, CGFloat end)
{
    if (t <= 0) {
        return start;
    } else if (t >= 1) {
        return end;
    } else {
        return UILinearInterpolation(2 * t - t * t, start, end);
    }
}

@implementation UIScrollViewAnimation

- (id)initWithScrollView:(UIScrollView *)sv
{
    if ((self=[super init])) {
        _scrollView = sv;
        _beginTime = [NSDate timeIntervalSinceReferenceDate];
    }
    return self;
}

- (BOOL)animate
{
    return YES;
}

- (void)momentumScrollBy:(CGPoint)delta
{
    // does nothing
}

@end
