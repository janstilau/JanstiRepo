//
//  UIButton+New.h
//  HLMagic
//
//  Created by marujun on 13-12-6.
//  Copyright (c) 2013年 chen ying. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIButton (New)

/** 扩大按钮点击区域 */
@property (nonatomic, assign) UIEdgeInsets hitEdgeInsets;

/** 白色箭头的返回按钮 */
+ (UIButton *)newBackArrowNavButtonWithTarget:(id)target action:(SEL)action;

/** 底色为透明的按钮 */
+ (UIButton *)newNavButtonWithTitle:(NSString *)title target:(id)target action:(SEL)action;

+ (UIButton *)newNavButtonWithImage:(UIImage *)image target:(id)target action:(SEL)action;

@end
