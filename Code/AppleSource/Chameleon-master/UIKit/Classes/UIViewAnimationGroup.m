#import "UIViewAnimationGroup.h"
#import <QuartzCore/QuartzCore.h>
#import "UIColor.h"
#import "UIApplication.h"

static NSMutableSet *runningAnimationGroupSet = nil;

// 根据 UIViewAnimationCurve 枚举值, 生成实际的 CAMediaTimingFunction 对象.
static inline CAMediaTimingFunction *CAMediaTimingFunctionFromUIViewAnimationCurve(UIViewAnimationCurve curve)
{
    switch (curve) {
        case UIViewAnimationCurveEaseInOut:	return [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        case UIViewAnimationCurveEaseIn:	return [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
        case UIViewAnimationCurveEaseOut:	return [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
        case UIViewAnimationCurveLinear:	return [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    }
    return nil;
}

BOOL UIViewAnimationOptionIsSet(UIViewAnimationOptions options, UIViewAnimationOptions option)
{
    return ((options & option) == option);
}

static inline UIViewAnimationOptions UIViewAnimationOptionCurve(UIViewAnimationOptions options)
{
    return (options & (UIViewAnimationOptionCurveEaseInOut
                       | UIViewAnimationOptionCurveEaseIn
                       | UIViewAnimationOptionCurveEaseOut
                       | UIViewAnimationOptionCurveLinear));
}

static inline UIViewAnimationOptions UIViewAnimationOptionTransition(UIViewAnimationOptions options)
{
    return (options & (UIViewAnimationOptionTransitionNone
                       | UIViewAnimationOptionTransitionFlipFromLeft
                       | UIViewAnimationOptionTransitionFlipFromRight
                       | UIViewAnimationOptionTransitionCurlUp
                       | UIViewAnimationOptionTransitionCurlDown
                       | UIViewAnimationOptionTransitionCrossDissolve
                       | UIViewAnimationOptionTransitionFlipFromTop
                       | UIViewAnimationOptionTransitionFlipFromBottom));
}

@implementation UIViewAnimationGroup {
    NSUInteger _waitingAnimationNum;
    BOOL _didStart;
    CFTimeInterval _animationBeginTime;
    UIView *_transitionView;
    BOOL _transitionShouldCache;
    NSMutableSet *_animatingViews;
}

+ (void)initialize
{
    if (self == [UIViewAnimationGroup class]) {
        runningAnimationGroupSet = [NSMutableSet setWithCapacity:1];
    }
}

- (id)initWithAnimationOptions:(UIViewAnimationOptions)options
{
    if ((self=[super init])) {
        _waitingAnimationNum = 1;
        _animationBeginTime = CACurrentMediaTime();
        _animatingViews = [NSMutableSet setWithCapacity:2];
        
        self.duration = 0.2;
        
        // 在这里, 根据 options, 去除对应的属性值来.
        self.repeatCount = UIViewAnimationOptionIsSet(options, UIViewAnimationOptionRepeat)? FLT_MAX : 0;
        self.allowUserInteraction = UIViewAnimationOptionIsSet(options, UIViewAnimationOptionAllowUserInteraction);
        self.repeatAutoreverses = UIViewAnimationOptionIsSet(options, UIViewAnimationOptionAutoreverse);
        self.beginsFromCurrentState = UIViewAnimationOptionIsSet(options, UIViewAnimationOptionBeginFromCurrentState);

        const UIViewAnimationOptions animationCurve = UIViewAnimationOptionCurve(options);
        if (animationCurve == UIViewAnimationOptionCurveEaseIn) {
            self.curve = UIViewAnimationCurveEaseIn;
        } else if (animationCurve == UIViewAnimationOptionCurveEaseOut) {
            self.curve = UIViewAnimationCurveEaseOut;
        } else if (animationCurve == UIViewAnimationOptionCurveLinear) {
            self.curve = UIViewAnimationCurveLinear;
        } else {
            self.curve = UIViewAnimationCurveEaseInOut;
        }
        
        const UIViewAnimationOptions animationTransition = UIViewAnimationOptionTransition(options);
        if (animationTransition == UIViewAnimationOptionTransitionFlipFromLeft) {
            self.transition = UIViewAnimationGroupTransitionFlipFromLeft;
        } else if (animationTransition == UIViewAnimationOptionTransitionFlipFromRight) {
            self.transition = UIViewAnimationGroupTransitionFlipFromRight;
        } else if (animationTransition == UIViewAnimationOptionTransitionCurlUp) {
            self.transition = UIViewAnimationGroupTransitionCurlUp;
        } else if (animationTransition == UIViewAnimationOptionTransitionCurlDown) {
            self.transition = UIViewAnimationGroupTransitionCurlDown;
        } else if (animationTransition == UIViewAnimationOptionTransitionCrossDissolve) {
            self.transition = UIViewAnimationGroupTransitionCrossDissolve;
        } else if (animationTransition == UIViewAnimationOptionTransitionFlipFromTop) {
            self.transition = UIViewAnimationGroupTransitionFlipFromTop;
        } else if (animationTransition == UIViewAnimationOptionTransitionFlipFromBottom) {
            self.transition = UIViewAnimationGroupTransitionFlipFromBottom;
        } else {
            self.transition = UIViewAnimationGroupTransitionNone;
        }
    }
    return self;
}

- (NSArray *)allAnimatingViews
{
    @synchronized(runningAnimationGroupSet) {
        return [_animatingViews allObjects];
    }
}

- (void)notifyAnimationsDidStartIfNeeded
{
    if (!_didStart) {
        _didStart = YES;
        @synchronized(runningAnimationGroupSet) {
            [runningAnimationGroupSet addObject:self];
        }
        // 只要有一个动画开始执行, 更改状态.
    }
}

- (void)notifyAnimationsDidStopIfNeededUsingStatus:(BOOL)animationsDidFinish
{
    if (_waitingAnimationNum == 0) {
        if (self.completionBlock) { // 如果全部动画做完了. 调用 completionBlock.
            self.completionBlock(animationsDidFinish);
        }
        @synchronized(runningAnimationGroupSet) {
            [_animatingViews removeAllObjects];
            [runningAnimationGroupSet removeObject:self];
        }
    }
}

- (void)animationDidStart:(CAAnimation *)theAnimation
{
    [self notifyAnimationsDidStartIfNeeded];
}

- (void)animationDidStop:(CAAnimation *)theAnimation finished:(BOOL)flag
{
    _waitingAnimationNum--;
    [self notifyAnimationsDidStopIfNeededUsingStatus:flag];
}

- (CAAnimation *)addAnimation:(CAAnimation *)animation
{
    // 在这里, 根据自身的状态, 对 CAAnimation 进行赋值操作. 这些状态, 都是根据 UIVIewAnimationOptions 进行传递的.
    animation.timingFunction = CAMediaTimingFunctionFromUIViewAnimationCurve(self.curve);
    animation.duration = self.duration;
    animation.beginTime = _animationBeginTime + self.delay;
    animation.repeatCount = self.repeatCount;
    animation.autoreverses = self.repeatAutoreverses;
    animation.fillMode = kCAFillModeBackwards;
    animation.delegate = self; // 监听每一个动画.
    animation.removedOnCompletion = YES;
    _waitingAnimationNum++;
    return animation;
}

// 这里, 是动画系统调用的. 也就是说, 动画系统会对 layer 进行取值, 取多少次, 就加上多少个 animation. 应该是动画系统根据 keypath 进行取值.
// 生成的 CABasicAnimation 没有设置 toValue, 应该是默认是当前的属性值.
- (id)actionForView:(UIView *)view forKey:(NSString *)keyPath
{
    @synchronized(runningAnimationGroupSet) {
        [_animatingViews addObject:view];
    }

    if (_transitionView && self.transition != UIViewAnimationGroupTransitionNone) {
        return nil;
    } else {
        CALayer *layer = view.layer;
        CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:keyPath];
        animation.fromValue = self.beginsFromCurrentState? [layer.presentationLayer valueForKey:keyPath] : [layer valueForKey:keyPath];
        return [self addAnimation:animation];
    }
}

- (void)setTransitionView:(UIView *)view shouldCache:(BOOL)cache;
{
    _transitionView = view;
    _transitionShouldCache = cache;
}

- (void)commit
{
    // 如果有着转场动画, 那么就给 _transitionView 的 layer 增加一个转场动画.
    // 转场动画, 就是一个 layer 的动画, 它和提交转场动画的时候, animaiton block 里面的动画是分开的.
    if (_transitionView &&
        self.transition != UIViewAnimationGroupTransitionNone) {
        // 如果有转场动画.
        CATransition *trans = [CATransition animation];
        switch (self.transition) {
            case UIViewAnimationGroupTransitionFlipFromLeft:
                trans.type = kCATransitionPush;
                trans.subtype = kCATransitionFromLeft;
                break;
                
            case UIViewAnimationGroupTransitionFlipFromRight:
                trans.type = kCATransitionPush;
                trans.subtype = kCATransitionFromRight;
                break;
                
            case UIViewAnimationGroupTransitionFlipFromTop:
                trans.type = kCATransitionPush;
                trans.subtype = kCATransitionFromTop;
                break;
                
            case UIViewAnimationGroupTransitionFlipFromBottom:
                trans.type = kCATransitionPush;
                trans.subtype = kCATransitionFromBottom;
                break;

            case UIViewAnimationGroupTransitionCurlUp:
                trans.type = kCATransitionReveal;
                trans.subtype = kCATransitionFromTop;
                break;
                
            case UIViewAnimationGroupTransitionCurlDown:
                trans.type = kCATransitionReveal;
                trans.subtype = kCATransitionFromBottom;
                break;
                
            case UIViewAnimationGroupTransitionCrossDissolve:
            default:
                trans.type = kCATransitionFade;
                break;
        }
        
        [_animatingViews addObject:_transitionView];
        [_transitionView.layer addAnimation:[self addAnimation:trans] forKey:kCATransition];
    }
    
    _waitingAnimationNum--; // 这里为什么要减一
    [self notifyAnimationsDidStopIfNeededUsingStatus:YES];
}

@end
