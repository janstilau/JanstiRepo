//
//  YYTextLayoutDraw.m
//  YYKitDemo
//
//  Created by JustinLau on 2019/4/21.
//  Copyright © 2019 ibireme. All rights reserved.
//

#import "YYTextLayoutDraw.h"
#import "YYTextLayout.h"

 inline CGSize YYTextClipCGSize(CGSize size) {
    if (size.width > YYTextContainerMaxSize.width) size.width = YYTextContainerMaxSize.width;
    if (size.height > YYTextContainerMaxSize.height) size.height = YYTextContainerMaxSize.height;
    return size;
}

 inline UIEdgeInsets UIEdgeInsetRotateVertical(UIEdgeInsets insets) {
    UIEdgeInsets one;
    one.top = insets.left;
    one.left = insets.bottom;
    one.bottom = insets.right;
    one.right = insets.top;
    return one;
}

CGColorRef YYTextGetCGColor(CGColorRef color) {
    static UIColor *defaultColor;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        defaultColor = [UIColor blackColor];
    });
    if (!color) return defaultColor.CGColor;
    if ([((__bridge NSObject *)color) respondsToSelector:@selector(CGColor)]) {
        return ((__bridge UIColor *)color).CGColor;
    }
    return color;
}


CGRect YYTextMergeRectInSameLine(CGRect rect1, CGRect rect2, BOOL isVertical) {
    if (isVertical) {
        CGFloat top = MIN(rect1.origin.y, rect2.origin.y);
        CGFloat bottom = MAX(rect1.origin.y + rect1.size.height, rect2.origin.y + rect2.size.height);
        CGFloat width = MAX(rect1.size.width, rect2.size.width);
        return CGRectMake(rect1.origin.x, top, width, bottom - top);
    } else {
        CGFloat left = MIN(rect1.origin.x, rect2.origin.x);
        CGFloat right = MAX(rect1.origin.x + rect1.size.width, rect2.origin.x + rect2.size.width);
        CGFloat height = MAX(rect1.size.height, rect2.size.height);
        return CGRectMake(left, rect1.origin.y, right - left, height);
    }
}

void YYTextGetRunsMaxMetric(CFArrayRef runs, CGFloat *xHeight, CGFloat *underlinePosition, CGFloat *lineThickness) {
    CGFloat maxXHeight = 0;
    CGFloat maxUnderlinePos = 0;
    CGFloat maxLineThickness = 0;
    for (NSUInteger i = 0, max = CFArrayGetCount(runs); i < max; i++) {
        CTRunRef run = CFArrayGetValueAtIndex(runs, i);
        CFDictionaryRef attrs = CTRunGetAttributes(run);
        if (attrs) {
            CTFontRef font = CFDictionaryGetValue(attrs, kCTFontAttributeName);
            if (font) {
                CGFloat xHeight = CTFontGetXHeight(font);
                if (xHeight > maxXHeight) maxXHeight = xHeight;
                CGFloat underlinePos = CTFontGetUnderlinePosition(font);
                if (underlinePos < maxUnderlinePos) maxUnderlinePos = underlinePos;
                CGFloat lineThickness = CTFontGetUnderlineThickness(font);
                if (lineThickness > maxLineThickness) maxLineThickness = lineThickness;
            }
        }
    }
    if (xHeight) *xHeight = maxXHeight;
    if (underlinePosition) *underlinePosition = maxUnderlinePos;
    if (lineThickness) *lineThickness = maxLineThickness;
}

