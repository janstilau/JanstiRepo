//
//  USIndicatorView.m
//  USEvent
//
//  Created by marujun on 15/10/19.
//  Copyright © 2015年 MaRuJun. All rights reserved.
//

#import "USIndicatorView.h"

@implementation USIndicatorView

//code
- (id)initWithFrame:(CGRect)frame
{
    frame.size = CGSizeMake(38, 38);
    
    self = [super initWithFrame:frame];
    if (self) {
        [self setup];
    }
    return self;
}

//XIB
- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self setup];
    }
    return self;
}

- (void)setup
{
    _hidesWhenStopped = YES;
    
    self.backgroundColor = [UIColor clearColor];
    
    UIImageView *imageView = [[UIImageView alloc] init];
    imageView.image = [UIImage imageNamed:@"us_loading_icon.png"];
    [self addSubview:imageView];
    [imageView autoPinEdgesToSuperviewEdgesWithInsets:UIEdgeInsetsZero];
}

- (void)setHidesWhenStopped:(BOOL)hidesWhenStopped
{
    _hidesWhenStopped = hidesWhenStopped;
    
    if (!_hidesWhenStopped) {
        return;
    }
    
    if (self.isAnimating) {
        self.hidden = NO;
    } else {
        self.hidden = YES;
    }
}

- (void)startAnimating
{
    CABasicAnimation* rotationAnimation;
    rotationAnimation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
    rotationAnimation.toValue = [NSNumber numberWithFloat: M_PI * 2.0];
    rotationAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    rotationAnimation.duration = 1.6f;
    //你可以设置到最大的整数值
    rotationAnimation.repeatCount = HUGE_VALF;
    rotationAnimation.cumulative = NO;
    //home键返回继续执行动画
    rotationAnimation.removedOnCompletion = NO;
    rotationAnimation.fillMode = kCAFillModeForwards;
    [self.layer addAnimation:rotationAnimation forKey:@"Rotation"];
    
    self.isAnimating = YES;
    
    if (_hidesWhenStopped) {
        self.hidden = NO;
    }
}

- (void)stopAnimating
{
    self.isAnimating = NO;
    
    [self.layer removeAnimationForKey:@"Rotation"];
    
    if (_hidesWhenStopped) {
        self.hidden = YES;
    }
}

@end
