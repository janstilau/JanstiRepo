//
//  TorusIndicatorView.m
//  MCFriends
//
//  Created by marujun on 14/10/28.
//  Copyright (c) 2014年 marujun. All rights reserved.
//

#import "TorusIndicatorView.h"

@implementation TorusIndicatorView

//code
- (id)initWithFrame:(CGRect)frame
{
    frame.size = CGSizeMake(38, 38);
    
    self = [super initWithFrame:frame];
    if (self) {
        _hidesWhenStopped = YES;
        self.backgroundColor = [UIColor clearColor];
    }
    return self;
}

//XIB
- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        _hidesWhenStopped = YES;
        
        self.backgroundColor = [UIColor clearColor];
    }
    return self;
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

- (void)drawRect:(CGRect)rect
{
    // Drawing code
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    //画圆
    CGContextSetStrokeColorWithColor(context, [UIColor colorWithRed:0 green:0 blue:0 alpha:0.5].CGColor);
    CGContextSetLineWidth(context, 4.0f);
    CGContextAddArc(context, self.bounds.size.width/2.0f, self.bounds.size.height/2.0f, (self.bounds.size.height/2.0f - 5), 0, 2*M_PI, 0); //添加一个圆
    CGContextDrawPath(context, kCGPathStroke); //绘制路径
    CGContextStrokePath(context);//绘画路径
    
    //
    CGContextSetStrokeColorWithColor(context, [UIColor whiteColor].CGColor);
    CGContextSetLineWidth(context, 4.4f);
    CGContextSetLineCap(context, kCGLineCapRound);
    CGContextAddArc(context, self.bounds.size.width/2.0f, self.bounds.size.height/2.0f, (self.bounds.size.height/2.0f - 5), 0, 0.75*M_PI, 0);
    CGContextStrokePath(context);//绘画路径
}

- (void)startAnimating
{
    CABasicAnimation* rotationAnimation;
    rotationAnimation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
    rotationAnimation.toValue = [NSNumber numberWithFloat: M_PI * 2.0];
    [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    rotationAnimation.duration = 0.8f;
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