void YYTextDrawRun(YYTextLine *line, CTRunRef run, CGContextRef context, CGSize size, BOOL isVertical, NSArray *runRanges, CGFloat verticalOffset) {
    CGAffineTransform runTextMatrix = CTRunGetTextMatrix(run);
    BOOL runTextMatrixIsID = CGAffineTransformIsIdentity(runTextMatrix);
    
    CFDictionaryRef runAttrs = CTRunGetAttributes(run);
    NSValue *glyphTransformValue = CFDictionaryGetValue(runAttrs, (__bridge const void *)(YYTextGlyphTransformAttributeName));
    if (!isVertical && !glyphTransformValue) { // draw run
        if (!runTextMatrixIsID) {
            CGContextSaveGState(context);
            CGAffineTransform trans = CGContextGetTextMatrix(context);
            CGContextSetTextMatrix(context, CGAffineTransformConcat(trans, runTextMatrix));
        }
        CTRunDraw(run, context, CFRangeMake(0, 0));
        if (!runTextMatrixIsID) {
            CGContextRestoreGState(context);
        }
    } else { // draw glyph
        CTFontRef runFont = CFDictionaryGetValue(runAttrs, kCTFontAttributeName);
        if (!runFont) return;
        NSUInteger glyphCount = CTRunGetGlyphCount(run);
        if (glyphCount <= 0) return;
        
        CGGlyph glyphs[glyphCount];
        CGPoint glyphPositions[glyphCount];
        CTRunGetGlyphs(run, CFRangeMake(0, 0), glyphs);
        CTRunGetPositions(run, CFRangeMake(0, 0), glyphPositions);
        
        CGColorRef fillColor = (CGColorRef)CFDictionaryGetValue(runAttrs, kCTForegroundColorAttributeName);
        fillColor = YYTextGetCGColor(fillColor);
        NSNumber *strokeWidth = CFDictionaryGetValue(runAttrs, kCTStrokeWidthAttributeName);
        
        CGContextSaveGState(context); {
            CGContextSetFillColorWithColor(context, fillColor);
            if ((strokeWidth == nil) || strokeWidth.floatValue == 0) {
                CGContextSetTextDrawingMode(context, kCGTextFill);
            } else {
                CGColorRef strokeColor = (CGColorRef)CFDictionaryGetValue(runAttrs, kCTStrokeColorAttributeName);
                if (!strokeColor) strokeColor = fillColor;
                CGContextSetStrokeColorWithColor(context, strokeColor);
                CGContextSetLineWidth(context, CTFontGetSize(runFont) * fabs(strokeWidth.floatValue * 0.01));
                if (strokeWidth.floatValue > 0) {
                    CGContextSetTextDrawingMode(context, kCGTextStroke);
                } else {
                    CGContextSetTextDrawingMode(context, kCGTextFillStroke);
                }
            }
            
            if (isVertical) {
                CFIndex runStrIdx[glyphCount + 1];
                CTRunGetStringIndices(run, CFRangeMake(0, 0), runStrIdx);
                CFRange runStrRange = CTRunGetStringRange(run);
                runStrIdx[glyphCount] = runStrRange.location + runStrRange.length;
                CGSize glyphAdvances[glyphCount];
                CTRunGetAdvances(run, CFRangeMake(0, 0), glyphAdvances);
                CGFloat ascent = CTFontGetAscent(runFont);
                CGFloat descent = CTFontGetDescent(runFont);
                CGAffineTransform glyphTransform = glyphTransformValue.CGAffineTransformValue;
                CGPoint zeroPoint = CGPointZero;
                
                for (YYTextRunGlyphRange *oneRange in runRanges) {
                    NSRange range = oneRange.glyphRangeInRun;
                    NSUInteger rangeMax = range.location + range.length;
                    YYTextRunGlyphDrawMode mode = oneRange.drawMode;
                    
                    for (NSUInteger g = range.location; g < rangeMax; g++) {
                        CGContextSaveGState(context); {
                            CGContextSetTextMatrix(context, CGAffineTransformIdentity);
                            if (glyphTransformValue) {
                                CGContextSetTextMatrix(context, glyphTransform);
                            }
                            if (mode) { // CJK glyph, need rotated
                                CGFloat ofs = (ascent - descent) * 0.5;
                                CGFloat w = glyphAdvances[g].width * 0.5;
                                CGFloat x = x = line.position.x + verticalOffset + glyphPositions[g].y + (ofs - w);
                                CGFloat y = -line.position.y + size.height - glyphPositions[g].x - (ofs + w);
                                if (mode == YYTextRunGlyphDrawModeVerticalRotateMove) {
                                    x += w;
                                    y += w;
                                }
                                CGContextSetTextPosition(context, x, y);
                            } else {
                                CGContextRotateCTM(context, DegreesToRadians(-90));
                                CGContextSetTextPosition(context,
                                                         line.position.y - size.height + glyphPositions[g].x,
                                                         line.position.x + verticalOffset + glyphPositions[g].y);
                            }
                            
                            if (CTFontContainsColorBitmapGlyphs(runFont)) {
                                CTFontDrawGlyphs(runFont, glyphs + g, &zeroPoint, 1, context);
                            } else {
                                CGFontRef cgFont = CTFontCopyGraphicsFont(runFont, NULL);
                                CGContextSetFont(context, cgFont);
                                CGContextSetFontSize(context, CTFontGetSize(runFont));
                                CGContextShowGlyphsAtPositions(context, glyphs + g, &zeroPoint, 1);
                                CGFontRelease(cgFont);
                            }
                        } CGContextRestoreGState(context);
                    }
                }
            } else { // not vertical
                if (glyphTransformValue) {
                    CFIndex runStrIdx[glyphCount + 1];
                    CTRunGetStringIndices(run, CFRangeMake(0, 0), runStrIdx);
                    CFRange runStrRange = CTRunGetStringRange(run);
                    runStrIdx[glyphCount] = runStrRange.location + runStrRange.length;
                    CGSize glyphAdvances[glyphCount];
                    CTRunGetAdvances(run, CFRangeMake(0, 0), glyphAdvances);
                    CGAffineTransform glyphTransform = glyphTransformValue.CGAffineTransformValue;
                    CGPoint zeroPoint = CGPointZero;
                    
                    for (NSUInteger g = 0; g < glyphCount; g++) {
                        CGContextSaveGState(context); {
                            CGContextSetTextMatrix(context, CGAffineTransformIdentity);
                            CGContextSetTextMatrix(context, glyphTransform);
                            CGContextSetTextPosition(context,
                                                     line.position.x + glyphPositions[g].x,
                                                     size.height - (line.position.y + glyphPositions[g].y));
                            
                            if (CTFontContainsColorBitmapGlyphs(runFont)) {
                                CTFontDrawGlyphs(runFont, glyphs + g, &zeroPoint, 1, context);
                            } else {
                                CGFontRef cgFont = CTFontCopyGraphicsFont(runFont, NULL);
                                CGContextSetFont(context, cgFont);
                                CGContextSetFontSize(context, CTFontGetSize(runFont));
                                CGContextShowGlyphsAtPositions(context, glyphs + g, &zeroPoint, 1);
                                CGFontRelease(cgFont);
                            }
                        } CGContextRestoreGState(context);
                    }
                } else {
                    if (CTFontContainsColorBitmapGlyphs(runFont)) {
                        CTFontDrawGlyphs(runFont, glyphs, glyphPositions, glyphCount, context);
                    } else {
                        CGFontRef cgFont = CTFontCopyGraphicsFont(runFont, NULL);
                        CGContextSetFont(context, cgFont);
                        CGContextSetFontSize(context, CTFontGetSize(runFont));
                        CGContextShowGlyphsAtPositions(context, glyphs, glyphPositions, glyphCount);
                        CGFontRelease(cgFont);
                    }
                }
            }
            
        } CGContextRestoreGState(context);
    }
}

void YYTextSetLinePatternInContext(YYTextLineStyle style, CGFloat width, CGFloat phase, CGContextRef context){
    CGContextSetLineWidth(context, width);
    CGContextSetLineCap(context, kCGLineCapButt);
    CGContextSetLineJoin(context, kCGLineJoinMiter);
    
    CGFloat dash = 12, dot = 5, space = 3;
    NSUInteger pattern = style & 0xF00;
    if (pattern == YYTextLineStylePatternSolid) {
        CGContextSetLineDash(context, phase, NULL, 0);
    } else if (pattern == YYTextLineStylePatternDot) {
        CGFloat lengths[2] = {width * dot, width * space};
        CGContextSetLineDash(context, phase, lengths, 2);
    } else if (pattern == YYTextLineStylePatternDash) {
        CGFloat lengths[2] = {width * dash, width * space};
        CGContextSetLineDash(context, phase, lengths, 2);
    } else if (pattern == YYTextLineStylePatternDashDot) {
        CGFloat lengths[4] = {width * dash, width * space, width * dot, width * space};
        CGContextSetLineDash(context, phase, lengths, 4);
    } else if (pattern == YYTextLineStylePatternDashDotDot) {
        CGFloat lengths[6] = {width * dash, width * space,width * dot, width * space, width * dot, width * space};
        CGContextSetLineDash(context, phase, lengths, 6);
    } else if (pattern == YYTextLineStylePatternCircleDot) {
        CGFloat lengths[2] = {width * 0, width * 3};
        CGContextSetLineDash(context, phase, lengths, 2);
        CGContextSetLineCap(context, kCGLineCapRound);
        CGContextSetLineJoin(context, kCGLineJoinRound);
    }
}


