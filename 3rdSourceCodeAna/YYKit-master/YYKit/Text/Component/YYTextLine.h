//
//  YYTextLine.h
//  YYKit <https://github.com/ibireme/YYKit>
//
//  Created by ibireme on 15/3/10.
//  Copyright (c) 2015 ibireme.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import <UIKit/UIKit.h>
#import <CoreText/CoreText.h>

#if __has_include(<YYKit/YYKit.h>)
#import <YYKit/YYTextAttribute.h>
#else
#import "YYTextAttribute.h"
#endif

@class YYTextRunGlyphRange;

NS_ASSUME_NONNULL_BEGIN

/**
 A text line object wrapped `CTLineRef`, see `YYTextLayout` for more.
 
 对于 CTLine 的包装.
 */

@interface YYTextLine : NSObject

+ (instancetype)lineWithCTLine:(CTLineRef)CTLine position:(CGPoint)position vertical:(BOOL)isVertical;

@property (nonatomic) NSUInteger index;     ///< line index
@property (nonatomic) NSUInteger row;       ///< line row
@property (nullable, nonatomic, strong) NSArray<NSArray<YYTextRunGlyphRange *> *> *verticalRotateRange; ///< Run rotate range

@property (nonatomic, readonly) CTLineRef CTLine;   ///< CoreText line
@property (nonatomic, readonly) NSRange range;      ///< string range 这个 CTLine 占据的 string 的 range
@property (nonatomic, readonly) BOOL vertical;      ///< vertical form

@property (nonatomic, readonly) CGRect bounds;      ///< bounds (ascent + descent)
@property (nonatomic, readonly) CGSize size;        ///< bounds.size
@property (nonatomic, readonly) CGFloat width;      ///< bounds.size.width
@property (nonatomic, readonly) CGFloat height;     ///< bounds.size.height
@property (nonatomic, readonly) CGFloat top;        ///< bounds.origin.y
@property (nonatomic, readonly) CGFloat bottom;     ///< bounds.origin.y + bounds.size.height
@property (nonatomic, readonly) CGFloat left;       ///< bounds.origin.x
@property (nonatomic, readonly) CGFloat right;      ///< bounds.origin.x + bounds.size.width

@property (nonatomic)   CGPoint position;   ///< baseline position
@property (nonatomic, readonly) CGFloat ascent;     ///< line ascent
@property (nonatomic, readonly) CGFloat descent;    ///< line descent
@property (nonatomic, readonly) CGFloat leading;    ///< line leading
@property (nonatomic, readonly) CGFloat lineWidth;  ///< line width
@property (nonatomic, readonly) CGFloat trailingWhitespaceWidth;

// 这三个, 代表着图文混排中, 各个元素的信息.
/*
 之所以要把这些东西存起来, 是因为在处理点击事件的时候, 是无法得到各个图文混排的图元素的位置的. CTRunDelegate 只会在绘制的时候被调用, 然后将占位字符绘制到很大的一个区域而已, 但是这个区域到底有多大, 必须在点击事件的时候获取才行.
 所以, 提前存储这些信息, 才能快速的处理点击的逻辑.
 */
@property (nullable, nonatomic, readonly) NSArray<YYTextAttachment *> *attachments; ///< YYTextAttachment
@property (nullable, nonatomic, readonly) NSArray<NSValue *> *attachmentRanges;     ///< NSRange(NSValue)
@property (nullable, nonatomic, readonly) NSArray<NSValue *> *attachmentRects;      ///< CGRect(NSValue)

@end


typedef NS_ENUM(NSUInteger, YYTextRunGlyphDrawMode) {
    /// No rotate.
    YYTextRunGlyphDrawModeHorizontal = 0,
    
    /// Rotate vertical for single glyph.
    YYTextRunGlyphDrawModeVerticalRotate = 1,
    
    /// Rotate vertical for single glyph, and move the glyph to a better position,
    /// such as fullwidth punctuation.
    YYTextRunGlyphDrawModeVerticalRotateMove = 2,
};

/**
 A range in CTRun, used for vertical form.
 */
@interface YYTextRunGlyphRange : NSObject
@property (nonatomic) NSRange glyphRangeInRun;
@property (nonatomic) YYTextRunGlyphDrawMode drawMode;
+ (instancetype)rangeWithRange:(NSRange)range drawMode:(YYTextRunGlyphDrawMode)mode;
@end

NS_ASSUME_NONNULL_END
