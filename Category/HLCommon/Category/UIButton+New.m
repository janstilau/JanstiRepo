//
//  UIButton+New.m
//  HLMagic
//
//  Created by marujun on 13-12-6.
//  Copyright (c) 2013年 chen ying. All rights reserved.
//

#import "UIButton+New.h"
#import <objc/runtime.h>

@implementation UIButton (New)
@dynamic hitEdgeInsets;

static const NSString *keyHitEdgeInsets = @"HitTestEdgeInsets";

- (void)setHitEdgeInsets:(UIEdgeInsets)hitEdgeInsets
{
    NSValue *value = [NSValue value:&hitEdgeInsets
                       withObjCType:@encode(UIEdgeInsets)];
    objc_setAssociatedObject(self,
                             &keyHitEdgeInsets,
                             value,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIEdgeInsets)hitEdgeInsets
{
    NSValue *value = objc_getAssociatedObject(self, &keyHitEdgeInsets);
    if (value) {
        UIEdgeInsets edgeInsets;
        [value getValue:&edgeInsets];
        return edgeInsets;
    }
    else {
        return UIEdgeInsetsZero;
    }
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
    if (UIEdgeInsetsEqualToEdgeInsets(self.hitEdgeInsets, UIEdgeInsetsZero)
        || !self.enabled
        || self.hidden) {
        return [super pointInside:point withEvent:event];
    }
    
    CGRect relativeFrame = self.bounds;
    CGRect hitFrame = UIEdgeInsetsInsetRect(relativeFrame, self.hitEdgeInsets);
    
    return CGRectContainsPoint(hitFrame, point);
}

//白色箭头的返回按钮
+ (UIButton *)newBackArrowNavButtonWithTarget:(id)target action:(SEL)action
{
    UIButton *rightButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 46, 44)];
    [rightButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    rightButton.titleLabel.font = [UIFont fontWithName:FZLTXIHFontName size:14];
    [rightButton setContentHorizontalAlignment:UIControlContentHorizontalAlignmentLeft];
    [rightButton setContentVerticalAlignment:UIControlContentVerticalAlignmentCenter];
    [rightButton setTitleEdgeInsets:UIEdgeInsetsMake(0, 4, 0, 0)];
    [rightButton setContentEdgeInsets:UIEdgeInsetsMake(0, 0, 5, 0)];
    
    [rightButton setImage:[UIImage imageNamed:(@"pub_nav_back.png")] forState:UIControlStateNormal];
    [rightButton setTitleColor:KG_TINT_COLOR forState:UIControlStateHighlighted];
    if (action && target) {
        [rightButton addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    }
    return rightButton;
}

+ (UIButton *)newNavButtonWithTitle:(NSString *)title target:(id)target action:(SEL)action
{
    float height = 44;
    UIFont *font = [UIFont fontWithName:FZLTXIHFontName size:15];
    float width = [title stringWidthWithFont:font height:height];
    
    UIButton *rightButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, width + 5, height)];
    [rightButton setBackgroundColor:[UIColor clearColor]];
    rightButton.titleLabel.font = font;
    
    [rightButton setTitle:title forState:UIControlStateNormal];
    [rightButton setTitleColor:KG_TINT_COLOR forState:UIControlStateNormal];
    [rightButton setTitleColor:KG_TINT_HIGHLIGHT_COLOR forState:UIControlStateHighlighted];
    
    [rightButton setTitleEdgeInsets:UIEdgeInsetsMake(0, 0, 3, 0)];
    
    if (action && target) {
        [rightButton addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    }
    return rightButton;
}

+ (UIButton *)newNavButtonWithImage:(UIImage *)image target:(id)target action:(SEL)action
{
    UIButton *button = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 44, 44)];
    [button setImageEdgeInsets:UIEdgeInsetsMake(0, 10, 0, 0)];
    [button setImage:image forState:UIControlStateNormal];
    if (action && target) {
        [button addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    }
    return button;
}

@end