void YYTextDrawBorderRects(CGContextRef context, CGSize size, YYTextBorder *border, NSArray *rects, BOOL isVertical) {
    if (rects.count == 0) return;
    
    YYTextShadow *shadow = border.shadow;
    if (shadow.color) {
        CGContextSaveGState(context);
        CGContextSetShadowWithColor(context, shadow.offset, shadow.radius, shadow.color.CGColor);
        CGContextBeginTransparencyLayer(context, NULL);
    }
    
    NSMutableArray *paths = [NSMutableArray new];
    for (NSValue *value in rects) {
        CGRect rect = value.CGRectValue;
        if (isVertical) {
            rect = UIEdgeInsetsInsetRect(rect, UIEdgeInsetRotateVertical(border.insets));
        } else {
            rect = UIEdgeInsetsInsetRect(rect, border.insets);
        }
        rect = CGRectPixelRound(rect);
        UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:border.cornerRadius];
        [path closePath];
        [paths addObject:path];
    }
    
    if (border.fillColor) {
        CGContextSaveGState(context);
        CGContextSetFillColorWithColor(context, border.fillColor.CGColor);
        for (UIBezierPath *path in paths) {
            CGContextAddPath(context, path.CGPath);
        }
        CGContextFillPath(context);
        CGContextRestoreGState(context);
    }
    
    if (border.strokeColor && border.lineStyle > 0 && border.strokeWidth > 0) {
        
        //-------------------------- single line ------------------------------//
        CGContextSaveGState(context);
        for (UIBezierPath *path in paths) {
            CGRect bounds = CGRectUnion(path.bounds, (CGRect){CGPointZero, size});
            bounds = CGRectInset(bounds, -2 * border.strokeWidth, -2 * border.strokeWidth);
            CGContextAddRect(context, bounds);
            CGContextAddPath(context, path.CGPath);
            CGContextEOClip(context);
        }
        [border.strokeColor setStroke];
        YYTextSetLinePatternInContext(border.lineStyle, border.strokeWidth, 0, context);
        CGFloat inset = -border.strokeWidth * 0.5;
        if ((border.lineStyle & 0xFF) == YYTextLineStyleThick) {
            inset *= 2;
            CGContextSetLineWidth(context, border.strokeWidth * 2);
        }
        CGFloat radiusDelta = -inset;
        if (border.cornerRadius <= 0) {
            radiusDelta = 0;
        }
        CGContextSetLineJoin(context, border.lineJoin);
        for (NSValue *value in rects) {
            CGRect rect = value.CGRectValue;
            if (isVertical) {
                rect = UIEdgeInsetsInsetRect(rect, UIEdgeInsetRotateVertical(border.insets));
            } else {
                rect = UIEdgeInsetsInsetRect(rect, border.insets);
            }
            rect = CGRectInset(rect, inset, inset);
            UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:border.cornerRadius + radiusDelta];
            [path closePath];
            CGContextAddPath(context, path.CGPath);
        }
        CGContextStrokePath(context);
        CGContextRestoreGState(context);
        
        //------------------------- second line ------------------------------//
        if ((border.lineStyle & 0xFF) == YYTextLineStyleDouble) {
            CGContextSaveGState(context);
            CGFloat inset = -border.strokeWidth * 2;
            for (NSValue *value in rects) {
                CGRect rect = value.CGRectValue;
                rect = UIEdgeInsetsInsetRect(rect, border.insets);
                rect = CGRectInset(rect, inset, inset);
                UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:border.cornerRadius + 2 * border.strokeWidth];
                [path closePath];
                
                CGRect bounds = CGRectUnion(path.bounds, (CGRect){CGPointZero, size});
                bounds = CGRectInset(bounds, -2 * border.strokeWidth, -2 * border.strokeWidth);
                CGContextAddRect(context, bounds);
                CGContextAddPath(context, path.CGPath);
                CGContextEOClip(context);
            }
            CGContextSetStrokeColorWithColor(context, border.strokeColor.CGColor);
            YYTextSetLinePatternInContext(border.lineStyle, border.strokeWidth, 0, context);
            CGContextSetLineJoin(context, border.lineJoin);
            inset = -border.strokeWidth * 2.5;
            radiusDelta = border.strokeWidth * 2;
            if (border.cornerRadius <= 0) {
                radiusDelta = 0;
            }
            for (NSValue *value in rects) {
                CGRect rect = value.CGRectValue;
                rect = UIEdgeInsetsInsetRect(rect, border.insets);
                rect = CGRectInset(rect, inset, inset);
                UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:border.cornerRadius + radiusDelta];
                [path closePath];
                CGContextAddPath(context, path.CGPath);
            }
            CGContextStrokePath(context);
            CGContextRestoreGState(context);
        }
    }
    
    if (shadow.color) {
        CGContextEndTransparencyLayer(context);
        CGContextRestoreGState(context);
    }
}

void YYTextDrawLineStyle(CGContextRef context, CGFloat length, CGFloat lineWidth, YYTextLineStyle style, CGPoint position, CGColorRef color, BOOL isVertical) {
    NSUInteger styleBase = style & 0xFF;
    if (styleBase == 0) return;
    
    CGContextSaveGState(context); {
        if (isVertical) {
            CGFloat x, y1, y2, w;
            y1 = CGFloatPixelRound(position.y);
            y2 = CGFloatPixelRound(position.y + length);
            w = (styleBase == YYTextLineStyleThick ? lineWidth * 2 : lineWidth);
            
            CGFloat linePixel = CGFloatToPixel(w);
            if (fabs(linePixel - floor(linePixel)) < 0.1) {
                int iPixel = linePixel;
                if (iPixel == 0 || (iPixel % 2)) { // odd line pixel
                    x = CGFloatPixelHalf(position.x);
                } else {
                    x = CGFloatPixelFloor(position.x);
                }
            } else {
                x = position.x;
            }
            
            CGContextSetStrokeColorWithColor(context, color);
            YYTextSetLinePatternInContext(style, lineWidth, position.y, context);
            CGContextSetLineWidth(context, w);
            if (styleBase == YYTextLineStyleSingle) {
                CGContextMoveToPoint(context, x, y1);
                CGContextAddLineToPoint(context, x, y2);
                CGContextStrokePath(context);
            } else if (styleBase == YYTextLineStyleThick) {
                CGContextMoveToPoint(context, x, y1);
                CGContextAddLineToPoint(context, x, y2);
                CGContextStrokePath(context);
            } else if (styleBase == YYTextLineStyleDouble) {
                CGContextMoveToPoint(context, x - w, y1);
                CGContextAddLineToPoint(context, x - w, y2);
                CGContextStrokePath(context);
                CGContextMoveToPoint(context, x + w, y1);
                CGContextAddLineToPoint(context, x + w, y2);
                CGContextStrokePath(context);
            }
        } else {
            CGFloat x1, x2, y, w;
            x1 = CGFloatPixelRound(position.x);
            x2 = CGFloatPixelRound(position.x + length);
            w = (styleBase == YYTextLineStyleThick ? lineWidth * 2 : lineWidth);
            
            CGFloat linePixel = CGFloatToPixel(w);
            if (fabs(linePixel - floor(linePixel)) < 0.1) {
                int iPixel = linePixel;
                if (iPixel == 0 || (iPixel % 2)) { // odd line pixel
                    y = CGFloatPixelHalf(position.y);
                } else {
                    y = CGFloatPixelFloor(position.y);
                }
            } else {
                y = position.y;
            }
            
            CGContextSetStrokeColorWithColor(context, color);
            YYTextSetLinePatternInContext(style, lineWidth, position.x, context);
            CGContextSetLineWidth(context, w);
            if (styleBase == YYTextLineStyleSingle) {
                CGContextMoveToPoint(context, x1, y);
                CGContextAddLineToPoint(context, x2, y);
                CGContextStrokePath(context);
            } else if (styleBase == YYTextLineStyleThick) {
                CGContextMoveToPoint(context, x1, y);
                CGContextAddLineToPoint(context, x2, y);
                CGContextStrokePath(context);
            } else if (styleBase == YYTextLineStyleDouble) {
                CGContextMoveToPoint(context, x1, y - w);
                CGContextAddLineToPoint(context, x2, y - w);
                CGContextStrokePath(context);
                CGContextMoveToPoint(context, x1, y + w);
                CGContextAddLineToPoint(context, x2, y + w);
                CGContextStrokePath(context);
            }
        }
    } CGContextRestoreGState(context);
}

