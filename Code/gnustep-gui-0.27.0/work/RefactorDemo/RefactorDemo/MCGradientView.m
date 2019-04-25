//
//  MCGradientView.m
//  MCMoego
//
//  Created by 任成 on 2018/7/23.
//  Copyright © 2018年 Moca Inc. All rights reserved.
//

#import "MCGradientView.h"

@interface MCGradientView()

@property (nonatomic, strong) UIView *bgView; //!< 渐变加到这个视图上, 阴影和clipToBounds冲突
@property (nonatomic, strong) CAGradientLayer *gradientLayer; //!< 渐变图层

@end

@implementation MCGradientView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setupViews];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        [self setupViews];
    }
    return self;
}

- (void)setupViews {
    [self setupBgView];
    [self setupGradientView];
}

- (void)setupBgView {
    _bgView = [[UIView alloc] init];
    _bgView.backgroundColor = [UIColor clearColor];
    _bgView.userInteractionEnabled = NO;
    [self addSubview:_bgView];
}

- (void)setupGradientView {
    _gradientLayer = [CAGradientLayer layer];
    _gradientLayer.startPoint = CGPointMake(0, 0);
    _gradientLayer.endPoint = CGPointMake(1, 0);
    [_bgView.layer addSublayer:_gradientLayer];
}

- (void)setColors:(NSArray *)colors {
    _colors = colors;
    [self updateView];
}

- (void)updateView {
    self.gradientLayer.hidden = !_colors;
    NSMutableArray *cgColorsM = [NSMutableArray arrayWithCapacity:_colors.count];
    for (UIColor *aColor in _colors) {
        [cgColorsM addObject:(id)[aColor CGColor]];
    }
    _gradientLayer.colors = cgColorsM;
    NSMutableArray *locationsM = [NSMutableArray arrayWithCapacity:_colors.count];
    [locationsM addObject:@(0)];
    CGFloat margin = 1.0 / (_colors.count-1);
    for (int i = 1; i < _colors.count-1; ++i) {
        [locationsM addObject:@(margin * i)];
    }
    [locationsM addObject:@(1)];
    _gradientLayer.locations = locationsM;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _bgView.frame = self.bounds;
    _gradientLayer.frame = self.bounds;
}

@end
