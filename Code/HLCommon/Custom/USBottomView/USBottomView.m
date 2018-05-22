//
//  USBottomView.m
//  HTWallet
//
//  Created by ZK on 16/10/11.
//  Copyright © 2016年 MaRuJun. All rights reserved.
//

#import "USBottomView.h"

@interface USBottomView ()

@property (nonatomic, strong) UIButton *submitBtn;

@end

const CGFloat USBottomViewHeight = 88.f;

@implementation USBottomView

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        [self setup];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder]) {
        [self setup];
    }
    return self;
}

- (void)setup
{
    self.size = (CGSize){SCREEN_WIDTH, USBottomViewHeight};
    self.backgroundColor = [UIColor clearColor];
    
    _submitBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    _submitBtn.titleLabel.font = [UIFont fontWithName:FZLTXIHFontName size:AutoFitFontSize(16.f)];
    _submitBtn.backgroundColor = KY_TINT_HIGHLIGHT_COLOR;
    [_submitBtn setTitleColor:HexColor(0x535353) forState:UIControlStateNormal];
    [self addSubview:_submitBtn];
    
    _submitBtn.size = (CGSize){(320.f-30.f)*WindowZoomScale, 48.f};
    _submitBtn.layer.cornerRadius = 7.f;
    _submitBtn.layer.masksToBounds = YES;
    [_submitBtn setBackgroundImage:[UIImage imageWithColor:KY_TINT_COLOR] forState:UIControlStateNormal];
    [_submitBtn setBackgroundImage:[UIImage imageWithColor:KY_TINT_HIGHLIGHT_COLOR] forState:UIControlStateHighlighted];
    [_submitBtn setTitle:@"完成" forState:UIControlStateNormal];
    [_submitBtn addTarget:self action:@selector(submitBtnClick) forControlEvents:UIControlEventTouchUpInside];
}

#pragma mark - Setter

- (void)setTitle:(NSString *)title
{
    _title = title;
    
    [_submitBtn setTitle:title forState:UIControlStateNormal];
}

#pragma mark - Layout

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    self.bottom = self.superview.height;
    
    _submitBtn.bottom = (self.height - 15.f);
    _submitBtn.centerX = SCREEN_WIDTH*0.5;
}

#pragma mark - Action

- (void)submitBtnClick
{
    if ([self.delegate respondsToSelector:@selector(bottomViewDidClickButton:)]) {
        [self.delegate bottomViewDidClickButton:self];
    }
}

@end
