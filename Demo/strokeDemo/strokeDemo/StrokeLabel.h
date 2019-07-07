//
//  StrokeLabel.h
//  strokeDemo
//
//  Created by JustinLau on 2019/7/2.
//  Copyright © 2019 JustinLau. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface StrokeLabel : UILabel

@property (strong,nonatomic) UIColor *strokeColor;
@property (assign,nonatomic) CGFloat strokeWidth;

@end

NS_ASSUME_NONNULL_END
