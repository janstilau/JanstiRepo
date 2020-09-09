#import "UIScrollView+UIPrivate.h"

@interface UIScrollViewAnimation : NSObject
- (id)initWithScrollView:(UIScrollView *)sv;
- (BOOL)animate;
- (void)momentumScrollBy:(CGPoint)delta;

@property (nonatomic, readonly) UIScrollView *scrollView;
@property (nonatomic, assign) NSTimeInterval beginTime;
@end

extern CGFloat UILinearInterpolation(CGFloat t, CGFloat start, CGFloat end);
extern CGFloat UIQuadraticEaseOut(CGFloat t, CGFloat start, CGFloat end);
