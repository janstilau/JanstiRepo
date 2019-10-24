//
//  CoreTextData.m
//  CoreTextDemo
//
//  Created by TangQiao on 13-12-7.
//  Copyright (c) 2013年 TangQiao. All rights reserved.
//

#import "CoreTextData.h"

@implementation CoreTextData

- (void)setCtFrame:(CTFrameRef)ctFrame {
    if (_ctFrame != ctFrame) {
        if (_ctFrame != nil) {
            CFRelease(_ctFrame);
        }
        CFRetain(ctFrame);
        _ctFrame = ctFrame;
    }
}

- (void)dealloc {
    if (_ctFrame != nil) {
        CFRelease(_ctFrame);
        _ctFrame = nil;
    }
}

- (void)setImageArray:(NSArray *)imageArray {
    _imageArray = imageArray;
    [self fillImagePosition];
}

- (void)fillImagePosition {
    if (self.imageArray.count == 0) {
        return;
    }
    NSArray *lines = (NSArray *)CTFrameGetLines(self.ctFrame);
    NSUInteger lineCount = [lines count];
    CGPoint lineOrigins[lineCount];
    CTFrameGetLineOrigins(self.ctFrame, CFRangeMake(0, 0), lineOrigins); // 获取到每一行的 origin 的位置在哪里.
    
    int imgIndex = 0;
    CoreTextImageData * imageData = self.imageArray[0];
    
    for (int i = 0; i < lineCount; ++i) {
        if (imageData == nil) {
            break;
        }
        CTLineRef line = (__bridge CTLineRef)lines[i]; // 获取到每一行
        NSArray * runObjArray = (NSArray *)CTLineGetGlyphRuns(line);// 获取到每一个 CTRun
        for (id runObj in runObjArray) {
            CTRunRef run = (__bridge CTRunRef)runObj;
            NSDictionary *runAttributes = (NSDictionary *)CTRunGetAttributes(run);
            CTRunDelegateRef delegate = (__bridge CTRunDelegateRef)[runAttributes valueForKey:(id)kCTRunDelegateAttributeName];
            if (delegate == nil) {
                continue;
            }
            // 获取到每一个 CTRun 的 delegate.
            NSDictionary * metaDic = CTRunDelegateGetRefCon(delegate);
            if (![metaDic isKindOfClass:[NSDictionary class]]) {
                continue;
            }
            
            CGRect runBounds; // 这个 CTRun 的宽高信息
            CGFloat ascent;
            CGFloat descent;
            runBounds.size.width = CTRunGetTypographicBounds(run, CFRangeMake(0, 0), &ascent, &descent, NULL);
            runBounds.size.height = ascent + descent;
            
            CGFloat xOffset = CTLineGetOffsetForStringIndex(line, CTRunGetStringRange(run).location, NULL);
            runBounds.origin.x = lineOrigins[i].x + xOffset;
            runBounds.origin.y = lineOrigins[i].y;
            runBounds.origin.y -= descent;
            
            CGPathRef pathRef = CTFrameGetPath(self.ctFrame);
            CGRect colRect = CGPathGetBoundingBox(pathRef);
            
            // 这里的计算过程没有太明白.
            CGRect delegateBounds = CGRectOffset(runBounds, colRect.origin.x, colRect.origin.y);
            
            imageData.imagePosition = delegateBounds;
            imgIndex++;
            if (imgIndex == self.imageArray.count) {
                imageData = nil;
                break;
            } else {
                imageData = self.imageArray[imgIndex];
            }
        }
    }
}


@end
