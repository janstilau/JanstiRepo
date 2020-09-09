#import "UIImageView+UIPrivate.h"
#import "UIImage.h"
#import "UIGraphics.h"
#import "UIColor.h"
#import "UIImageAppKitIntegration.h"
#import "UIWindow.h"
#import "UIImage+UIPrivate.h"
#import "UIScreen.h"
#import <QuartzCore/QuartzCore.h>
#import "UIImageRep.h"

static NSArray *CGImagesWithUIImages(NSArray *images)
{
    NSMutableArray *CGImages = [NSMutableArray arrayWithCapacity:[images count]];
    for (UIImage *img in images) {
        [CGImages addObject:(__bridge id)[img CGImage]];
    }
    return CGImages;
}

@implementation UIImageView {
    _UIImageViewDrawMode _drawMode;
}

+ (BOOL)_instanceImplementsDrawRect
{
    return NO;
}

- (id)initWithFrame:(CGRect)frame
{
    if ((self=[super initWithFrame:frame])) {
        _drawMode = _UIImageViewDrawModeNormal;
        self.userInteractionEnabled = NO; // UIImageView 仅仅作为显示使用, 所以默认情况下, userInteractionEnabled = NO
        self.opaque = NO;
    }
    return self;
}

- (id)initWithImage:(UIImage *)theImage
{
    CGRect frame = CGRectZero;
    
    if (theImage) {
        frame.size = theImage.size; // 默认, 会使用 Image 的 size, 作为self.size
    }
    
    if ((self = [self initWithFrame:frame])) {
        self.image = theImage;
    }
    
    return self;
}

// 重写 sizeThatFits, 根据 Image 的 size 进行调整.
- (CGSize)sizeThatFits:(CGSize)size
{
    return _image? _image.size : CGSizeZero;
}

// 高亮状态改变, 重绘. 之前没有注意过, imageView 也有高亮状态.
- (void)setHighlighted:(BOOL)h
{
    if (h != _highlighted) {
        _highlighted = h;
        [self setNeedsDisplay];
        
        if ([self isAnimating]) {
            [self startAnimating];
        }
    }
}

- (void)setImage:(UIImage *)newImage
{
    if (_image != newImage) {
        _image = newImage;
        if (!_highlighted || !_highlightedImage) {
            [self setNeedsDisplay];
        }
    }
}

- (void)setHighlightedImage:(UIImage *)newImage
{
    if (_highlightedImage != newImage) {
        _highlightedImage = newImage;
        if (_highlighted) {
            [self setNeedsDisplay];
        }
    }
}

- (BOOL)_hasResizableImage
{
    return (_image.topCapHeight > 0 || _image.leftCapWidth > 0);
}

- (void)_setDrawMode:(_UIImageViewDrawMode)drawMode
{
    if (drawMode != _drawMode) {
        _drawMode = drawMode;
        [self setNeedsDisplay];
    }
}


// 核心方法.
- (void)displayLayer:(CALayer *)theLayer
{
    [super displayLayer:theLayer];
    
    // 根据状态的不同, 取不同的 Image 对象.
    UIImage *displayImage = (_highlighted && _highlightedImage)? _highlightedImage : _image;
    const CGFloat scale = self.window.screen.scale;
    const CGRect bounds = self.bounds;
    
    if (displayImage && self._hasResizableImage && bounds.size.width > 0 && bounds.size.height > 0) {
        UIGraphicsBeginImageContextWithOptions(bounds.size, NO, scale);
        [displayImage drawInRect:bounds];
        displayImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }
    
    // 如果需要, 绘制不同的 Image
    if (displayImage && (_drawMode != _UIImageViewDrawModeNormal)) {
        CGRect imageBounds;
        imageBounds.origin = CGPointZero;
        imageBounds.size = displayImage.size;
        
        UIGraphicsBeginImageContextWithOptions(imageBounds.size, NO, scale);
        
        CGBlendMode blendMode = kCGBlendModeNormal;
        CGFloat alpha = 1;
        
        if (_drawMode == _UIImageViewDrawModeDisabled) {
            alpha = 0.5;
        } else if (_drawMode == _UIImageViewDrawModeHighlighted) {
            [[[UIColor blackColor] colorWithAlphaComponent:0.4] setFill];
            UIRectFill(imageBounds);
            blendMode = kCGBlendModeDestinationAtop;
        }
        
        [displayImage drawInRect:imageBounds blendMode:blendMode alpha:alpha];
        displayImage = UIGraphicsGetImageFromCurrentImageContext();
        
        UIGraphicsEndImageContext();
    }
    
    UIImageRep *bestRepresentation = [displayImage _bestRepresentationForProposedScale:scale];
    theLayer.contents = (__bridge id)bestRepresentation.CGImage;
    
    if ([theLayer respondsToSelector:@selector(setContentsScale:)]) {
        [theLayer setContentsScale:bestRepresentation.scale];
    }
}

// 如果, size 更改了, 那么就进行刷新操作.
- (void)_displayIfNeededChangingFromOldSize:(CGSize)oldSize toNewSize:(CGSize)newSize
{
    if (!CGSizeEqualToSize(newSize,oldSize) && self._hasResizableImage) {
        [self setNeedsDisplay];
    }
}

- (void)setFrame:(CGRect)newFrame
{
    [self _displayIfNeededChangingFromOldSize:self.frame.size toNewSize:newFrame.size];
    [super setFrame:newFrame];
}

- (void)setBounds:(CGRect)newBounds
{
    [self _displayIfNeededChangingFromOldSize:self.bounds.size toNewSize:newBounds.size];
    [super setBounds:newBounds];
}


// 仅仅是增加了一个 contents 的动画.
- (void)startAnimating
{
    NSArray *images = _highlighted? _highlightedAnimationImages : _animationImages;
    CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:@"contents"];
    animation.calculationMode = kCAAnimationDiscrete;
    animation.duration = self.animationDuration ?: ([images count] * (1/30.0));
    animation.repeatCount = self.animationRepeatCount ?: HUGE_VALF;
    animation.values = CGImagesWithUIImages(images);
    animation.removedOnCompletion = NO;
    animation.fillMode = kCAFillModeBoth;
    [self.layer addAnimation:animation forKey:@"contents"];
}

- (void)stopAnimating
{
    [self.layer removeAnimationForKey:@"contents"];
}

- (BOOL)isAnimating
{
    return ([self.layer animationForKey:@"contents"] != nil);
}

@end
