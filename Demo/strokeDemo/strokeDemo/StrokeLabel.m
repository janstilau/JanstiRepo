//
//  StrokeLabel.m
//  strokeDemo
//
//  Created by JustinLau on 2019/7/2.
//  Copyright © 2019 JustinLau. All rights reserved.
//

#import "StrokeLabel.h"

@implementation StrokeLabel

- (void)drawTextInRect:(CGRect)rect
{
    if (self.strokeWidth > 0) {
        CGSize shadowOffset = self.shadowOffset;
        UIColor *textColor = self.textColor;
        
        CGContextRef c = UIGraphicsGetCurrentContext();
        CGContextSetLineWidth(c, self.strokeWidth);
        CGContextSetLineJoin(c, kCGLineJoinRound);
        //画外边
        CGContextSetTextDrawingMode(c, kCGTextStroke);
        self.textColor = self.strokeColor;
        [super drawTextInRect:rect];
        //画内文字
        CGContextSetTextDrawingMode(c, kCGTextFill);
        self.textColor = textColor;
        self.shadowOffset = CGSizeMake(0, 0);
        [super drawTextInRect:rect];
        self.shadowOffset = shadowOffset;
    } else {
        [super drawTextInRect:rect];
    }
}

@end
