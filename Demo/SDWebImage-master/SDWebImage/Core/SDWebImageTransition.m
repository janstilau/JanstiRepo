/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "SDWebImageTransition.h"

#if SD_UIKIT || SD_MAC

#if SD_MAC
#import "SDWebImageTransitionInternal.h"
#import "SDInternalMacros.h"

/*
 从 SDWebImageAnimationOptions 抽取出 TimeFunction 的信息.
 */
CAMediaTimingFunction * SDTimingFunctionFromAnimationOptions(SDWebImageAnimationOptions options) {
    if (SD_OPTIONS_CONTAINS(SDWebImageAnimationOptionCurveLinear, options)) {
        return [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    } else if (SD_OPTIONS_CONTAINS(SDWebImageAnimationOptionCurveEaseIn, options)) {
        return [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
    } else if (SD_OPTIONS_CONTAINS(SDWebImageAnimationOptionCurveEaseOut, options)) {
        return [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    } else if (SD_OPTIONS_CONTAINS(SDWebImageAnimationOptionCurveEaseInOut, options)) {
        return [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    } else {
        return [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionDefault];
    }
}

/*
 从 SDWebImageAnimationOptions 中, 生成 CATransition 对象.
 之所以, 可以从 SDWebImageAnimationOptions 直接生成 CATransition, 是因为 SDWebImageAnimationOptions 内部, 本身就有着关于 Transition 的值.
 */
CATransition * SDTransitionFromAnimationOptions(SDWebImageAnimationOptions options) {
    if (SD_OPTIONS_CONTAINS(options, SDWebImageAnimationOptionTransitionCrossDissolve)) {
        CATransition *trans = [CATransition animation];
        trans.type = kCATransitionFade;
        return trans;
    } else if (SD_OPTIONS_CONTAINS(options, SDWebImageAnimationOptionTransitionFlipFromLeft)) {
        CATransition *trans = [CATransition animation];
        trans.type = kCATransitionPush;
        trans.subtype = kCATransitionFromLeft;
        return trans;
    } else if (SD_OPTIONS_CONTAINS(options, SDWebImageAnimationOptionTransitionFlipFromRight)) {
        CATransition *trans = [CATransition animation];
        trans.type = kCATransitionPush;
        trans.subtype = kCATransitionFromRight;
        return trans;
    } else if (SD_OPTIONS_CONTAINS(options, SDWebImageAnimationOptionTransitionFlipFromTop)) {
        CATransition *trans = [CATransition animation];
        trans.type = kCATransitionPush;
        trans.subtype = kCATransitionFromTop;
        return trans;
    } else if (SD_OPTIONS_CONTAINS(options, SDWebImageAnimationOptionTransitionFlipFromBottom)) {
        CATransition *trans = [CATransition animation];
        trans.type = kCATransitionPush;
        trans.subtype = kCATransitionFromBottom;
        return trans;
    } else if (SD_OPTIONS_CONTAINS(options, SDWebImageAnimationOptionTransitionCurlUp)) {
        CATransition *trans = [CATransition animation];
        trans.type = kCATransitionReveal;
        trans.subtype = kCATransitionFromTop;
        return trans;
    } else if (SD_OPTIONS_CONTAINS(options, SDWebImageAnimationOptionTransitionCurlDown)) {
        CATransition *trans = [CATransition animation];
        trans.type = kCATransitionReveal;
        trans.subtype = kCATransitionFromBottom;
        return trans;
    } else {
        return nil;
    }
}
#endif

@implementation SDWebImageTransition

- (instancetype)init {
    self = [super init];
    if (self) {
        self.duration = 0.5;
    }
    return self;
}

@end

@implementation SDWebImageTransition (Conveniences)

/*
 各种工厂方法, 生成的对象, 无非是几个关键属性的不同, 也就是 animationOptions.
 因为在真正 UIView 的 transition 方法里面, 就是根据 animationOptions 进行的转场动画的执行.
 */

+ (void)setFadeTransition:(SDWebImageTransition *)fadeTransition {
    NSLog(@"%s", __func__);
}

+ (SDWebImageTransition *)fadeTransition {
    return [self fadeTransitionWithDuration:0.5];
}

+ (SDWebImageTransition *)fadeTransitionWithDuration:(NSTimeInterval)duration {
    SDWebImageTransition *transition = [SDWebImageTransition new];
#if SD_UIKIT
    transition.animationOptions = UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionAllowUserInteraction;
#else
    transition.animationOptions = SDWebImageAnimationOptionTransitionCrossDissolve;
#endif
    return transition;
}

+ (SDWebImageTransition *)flipFromLeftTransition {
    return [self flipFromLeftTransitionWithDuration:0.5];
}

+ (SDWebImageTransition *)flipFromLeftTransitionWithDuration:(NSTimeInterval)duration {
    SDWebImageTransition *transition = [SDWebImageTransition new];
#if SD_UIKIT
    transition.animationOptions = UIViewAnimationOptionTransitionFlipFromLeft | UIViewAnimationOptionAllowUserInteraction;
#else
    transition.animationOptions = SDWebImageAnimationOptionTransitionFlipFromLeft;
#endif
    return transition;
}

+ (SDWebImageTransition *)flipFromRightTransition {
    return [self flipFromRightTransitionWithDuration:0.5];
}

+ (SDWebImageTransition *)flipFromRightTransitionWithDuration:(NSTimeInterval)duration {
    SDWebImageTransition *transition = [SDWebImageTransition new];
#if SD_UIKIT
    transition.animationOptions = UIViewAnimationOptionTransitionFlipFromRight | UIViewAnimationOptionAllowUserInteraction;
#else
    transition.animationOptions = SDWebImageAnimationOptionTransitionFlipFromRight;
#endif
    return transition;
}

+ (SDWebImageTransition *)flipFromTopTransition {
    return [self flipFromTopTransitionWithDuration:0.5];
}

+ (SDWebImageTransition *)flipFromTopTransitionWithDuration:(NSTimeInterval)duration {
    SDWebImageTransition *transition = [SDWebImageTransition new];
#if SD_UIKIT
    transition.animationOptions = UIViewAnimationOptionTransitionFlipFromTop | UIViewAnimationOptionAllowUserInteraction;
#else
    transition.animationOptions = SDWebImageAnimationOptionTransitionFlipFromTop;
#endif
    return transition;
}

+ (SDWebImageTransition *)flipFromBottomTransition {
    return [self flipFromBottomTransitionWithDuration:0.5];
}

+ (SDWebImageTransition *)flipFromBottomTransitionWithDuration:(NSTimeInterval)duration {
    SDWebImageTransition *transition = [SDWebImageTransition new];
#if SD_UIKIT
    transition.animationOptions = UIViewAnimationOptionTransitionFlipFromBottom | UIViewAnimationOptionAllowUserInteraction;
#else
    transition.animationOptions = SDWebImageAnimationOptionTransitionFlipFromBottom;
#endif
    return transition;
}

+ (SDWebImageTransition *)curlUpTransition {
    return [self curlUpTransitionWithDuration:0.5];
}

+ (SDWebImageTransition *)curlUpTransitionWithDuration:(NSTimeInterval)duration {
    SDWebImageTransition *transition = [SDWebImageTransition new];
#if SD_UIKIT
    transition.animationOptions = UIViewAnimationOptionTransitionCurlUp | UIViewAnimationOptionAllowUserInteraction;
#else
    transition.animationOptions = SDWebImageAnimationOptionTransitionCurlUp;
#endif
    return transition;
}

+ (SDWebImageTransition *)curlDownTransition {
    return [self curlDownTransitionWithDuration:0.5];
}

+ (SDWebImageTransition *)curlDownTransitionWithDuration:(NSTimeInterval)duration {
    SDWebImageTransition *transition = [SDWebImageTransition new];
#if SD_UIKIT
    transition.animationOptions = UIViewAnimationOptionTransitionCurlDown | UIViewAnimationOptionAllowUserInteraction;
#else
    transition.animationOptions = SDWebImageAnimationOptionTransitionCurlDown;
#endif
    transition.duration = duration;
    return transition;
}

@end

#endif