void YYTextDrawText(YYTextLayout *layout, CGContextRef context, CGSize size, CGPoint point, BOOL (^cancel)(void)) {
    CGContextSaveGState(context); {
        
        CGContextTranslateCTM(context, point.x, point.y);
        CGContextTranslateCTM(context, 0, size.height); // 这两步, 是 iOS 和 macOS 的之间的切换
        CGContextScaleCTM(context, 1, -1);
        
        BOOL isVertical = layout.container.verticalForm;
        CGFloat verticalOffset = isVertical ? (size.width - layout.container.size.width) : 0;
        
        NSArray *lines = layout.lines;
        for (NSUInteger l = 0, lMax = lines.count; l < lMax; l++) {
            YYTextLine *line = lines[l];
            if (layout.truncatedLine && layout.truncatedLine.index == line.index) line = layout.truncatedLine;
            NSArray *lineRunRanges = line.verticalRotateRange;
            CGFloat posX = line.position.x + verticalOffset;
            CGFloat posY = size.height - line.position.y;
            CFArrayRef runs = CTLineGetGlyphRuns(line.CTLine);
            for (NSUInteger r = 0, rMax = CFArrayGetCount(runs); r < rMax; r++) {
                CTRunRef run = CFArrayGetValueAtIndex(runs, r);
                CGContextSetTextMatrix(context, CGAffineTransformIdentity);
                CGContextSetTextPosition(context, posX, posY);
                YYTextDrawRun(line, run, context, size, isVertical, lineRunRanges[r], verticalOffset);
            }
            if (cancel && cancel()) break;
        }
        
    } CGContextRestoreGState(context);
}

// 绘制边框.
void YYTextDrawBlockBorder(YYTextLayout *layout, CGContextRef context, CGSize size, CGPoint point, BOOL (^cancel)(void)) {
    CGContextSaveGState(context);
    
    CGContextTranslateCTM(context, point.x, point.y);
    BOOL isVertical = layout.container.verticalForm;
    CGFloat verticalOffset = isVertical ? (size.width - layout.container.size.width) : 0;
    
    NSArray *lines = layout.lines; // 还是绕不开要去看 textLayout 的源码.
    for (NSInteger l = 0, lMax = lines.count; l < lMax; l++) {
        if (cancel && cancel()) break;
        
        YYTextLine *line = lines[l];
        if (layout.truncatedLine && layout.truncatedLine.index == line.index) line = layout.truncatedLine;
        CFArrayRef runs = CTLineGetGlyphRuns(line.CTLine);
        for (NSInteger r = 0, rMax = CFArrayGetCount(runs); r < rMax; r++) {
            CTRunRef run = CFArrayGetValueAtIndex(runs, r);
            CFIndex glyphCount = CTRunGetGlyphCount(run);
            if (glyphCount == 0) continue;
            NSDictionary *attrs = (id)CTRunGetAttributes(run);
            YYTextBorder *border = attrs[YYTextBlockBorderAttributeName];
            if (!border) continue;
            
            NSUInteger lineStartIndex = line.index;
            while (lineStartIndex > 0) {
                if (((YYTextLine *)lines[lineStartIndex - 1]).row == line.row) lineStartIndex--;
                else break;
            }
            
            CGRect unionRect = CGRectZero;
            NSUInteger lineStartRow = ((YYTextLine *)lines[lineStartIndex]).row;
            NSUInteger lineContinueIndex = lineStartIndex;
            NSUInteger lineContinueRow = lineStartRow;
            do {
                YYTextLine *one = lines[lineContinueIndex];
                if (lineContinueIndex == lineStartIndex) {
                    unionRect = one.bounds;
                } else {
                    unionRect = CGRectUnion(unionRect, one.bounds);
                }
                if (lineContinueIndex + 1 == lMax) break;
                YYTextLine *next = lines[lineContinueIndex + 1];
                if (next.row != lineContinueRow) {
                    YYTextBorder *nextBorder = [layout.text attribute:YYTextBlockBorderAttributeName atIndex:next.range.location];
                    if ([nextBorder isEqual:border]) {
                        lineContinueRow++;
                    } else {
                        break;
                    }
                }
                lineContinueIndex++;
            } while (true);
            
            if (isVertical) {
                UIEdgeInsets insets = layout.container.insets;
                unionRect.origin.y = insets.top;
                unionRect.size.height = layout.container.size.height -insets.top - insets.bottom;
            } else {
                UIEdgeInsets insets = layout.container.insets;
                unionRect.origin.x = insets.left;
                unionRect.size.width = layout.container.size.width -insets.left - insets.right;
            }
            unionRect.origin.x += verticalOffset;
            YYTextDrawBorderRects(context, size, border, @[[NSValue valueWithCGRect:unionRect]], isVertical);
            
            l = lineContinueIndex;
            break;
        }
    }
    
    
    CGContextRestoreGState(context);
}

