//
//  UIView+Debug.h
//  MCMoego
//
//  Created by JustinLau on 2019/3/25.
//  Copyright © 2019年 Moca Inc. All rights reserved.
//
#if DEBUG

#import <UIKit/UIKit.h>
#import "UIColor+Debug.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * 该类函数, 应该用在调试状况下的断点命令中, 因为 release 模式下, 不编译这些函数.
 */

@interface UIView (Debug)

/**
 * 增加边框, 用于动态调试时, 确定 View 的实际位置. 边框颜色随机
 */
- (void)addBorderLine;
- (void)addBorderLineInWidth:(CGFloat)width;

/**
 * 增加描述文字, 用于动态调试时, 确定 View 的功能. 文字颜色随机
 */
- (void)addTip:(NSString *)tip;

@end

NS_ASSUME_NONNULL_END

#endif
