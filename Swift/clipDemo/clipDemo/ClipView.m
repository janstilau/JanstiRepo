//
//  ClipView.m
//  clipDemo
//
//  Created by JustinLau on 2019/12/19.
//  Copyright © 2019 JustinLau. All rights reserved.
//

#import "ClipView.h"

@implementation ClipView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setup];
        self.backgroundColor = [UIColor redColor];
    }
    return self;
}

#define SCREEN_WIDTH         [[UIScreen mainScreen] bounds].size.width
#define SCREEN_HEIGHT        [[UIScreen mainScreen] bounds].size.height

static const CGFloat kPostCardHeight = 40;
static const CGFloat kPostCardLRMargin = 14;
static const CGFloat kCardBottomMargin = 14;

- (void)setup {
    UIBezierPath *bezierPath = [UIBezierPath bezierPath];
    NSInteger count = 3;
    [bezierPath moveToPoint:CGPointMake(0, kPostCardHeight*0.5)];
    [bezierPath addLineToPoint:CGPointMake(0, kPostCardHeight*count + kCardBottomMargin)];
    [bezierPath addLineToPoint:CGPointMake(SCREEN_WIDTH, kPostCardHeight*count + kCardBottomMargin)];
    [bezierPath addLineToPoint:CGPointMake(SCREEN_WIDTH, kPostCardHeight*0.5)];
//    [bezierPath addQuadCurveToPoint:CGPointMake(SCREEN_WIDTH-kPostCardLRMargin, kPostCardHeight*0.5) controlPoint:CGPointMake(SCREEN_WIDTH*-100, -50)];
    [bezierPath addLineToPoint:CGPointMake(SCREEN_WIDTH-kPostCardLRMargin, kPostCardHeight*0.5)];
//    [bezierPath addQuadCurveToPoint:CGPointMake(0, kPostCardHeight*0.5) controlPoint:CGPointMake(100, -50)];
    CAShapeLayer *shapeLayer = [CAShapeLayer layer];
    shapeLayer.opacity = 0.5;
    shapeLayer.backgroundColor = [[UIColor blueColor] CGColor];
    shapeLayer.path = [bezierPath CGPath];
    self.layer.mask = shapeLayer;
    
    self.layer.borderColor = [[UIColor blueColor] CGColor];
    self.layer.borderWidth = 1;
}

@end