void YYTextDrawBorder(YYTextLayout *layout, CGContextRef context, CGSize size, CGPoint point, YYTextBorderType type, BOOL (^cancel)(void)) {
    CGContextSaveGState(context);
    CGContextTranslateCTM(context, point.x, point.y);
    
    BOOL isVertical = layout.container.verticalForm;
    CGFloat verticalOffset = isVertical ? (size.width - layout.container.size.width) : 0;
    
    NSArray *lines = layout.lines;
    NSString *borderKey = (type == YYTextBorderTypeNormal ? YYTextBorderAttributeName : YYTextBackgroundBorderAttributeName);
    
    BOOL needJumpRun = NO;
    NSUInteger jumpRunIndex = 0;
    
    for (NSInteger l = 0, lMax = lines.count; l < lMax; l++) {
        if (cancel && cancel()) break;
        
        YYTextLine *line = lines[l];
        if (layout.truncatedLine && layout.truncatedLine.index == line.index) line = layout.truncatedLine;
        CFArrayRef runs = CTLineGetGlyphRuns(line.CTLine);
        for (NSInteger r = 0, rMax = CFArrayGetCount(runs); r < rMax; r++) {
            if (needJumpRun) {
                needJumpRun = NO;
                r = jumpRunIndex + 1;
                if (r >= rMax) break;
            }
            
            CTRunRef run = CFArrayGetValueAtIndex(runs, r);
            CFIndex glyphCount = CTRunGetGlyphCount(run);
            if (glyphCount == 0) continue;
            
            NSDictionary *attrs = (id)CTRunGetAttributes(run);
            YYTextBorder *border = attrs[borderKey];
            if (!border) continue;
            
            CFRange runRange = CTRunGetStringRange(run);
            if (runRange.location == kCFNotFound || runRange.length == 0) continue;
            if (runRange.location + runRange.length > layout.text.length) continue;
            
            NSMutableArray *runRects = [NSMutableArray new];
            NSInteger endLineIndex = l;
            NSInteger endRunIndex = r;
            BOOL endFound = NO;
            for (NSInteger ll = l; ll < lMax; ll++) {
                if (endFound) break;
                YYTextLine *iLine = lines[ll];
                CFArrayRef iRuns = CTLineGetGlyphRuns(iLine.CTLine);
                
                CGRect extLineRect = CGRectNull;
                for (NSInteger rr = (ll == l) ? r : 0, rrMax = CFArrayGetCount(iRuns); rr < rrMax; rr++) {
                    CTRunRef iRun = CFArrayGetValueAtIndex(iRuns, rr);
                    NSDictionary *iAttrs = (id)CTRunGetAttributes(iRun);
                    YYTextBorder *iBorder = iAttrs[borderKey];
                    if (![border isEqual:iBorder]) {
                        endFound = YES;
                        break;
                    }
                    endLineIndex = ll;
                    endRunIndex = rr;
                    
                    CGPoint iRunPosition = CGPointZero;
                    CTRunGetPositions(iRun, CFRangeMake(0, 1), &iRunPosition);
                    CGFloat ascent, descent;
                    CGFloat iRunWidth = CTRunGetTypographicBounds(iRun, CFRangeMake(0, 0), &ascent, &descent, NULL);
                    
                    if (isVertical) {
                        YY_SWAP(iRunPosition.x, iRunPosition.y);
                        iRunPosition.y += iLine.position.y;
                        CGRect iRect = CGRectMake(verticalOffset + line.position.x - descent, iRunPosition.y, ascent + descent, iRunWidth);
                        if (CGRectIsNull(extLineRect)) {
                            extLineRect = iRect;
                        } else {
                            extLineRect = CGRectUnion(extLineRect, iRect);
                        }
                    } else {
                        iRunPosition.x += iLine.position.x;
                        CGRect iRect = CGRectMake(iRunPosition.x, iLine.position.y - ascent, iRunWidth, ascent + descent);
                        if (CGRectIsNull(extLineRect)) {
                            extLineRect = iRect;
                        } else {
                            extLineRect = CGRectUnion(extLineRect, iRect);
                        }
                    }
                }
                
                if (!CGRectIsNull(extLineRect)) {
                    [runRects addObject:[NSValue valueWithCGRect:extLineRect]];
                }
            }
            
            NSMutableArray *drawRects = [NSMutableArray new];
            CGRect curRect= ((NSValue *)[runRects firstObject]).CGRectValue;
            for (NSInteger re = 0, reMax = runRects.count; re < reMax; re++) {
                CGRect rect = ((NSValue *)runRects[re]).CGRectValue;
                if (isVertical) {
                    if (fabs(rect.origin.x - curRect.origin.x) < 1) {
                        curRect = YYTextMergeRectInSameLine(rect, curRect, isVertical);
                    } else {
                        [drawRects addObject:[NSValue valueWithCGRect:curRect]];
                        curRect = rect;
                    }
                } else {
                    if (fabs(rect.origin.y - curRect.origin.y) < 1) {
                        curRect = YYTextMergeRectInSameLine(rect, curRect, isVertical);
                    } else {
                        [drawRects addObject:[NSValue valueWithCGRect:curRect]];
                        curRect = rect;
                    }
                }
            }
            if (!CGRectEqualToRect(curRect, CGRectZero)) {
                [drawRects addObject:[NSValue valueWithCGRect:curRect]];
            }
            
            YYTextDrawBorderRects(context, size, border, drawRects, isVertical);
            
            if (l == endLineIndex) {
                r = endRunIndex;
            } else {
                l = endLineIndex - 1;
                needJumpRun = YES;
                jumpRunIndex = endRunIndex;
                break;
            }
            
        }
    }
    
    CGContextRestoreGState(context);
}

