//
//  UIColor+Debug.h
//  MCMoego
//
//  Created by JustinLau on 2019/3/25.
//  Copyright © 2019年 Moca Inc. All rights reserved.
//

#if DEBUG

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIColor (Debug)

+ (UIColor *)randomColor;

@end

NS_ASSUME_NONNULL_END

#endif
