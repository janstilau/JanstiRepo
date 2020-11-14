#import "UILabel.h"
#import "UIColor.h"
#import "UIFont.h"
#import "UIGraphics.h"
#import <AppKit/NSApplication.h>

@implementation UILabel

- (id)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame])) {
        self.userInteractionEnabled = NO;
        self.textAlignment = UITextAlignmentLeft;
        self.lineBreakMode = UILineBreakModeTailTruncation;
        self.textColor = [UIColor blackColor];
        self.backgroundColor = [UIColor whiteColor];
        self.enabled = YES;
        self.font = [UIFont systemFontOfSize:17];
        self.numberOfLines = 1;
        self.contentMode = UIViewContentModeLeft;
        self.clipsToBounds = YES;
        self.shadowOffset = CGSizeMake(0,-1);
        self.baselineAdjustment = UIBaselineAdjustmentAlignBaselines;
    }
    return self;
}

- (void)setText:(NSString *)newText
{
    if (_text != newText) {
        _text = [newText copy];
        [self setNeedsDisplay];
    }
}

- (void)setFont:(UIFont *)newFont
{
    assert(newFont != nil);

    if (newFont != _font) {
        _font = newFont;
        [self setNeedsDisplay];
    }
}

- (void)setTextColor:(UIColor *)newColor
{
    if (newColor != _textColor) {
        _textColor = newColor;
        [self setNeedsDisplay];
    }
}

- (void)setShadowColor:(UIColor *)newColor
{
    if (newColor != _shadowColor) {
        _shadowColor = newColor;
        [self setNeedsDisplay];
    }
}

- (void)setShadowOffset:(CGSize)newOffset
{
    if (!CGSizeEqualToSize(newOffset,_shadowOffset)) {
        _shadowOffset = newOffset;
        [self setNeedsDisplay];
    }
}

- (void)setTextAlignment:(UITextAlignment)newAlignment
{
    if (newAlignment != _textAlignment) {
        _textAlignment = newAlignment;
        [self setNeedsDisplay];
    }
}

- (void)setLineBreakMode:(UILineBreakMode)newMode
{
    if (newMode != _lineBreakMode) {
        _lineBreakMode = newMode;
        [self setNeedsDisplay];
    }
}

- (void)setEnabled:(BOOL)newEnabled
{
    if (newEnabled != _enabled) {
        _enabled = newEnabled;
        [self setNeedsDisplay];
    }
}

- (void)setNumberOfLines:(NSInteger)lines
{
    if (lines != _numberOfLines) {
        _numberOfLines = lines;
        [self setNeedsDisplay];
    }
}

// 以上所有的 set 方法, 都是修改了属性之后, 然后设置

- (CGRect)textRectForBounds:(CGRect)bounds limitedToNumberOfLines:(NSInteger)numberOfLines
{
    if ([_text length] > 0) {
        CGSize maxSize = bounds.size;
        if (numberOfLines > 0) {
            maxSize.height = _font.lineHeight * numberOfLines;
        }
        // 最终还是用到了字符串的方法, 而字符串的方法, 是根据 coreText 的方法获取最后的 size 大小.
        CGSize size = [_text sizeWithFont: _font constrainedToSize: maxSize lineBreakMode: _lineBreakMode];
        return (CGRect){bounds.origin, size};
    }
    return (CGRect){bounds.origin, {0, 0}};
}

- (void)drawTextInRect:(CGRect)rect
{
    [_text drawInRect:rect withFont:_font lineBreakMode:_lineBreakMode alignment:_textAlignment];
}

- (void)drawRect:(CGRect)rect
{
    if ([_text length] > 0) {
        CGContextSaveGState(UIGraphicsGetCurrentContext());
        
        const CGRect bounds = self.bounds;
        CGRect drawRect = CGRectZero;
        
        // find out the actual size of the text given the size of our bounds
        CGSize maxSize = bounds.size;
        if (_numberOfLines > 0) {
            maxSize.height = _font.lineHeight * _numberOfLines;
        }
        drawRect.size = [_text sizeWithFont:_font constrainedToSize:maxSize lineBreakMode:_lineBreakMode];

        // now vertically center it
        drawRect.origin.y = roundf((bounds.size.height - drawRect.size.height) / 2.f);
        
        // now position it correctly for the width
        // this might be cheating somehow and not how the real thing does it...
        // I didn't spend a ton of time investigating the sizes that it sends the drawTextInRect: method
        drawRect.origin.x = 0;
        drawRect.size.width = bounds.size.width;
        
        // if there's a shadow, let's set that up
        CGSize offset = _shadowOffset;

        // stupid version compatibilities..
        if (floorf(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_6) {
            offset.height *= -1;
        }
        
        CGContextSetShadowWithColor(UIGraphicsGetCurrentContext(), offset, 0, _shadowColor.CGColor);
        
        // finally, draw the real label
        UIColor *drawColor = (_highlighted && _highlightedTextColor)? _highlightedTextColor : _textColor;
        [drawColor setFill];
        // 先计算出 drawRect 的大小
        [self drawTextInRect:drawRect];
        
        CGContextRestoreGState(UIGraphicsGetCurrentContext());
    }
}

- (void)setFrame:(CGRect)newFrame
{
    const BOOL redisplay = !CGSizeEqualToSize(newFrame.size,self.frame.size);
    [super setFrame:newFrame];
    if (redisplay) {
        [self setNeedsDisplay];
    }
}

- (CGSize)sizeThatFits:(CGSize)size
{
    size = CGSizeMake(((_numberOfLines > 0)? CGFLOAT_MAX : size.width), ((_numberOfLines <= 0)? CGFLOAT_MAX : (_font.lineHeight*_numberOfLines)));
    return [_text sizeWithFont:_font constrainedToSize:size lineBreakMode:_lineBreakMode];
}

- (void)setHighlighted:(BOOL)highlighted
{
    if (highlighted != _highlighted) {
        _highlighted = highlighted;
        [self setNeedsDisplay];
    }
}

@end