void YYTextDrawDecoration(YYTextLayout *layout, CGContextRef context, CGSize size, CGPoint point, YYTextDecorationType type, BOOL (^cancel)(void)) {
    NSArray *lines = layout.lines;
    
    CGContextSaveGState(context);
    CGContextTranslateCTM(context, point.x, point.y);
    
    BOOL isVertical = layout.container.verticalForm;
    CGFloat verticalOffset = isVertical ? (size.width - layout.container.size.width) : 0;
    CGContextTranslateCTM(context, verticalOffset, 0);
    
    for (NSUInteger l = 0, lMax = layout.lines.count; l < lMax; l++) {
        if (cancel && cancel()) break;
        
        YYTextLine *line = lines[l];
        if (layout.truncatedLine && layout.truncatedLine.index == line.index) line = layout.truncatedLine;
        CFArrayRef runs = CTLineGetGlyphRuns(line.CTLine);
        for (NSUInteger r = 0, rMax = CFArrayGetCount(runs); r < rMax; r++) {
            CTRunRef run = CFArrayGetValueAtIndex(runs, r);
            CFIndex glyphCount = CTRunGetGlyphCount(run);
            if (glyphCount == 0) continue;
            
            NSDictionary *attrs = (id)CTRunGetAttributes(run);
            YYTextDecoration *underline = attrs[YYTextUnderlineAttributeName];
            YYTextDecoration *strikethrough = attrs[YYTextStrikethroughAttributeName];
            
            BOOL needDrawUnderline = NO, needDrawStrikethrough = NO;
            if ((type & YYTextDecorationTypeUnderline) && underline.style > 0) {
                needDrawUnderline = YES;
            }
            if ((type & YYTextDecorationTypeStrikethrough) && strikethrough.style > 0) {
                needDrawStrikethrough = YES;
            }
            if (!needDrawUnderline && !needDrawStrikethrough) continue;
            
            CFRange runRange = CTRunGetStringRange(run);
            if (runRange.location == kCFNotFound || runRange.length == 0) continue;
            if (runRange.location + runRange.length > layout.text.length) continue;
            NSString *runStr = [layout.text attributedSubstringFromRange:NSMakeRange(runRange.location, runRange.length)].string;
            if (YYTextIsLinebreakString(runStr)) continue; // may need more checks...
            
            CGFloat xHeight, underlinePosition, lineThickness;
            YYTextGetRunsMaxMetric(runs, &xHeight, &underlinePosition, &lineThickness);
            
            CGPoint underlineStart, strikethroughStart;
            CGFloat length;
            
            if (isVertical) {
                underlineStart.x = line.position.x + underlinePosition;
                strikethroughStart.x = line.position.x + xHeight / 2;
                
                CGPoint runPosition = CGPointZero;
                CTRunGetPositions(run, CFRangeMake(0, 1), &runPosition);
                underlineStart.y = strikethroughStart.y = runPosition.x + line.position.y;
                length = CTRunGetTypographicBounds(run, CFRangeMake(0, 0), NULL, NULL, NULL);
                
            } else {
                underlineStart.y = line.position.y - underlinePosition;
                strikethroughStart.y = line.position.y - xHeight / 2;
                
                CGPoint runPosition = CGPointZero;
                CTRunGetPositions(run, CFRangeMake(0, 1), &runPosition);
                underlineStart.x = strikethroughStart.x = runPosition.x + line.position.x;
                length = CTRunGetTypographicBounds(run, CFRangeMake(0, 0), NULL, NULL, NULL);
            }
            
            if (needDrawUnderline) {
                CGColorRef color = underline.color.CGColor;
                if (!color) {
                    color = (__bridge CGColorRef)(attrs[(id)kCTForegroundColorAttributeName]);
                    color = YYTextGetCGColor(color);
                }
                CGFloat thickness = (underline.width != nil) ? underline.width.floatValue : lineThickness;
                YYTextShadow *shadow = underline.shadow;
                while (shadow) {
                    if (!shadow.color) {
                        shadow = shadow.subShadow;
                        continue;
                    }
                    CGFloat offsetAlterX = size.width + 0xFFFF;
                    CGContextSaveGState(context); {
                        CGSize offset = shadow.offset;
                        offset.width -= offsetAlterX;
                        CGContextSaveGState(context); {
                            CGContextSetShadowWithColor(context, offset, shadow.radius, shadow.color.CGColor);
                            CGContextSetBlendMode(context, shadow.blendMode);
                            CGContextTranslateCTM(context, offsetAlterX, 0);
                            YYTextDrawLineStyle(context, length, thickness, underline.style, underlineStart, color, isVertical);
                        } CGContextRestoreGState(context);
                    } CGContextRestoreGState(context);
                    shadow = shadow.subShadow;
                }
                YYTextDrawLineStyle(context, length, thickness, underline.style, underlineStart, color, isVertical);
            }
            
            if (needDrawStrikethrough) {
                CGColorRef color = strikethrough.color.CGColor;
                if (!color) {
                    color = (__bridge CGColorRef)(attrs[(id)kCTForegroundColorAttributeName]);
                    color = YYTextGetCGColor(color);
                }
                CGFloat thickness = (strikethrough.width != nil) ? strikethrough.width.floatValue : lineThickness;
                YYTextShadow *shadow = underline.shadow;
                while (shadow) {
                    if (!shadow.color) {
                        shadow = shadow.subShadow;
                        continue;
                    }
                    CGFloat offsetAlterX = size.width + 0xFFFF;
                    CGContextSaveGState(context); {
                        CGSize offset = shadow.offset;
                        offset.width -= offsetAlterX;
                        CGContextSaveGState(context); {
                            CGContextSetShadowWithColor(context, offset, shadow.radius, shadow.color.CGColor);
                            CGContextSetBlendMode(context, shadow.blendMode);
                            CGContextTranslateCTM(context, offsetAlterX, 0);
                            YYTextDrawLineStyle(context, length, thickness, underline.style, underlineStart, color, isVertical);
                        } CGContextRestoreGState(context);
                    } CGContextRestoreGState(context);
                    shadow = shadow.subShadow;
                }
                YYTextDrawLineStyle(context, length, thickness, strikethrough.style, strikethroughStart, color, isVertical);
            }
        }
    }
    CGContextRestoreGState(context);
}

void YYTextDrawAttachment(YYTextLayout *layout, CGContextRef context, CGSize size, CGPoint point, UIView *targetView, CALayer *targetLayer, BOOL (^cancel)(void)) {
    
    BOOL isVertical = layout.container.verticalForm;
    CGFloat verticalOffset = isVertical ? (size.width - layout.container.size.width) : 0;
    
    for (NSUInteger i = 0, max = layout.attachments.count; i < max; i++) {
        YYTextAttachment *a = layout.attachments[i];
        if (!a.content) continue;
        
        UIImage *image = nil;
        UIView *view = nil;
        CALayer *layer = nil;
        if ([a.content isKindOfClass:[UIImage class]]) {
            image = a.content;
        } else if ([a.content isKindOfClass:[UIView class]]) {
            view = a.content;
        } else if ([a.content isKindOfClass:[CALayer class]]) {
            layer = a.content;
        }
        if (!image && !view && !layer) continue;
        if (image && !context) continue;
        if (view && !targetView) continue;
        if (layer && !targetLayer) continue;
        if (cancel && cancel()) break;
        
        CGSize asize = image ? image.size : view ? view.frame.size : layer.frame.size;
        CGRect rect = ((NSValue *)layout.attachmentRects[i]).CGRectValue;
        if (isVertical) {
            rect = UIEdgeInsetsInsetRect(rect, UIEdgeInsetRotateVertical(a.contentInsets));
        } else {
            rect = UIEdgeInsetsInsetRect(rect, a.contentInsets);
        }
        rect = YYCGRectFitWithContentMode(rect, asize, a.contentMode);
        rect = CGRectPixelRound(rect);
        rect = CGRectStandardize(rect);
        rect.origin.x += point.x + verticalOffset;
        rect.origin.y += point.y;
        if (image) {
            CGImageRef ref = image.CGImage;
            if (ref) {
                CGContextSaveGState(context);
                CGContextTranslateCTM(context, 0, CGRectGetMaxY(rect) + CGRectGetMinY(rect));
                CGContextScaleCTM(context, 1, -1);
                CGContextDrawImage(context, rect, ref);
                CGContextRestoreGState(context);
            }
        } else if (view) {
            view.frame = rect;
            [targetView addSubview:view];
        } else if (layer) {
            layer.frame = rect;
            [targetLayer addSublayer:layer];
        }
    }
}

void YYTextDrawShadow(YYTextLayout *layout, CGContextRef context, CGSize size, CGPoint point, BOOL (^cancel)(void)) {
    //move out of context. (0xFFFF is just a random large number)
    CGFloat offsetAlterX = size.width + 0xFFFF;
    
    BOOL isVertical = layout.container.verticalForm;
    CGFloat verticalOffset = isVertical ? (size.width - layout.container.size.width) : 0;
    
    CGContextSaveGState(context); {
        CGContextTranslateCTM(context, point.x, point.y);
        CGContextTranslateCTM(context, 0, size.height);
        CGContextScaleCTM(context, 1, -1);
        NSArray *lines = layout.lines;
        for (NSUInteger l = 0, lMax = layout.lines.count; l < lMax; l++) {
            if (cancel && cancel()) break;
            YYTextLine *line = lines[l];
            if (layout.truncatedLine && layout.truncatedLine.index == line.index) line = layout.truncatedLine;
            NSArray *lineRunRanges = line.verticalRotateRange;
            CGFloat linePosX = line.position.x;
            CGFloat linePosY = size.height - line.position.y;
            CFArrayRef runs = CTLineGetGlyphRuns(line.CTLine);
            for (NSUInteger r = 0, rMax = CFArrayGetCount(runs); r < rMax; r++) {
                CTRunRef run = CFArrayGetValueAtIndex(runs, r);
                CGContextSetTextMatrix(context, CGAffineTransformIdentity);
                CGContextSetTextPosition(context, linePosX, linePosY);
                NSDictionary *attrs = (id)CTRunGetAttributes(run);
                YYTextShadow *shadow = attrs[YYTextShadowAttributeName];
                YYTextShadow *nsShadow = [YYTextShadow shadowWithNSShadow:attrs[NSShadowAttributeName]]; // NSShadow compatible
                if (nsShadow) {
                    nsShadow.subShadow = shadow;
                    shadow = nsShadow;
                }
                while (shadow) {
                    if (!shadow.color) {
                        shadow = shadow.subShadow;
                        continue;
                    }
                    CGSize offset = shadow.offset;
                    offset.width -= offsetAlterX;
                    CGContextSaveGState(context); {
                        CGContextSetShadowWithColor(context, offset, shadow.radius, shadow.color.CGColor);
                        CGContextSetBlendMode(context, shadow.blendMode);
                        CGContextTranslateCTM(context, offsetAlterX, 0);
                        YYTextDrawRun(line, run, context, size, isVertical, lineRunRanges[r], verticalOffset);
                    } CGContextRestoreGState(context);
                    shadow = shadow.subShadow;
                }
            }
        }
    } CGContextRestoreGState(context);
}

