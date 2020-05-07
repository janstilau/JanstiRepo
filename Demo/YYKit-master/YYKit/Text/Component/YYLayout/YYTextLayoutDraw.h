//
//  YYTextLayoutDraw.h
//  YYKitDemo
//
//  Created by JustinLau on 2019/4/21.
//  Copyright © 2019 ibireme. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "YYKit.h"

NS_ASSUME_NONNULL_BEGIN

@class YYTextLayout;

extern void YYTextDrawDebug(YYTextLayout *layout, CGContextRef context, CGSize size, CGPoint point, YYTextDebugOption *op);
extern void YYTextDrawInnerShadow(YYTextLayout *layout, CGContextRef context, CGSize size, CGPoint point, BOOL (^cancel)(void));
extern void YYTextDrawShadow(YYTextLayout *layout, CGContextRef context, CGSize size, CGPoint point, BOOL (^cancel)(void));
extern void YYTextDrawAttachment(YYTextLayout *layout, CGContextRef context, CGSize size, CGPoint point, UIView *targetView, CALayer *targetLayer, BOOL (^cancel)(void));
extern void YYTextDrawDecoration(YYTextLayout *layout, CGContextRef context, CGSize size, CGPoint point, YYTextDecorationType type, BOOL (^cancel)(void));
extern void YYTextDrawBorder(YYTextLayout *layout, CGContextRef context, CGSize size, CGPoint point, YYTextBorderType type, BOOL (^cancel)(void));
extern void YYTextDrawBlockBorder(YYTextLayout *layout, CGContextRef context, CGSize size, CGPoint point, BOOL (^cancel)(void));
extern void YYTextDrawText(YYTextLayout *layout, CGContextRef context, CGSize size, CGPoint point, BOOL (^cancel)(void));
extern void YYTextDrawLineStyle(CGContextRef context, CGFloat length, CGFloat lineWidth, YYTextLineStyle style, CGPoint position, CGColorRef color, BOOL isVertical);
extern void YYTextDrawBorderRects(CGContextRef context, CGSize size, YYTextBorder *border, NSArray *rects, BOOL isVertical);
extern void YYTextSetLinePatternInContext(YYTextLineStyle style, CGFloat width, CGFloat phase, CGContextRef context);
extern void YYTextDrawRun(YYTextLine *line, CTRunRef run, CGContextRef context, CGSize size, BOOL isVertical, NSArray *runRanges, CGFloat verticalOffset);
extern void YYTextGetRunsMaxMetric(CFArrayRef runs, CGFloat *xHeight, CGFloat *underlinePosition, CGFloat *lineThickness);
extern CGRect YYTextMergeRectInSameLine(CGRect rect1, CGRect rect2, BOOL isVertical);
extern CGColorRef YYTextGetCGColor(CGColorRef color);
extern CGSize YYTextClipCGSize(CGSize size);
extern UIEdgeInsets UIEdgeInsetRotateVertical(UIEdgeInsets insets);

NS_ASSUME_NONNULL_END
