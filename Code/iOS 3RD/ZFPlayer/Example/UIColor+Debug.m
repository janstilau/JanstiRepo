//
//  UIColor+Debug.m
//  MCMoego
//
//  Created by JustinLau on 2019/3/25.
//  Copyright © 2019年 Moca Inc. All rights reserved.
//

#if DEBUG

#import "UIColor+Debug.h"

@implementation UIColor (Debug)

+ (UIColor *)randomColor {
    return [UIColor colorWithRed:random() % 255 / 255.0
                           green:random() % 255 / 255.0
                            blue:random() % 255 / 255.0
                           alpha:1.0];
}

@end

#endif