void YYTextDrawInnerShadow(YYTextLayout *layout, CGContextRef context, CGSize size, CGPoint point, BOOL (^cancel)(void)) {
    CGContextSaveGState(context);
    CGContextTranslateCTM(context, point.x, point.y);
    CGContextTranslateCTM(context, 0, size.height);
    CGContextScaleCTM(context, 1, -1);
    CGContextSetTextMatrix(context, CGAffineTransformIdentity);
    
    BOOL isVertical = layout.container.verticalForm;
    CGFloat verticalOffset = isVertical ? (size.width - layout.container.size.width) : 0;
    
    NSArray *lines = layout.lines;
    for (NSUInteger l = 0, lMax = lines.count; l < lMax; l++) {
        if (cancel && cancel()) break;
        
        YYTextLine *line = lines[l];
        if (layout.truncatedLine && layout.truncatedLine.index == line.index) line = layout.truncatedLine;
        NSArray *lineRunRanges = line.verticalRotateRange;
        CGFloat linePosX = line.position.x;
        CGFloat linePosY = size.height - line.position.y;
        CFArrayRef runs = CTLineGetGlyphRuns(line.CTLine);
        for (NSUInteger r = 0, rMax = CFArrayGetCount(runs); r < rMax; r++) {
            CTRunRef run = CFArrayGetValueAtIndex(runs, r);
            if (CTRunGetGlyphCount(run) == 0) continue;
            CGContextSetTextMatrix(context, CGAffineTransformIdentity);
            CGContextSetTextPosition(context, linePosX, linePosY);
            NSDictionary *attrs = (id)CTRunGetAttributes(run);
            YYTextShadow *shadow = attrs[YYTextInnerShadowAttributeName];
            while (shadow) {
                if (!shadow.color) {
                    shadow = shadow.subShadow;
                    continue;
                }
                CGPoint runPosition = CGPointZero;
                CTRunGetPositions(run, CFRangeMake(0, 1), &runPosition);
                CGRect runImageBounds = CTRunGetImageBounds(run, context, CFRangeMake(0, 0));
                runImageBounds.origin.x += runPosition.x;
                if (runImageBounds.size.width < 0.1 || runImageBounds.size.height < 0.1) continue;
                
                CFDictionaryRef runAttrs = CTRunGetAttributes(run);
                NSValue *glyphTransformValue = CFDictionaryGetValue(runAttrs, (__bridge const void *)(YYTextGlyphTransformAttributeName));
                if (glyphTransformValue) {
                    runImageBounds = CGRectMake(0, 0, size.width, size.height);
                }
                
                // text inner shadow
                CGContextSaveGState(context); {
                    CGContextSetBlendMode(context, shadow.blendMode);
                    CGContextSetShadowWithColor(context, CGSizeZero, 0, NULL);
                    CGContextSetAlpha(context, CGColorGetAlpha(shadow.color.CGColor));
                    CGContextClipToRect(context, runImageBounds);
                    CGContextBeginTransparencyLayer(context, NULL); {
                        UIColor *opaqueShadowColor = [shadow.color colorWithAlphaComponent:1];
                        CGContextSetShadowWithColor(context, shadow.offset, shadow.radius, opaqueShadowColor.CGColor);
                        CGContextSetFillColorWithColor(context, opaqueShadowColor.CGColor);
                        CGContextSetBlendMode(context, kCGBlendModeSourceOut);
                        CGContextBeginTransparencyLayer(context, NULL); {
                            CGContextFillRect(context, runImageBounds);
                            CGContextSetBlendMode(context, kCGBlendModeDestinationIn);
                            CGContextBeginTransparencyLayer(context, NULL); {
                                YYTextDrawRun(line, run, context, size, isVertical, lineRunRanges[r], verticalOffset);
                            } CGContextEndTransparencyLayer(context);
                        } CGContextEndTransparencyLayer(context);
                    } CGContextEndTransparencyLayer(context);
                } CGContextRestoreGState(context);
                shadow = shadow.subShadow;
            }
        }
    }
    
    CGContextRestoreGState(context);
}

void YYTextDrawDebug(YYTextLayout *layout, CGContextRef context, CGSize size, CGPoint point, YYTextDebugOption *op) {
    UIGraphicsPushContext(context);
    CGContextSaveGState(context);
    CGContextTranslateCTM(context, point.x, point.y);
    CGContextSetLineWidth(context, 1.0 / YYScreenScale());
    CGContextSetLineDash(context, 0, NULL, 0);
    CGContextSetLineJoin(context, kCGLineJoinMiter);
    CGContextSetLineCap(context, kCGLineCapButt);
    
    BOOL isVertical = layout.container.verticalForm;
    CGFloat verticalOffset = isVertical ? (size.width - layout.container.size.width) : 0;
    CGContextTranslateCTM(context, verticalOffset, 0);
    
    if (op.CTFrameBorderColor || op.CTFrameFillColor) {
        UIBezierPath *path = layout.container.path;
        if (!path) {
            CGRect rect = (CGRect){CGPointZero, layout.container.size};
            rect = UIEdgeInsetsInsetRect(rect, layout.container.insets);
            if (op.CTFrameBorderColor) rect = CGRectPixelHalf(rect);
            else rect = CGRectPixelRound(rect);
            path = [UIBezierPath bezierPathWithRect:rect];
        }
        [path closePath];
        
        for (UIBezierPath *ex in layout.container.exclusionPaths) {
            [path appendPath:ex];
        }
        if (op.CTFrameFillColor) {
            [op.CTFrameFillColor setFill];
            if (layout.container.pathLineWidth > 0) {
                CGContextSaveGState(context); {
                    CGContextBeginTransparencyLayer(context, NULL); {
                        CGContextAddPath(context, path.CGPath);
                        if (layout.container.pathFillEvenOdd) {
                            CGContextEOFillPath(context);
                        } else {
                            CGContextFillPath(context);
                        }
                        CGContextSetBlendMode(context, kCGBlendModeDestinationOut);
                        [[UIColor blackColor] setFill];
                        CGPathRef cgPath = CGPathCreateCopyByStrokingPath(path.CGPath, NULL, layout.container.pathLineWidth, kCGLineCapButt, kCGLineJoinMiter, 0);
                        if (cgPath) {
                            CGContextAddPath(context, cgPath);
                            CGContextFillPath(context);
                        }
                        CGPathRelease(cgPath);
                    } CGContextEndTransparencyLayer(context);
                } CGContextRestoreGState(context);
            } else {
                CGContextAddPath(context, path.CGPath);
                if (layout.container.pathFillEvenOdd) {
                    CGContextEOFillPath(context);
                } else {
                    CGContextFillPath(context);
                }
            }
        }
        if (op.CTFrameBorderColor) {
            CGContextSaveGState(context); {
                if (layout.container.pathLineWidth > 0) {
                    CGContextSetLineWidth(context, layout.container.pathLineWidth);
                }
                [op.CTFrameBorderColor setStroke];
                CGContextAddPath(context, path.CGPath);
                CGContextStrokePath(context);
            } CGContextRestoreGState(context);
        }
    }
    
    NSArray *lines = layout.lines;
    for (NSUInteger l = 0, lMax = lines.count; l < lMax; l++) {
        YYTextLine *line = lines[l];
        if (layout.truncatedLine && layout.truncatedLine.index == line.index) line = layout.truncatedLine;
        CGRect lineBounds = line.bounds;
        if (op.CTLineFillColor) {
            [op.CTLineFillColor setFill];
            CGContextAddRect(context, CGRectPixelRound(lineBounds));
            CGContextFillPath(context);
        }
        if (op.CTLineBorderColor) {
            [op.CTLineBorderColor setStroke];
            CGContextAddRect(context, CGRectPixelHalf(lineBounds));
            CGContextStrokePath(context);
        }
        if (op.baselineColor) {
            [op.baselineColor setStroke];
            if (isVertical) {
                CGFloat x = CGFloatPixelHalf(line.position.x);
                CGFloat y1 = CGFloatPixelHalf(line.top);
                CGFloat y2 = CGFloatPixelHalf(line.bottom);
                CGContextMoveToPoint(context, x, y1);
                CGContextAddLineToPoint(context, x, y2);
                CGContextStrokePath(context);
            } else {
                CGFloat x1 = CGFloatPixelHalf(lineBounds.origin.x);
                CGFloat x2 = CGFloatPixelHalf(lineBounds.origin.x + lineBounds.size.width);
                CGFloat y = CGFloatPixelHalf(line.position.y);
                CGContextMoveToPoint(context, x1, y);
                CGContextAddLineToPoint(context, x2, y);
                CGContextStrokePath(context);
            }
        }
        if (op.CTLineNumberColor) {
            [op.CTLineNumberColor set];
            NSMutableAttributedString *num = [[NSMutableAttributedString alloc] initWithString:@(l).description];
            num.color = op.CTLineNumberColor;
            num.font = [UIFont systemFontOfSize:6];
            [num drawAtPoint:CGPointMake(line.position.x, line.position.y - (isVertical ? 1 : 6))];
        }
        if (op.CTRunFillColor || op.CTRunBorderColor || op.CTRunNumberColor || op.CGGlyphFillColor || op.CGGlyphBorderColor) {
            CFArrayRef runs = CTLineGetGlyphRuns(line.CTLine);
            for (NSUInteger r = 0, rMax = CFArrayGetCount(runs); r < rMax; r++) {
                CTRunRef run = CFArrayGetValueAtIndex(runs, r);
                CFIndex glyphCount = CTRunGetGlyphCount(run);
                if (glyphCount == 0) continue;
                
                CGPoint glyphPositions[glyphCount];
                CTRunGetPositions(run, CFRangeMake(0, glyphCount), glyphPositions);
                
                CGSize glyphAdvances[glyphCount];
                CTRunGetAdvances(run, CFRangeMake(0, glyphCount), glyphAdvances);
                
                CGPoint runPosition = glyphPositions[0];
                if (isVertical) {
                    YY_SWAP(runPosition.x, runPosition.y);
                    runPosition.x = line.position.x;
                    runPosition.y += line.position.y;
                } else {
                    runPosition.x += line.position.x;
                    runPosition.y = line.position.y - runPosition.y;
                }
                
                CGFloat ascent, descent, leading;
                CGFloat width = CTRunGetTypographicBounds(run, CFRangeMake(0, 0), &ascent, &descent, &leading);
                CGRect runTypoBounds;
                if (isVertical) {
                    runTypoBounds = CGRectMake(runPosition.x - descent, runPosition.y, ascent + descent, width);
                } else {
                    runTypoBounds = CGRectMake(runPosition.x, line.position.y - ascent, width, ascent + descent);
                }
                
                if (op.CTRunFillColor) {
                    [op.CTRunFillColor setFill];
                    CGContextAddRect(context, CGRectPixelRound(runTypoBounds));
                    CGContextFillPath(context);
                }
                if (op.CTRunBorderColor) {
                    [op.CTRunBorderColor setStroke];
                    CGContextAddRect(context, CGRectPixelHalf(runTypoBounds));
                    CGContextStrokePath(context);
                }
                if (op.CTRunNumberColor) {
                    [op.CTRunNumberColor set];
                    NSMutableAttributedString *num = [[NSMutableAttributedString alloc] initWithString:@(r).description];
                    num.color = op.CTRunNumberColor;
                    num.font = [UIFont systemFontOfSize:6];
                    [num drawAtPoint:CGPointMake(runTypoBounds.origin.x, runTypoBounds.origin.y - 1)];
                }
                if (op.CGGlyphBorderColor || op.CGGlyphFillColor) {
                    for (NSUInteger g = 0; g < glyphCount; g++) {
                        CGPoint pos = glyphPositions[g];
                        CGSize adv = glyphAdvances[g];
                        CGRect rect;
                        if (isVertical) {
                            YY_SWAP(pos.x, pos.y);
                            pos.x = runPosition.x;
                            pos.y += line.position.y;
                            rect = CGRectMake(pos.x - descent, pos.y, runTypoBounds.size.width, adv.width);
                        } else {
                            pos.x += line.position.x;
                            pos.y = runPosition.y;
                            rect = CGRectMake(pos.x, pos.y - ascent, adv.width, runTypoBounds.size.height);
                        }
                        if (op.CGGlyphFillColor) {
                            [op.CGGlyphFillColor setFill];
                            CGContextAddRect(context, CGRectPixelRound(rect));
                            CGContextFillPath(context);
                        }
                        if (op.CGGlyphBorderColor) {
                            [op.CGGlyphBorderColor setStroke];
                            CGContextAddRect(context, CGRectPixelHalf(rect));
                            CGContextStrokePath(context);
                        }
                    }
                }
            }
        }
    }
    CGContextRestoreGState(context);
    UIGraphicsPopContext();
}
