#import "UIButton.h"
#import "UIControl+UIPrivate.h"
#import "UILabel.h"
#import "UIImage.h"
#import "UIImageView+UIPrivate.h"
#import "UIRoundedRectButton.h"
#import "UIColor.h"

static NSString *UIButtonContentTypeTitle = @"UIButtonContentTypeTitle";
static NSString *UIButtonContentTypeTitleColor = @"UIButtonContentTypeTitleColor";
static NSString *UIButtonContentTypeTitleShadowColor = @"UIButtonContentTypeTitleShadowColor";
static NSString *UIButtonContentTypeBackgroundImage = @"UIButtonContentTypeBackgroundImage";
static NSString *UIButtonContentTypeImage = @"UIButtonContentTypeImage";

@implementation UIButton {
    NSMutableDictionary *_content;
    UIImage *_adjustedHighlightImage;
    UIImage *_adjustedDisabledImage;
}

+ (id)buttonWithType:(UIButtonType)buttonType
{
    switch (buttonType) {
        case UIButtonTypeRoundedRect:
        case UIButtonTypeDetailDisclosure:
        case UIButtonTypeInfoLight:
        case UIButtonTypeInfoDark:
        case UIButtonTypeContactAdd:
            return [[UIRoundedRectButton alloc] init];
            
        case UIButtonTypeCustom:
        default:
            return [[self alloc] init];
    }
}

- (id)initWithFrame:(CGRect)frame
{
    if ((self=[super initWithFrame:frame])) {
        _buttonType = UIButtonTypeCustom; // 默认就是 custom
        _content = [[NSMutableDictionary alloc] init];
        
        _titleLabel = [[UILabel alloc] init];
        _imageView = [[UIImageView alloc] init];
        _backgroundImageView = [[UIImageView alloc] init];
        
        _adjustsImageWhenHighlighted = YES;
        _adjustsImageWhenDisabled = YES;
        _showsTouchWhenHighlighted = NO;
        
        self.opaque = NO;
        _titleLabel.lineBreakMode = UILineBreakModeMiddleTruncation;
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.textAlignment = UITextAlignmentLeft;
        _titleLabel.shadowOffset = CGSizeZero;
        [self addSubview:_backgroundImageView];
        [self addSubview:_imageView];
        [self addSubview:_titleLabel];
    }
    return self;
}


- (NSString *)currentTitle
{
    return _titleLabel.text;
}

- (UIColor *)currentTitleColor
{
    return _titleLabel.textColor;
}

- (UIColor *)currentTitleShadowColor
{
    return _titleLabel.shadowColor;
}

- (UIImage *)currentImage
{
    return _imageView.image;
}

- (UIImage *)currentBackgroundImage
{
    return _backgroundImageView.image;
}

- (UIColor *)_defaultTitleColor
{
    return [UIColor whiteColor];
}

- (UIColor *)_defaultTitleShadowColor
{
    return [UIColor whiteColor];
}

- (id)_contentForState:(UIControlState)state type:(NSString *)type
{
    return [[_content objectForKey:type] objectForKey:[NSNumber numberWithInt:state]];
}

- (id)_normalContentForState:(UIControlState)state type:(NSString *)type
{
    return [self _contentForState:state type:type] ?: [self _contentForState:UIControlStateNormal type:type];
}

// 根据 state 的不同, 取不同的值, 设置 Label 和 ImageView 的值.
- (void)_updateContent
{
    const UIControlState state = self.state;
    _titleLabel.text = [self titleForState:state];
    _titleLabel.textColor = [self titleColorForState:state] ?: [self _defaultTitleColor];
    _titleLabel.shadowColor = [self titleShadowColorForState:state] ?: [self _defaultTitleShadowColor];
    
    UIImage *image = [self _contentForState:state type:UIButtonContentTypeImage];
    UIImage *backgroundImage = [self _contentForState:state type:UIButtonContentTypeBackgroundImage];
    
    // 首先找到相应状态的值, 如果没有该值, 那么选 Normal 状态的值.
    if (!image) {
        image = [self imageForState:state];	// find the correct default image to show
        if (_adjustsImageWhenDisabled && state & UIControlStateDisabled) {
            [_imageView _setDrawMode:_UIImageViewDrawModeDisabled];
        } else if (_adjustsImageWhenHighlighted && state & UIControlStateHighlighted) {
            [_imageView _setDrawMode:_UIImageViewDrawModeHighlighted];
        } else {
            [_imageView _setDrawMode:_UIImageViewDrawModeNormal];
        }
    } else {
        [_imageView _setDrawMode:_UIImageViewDrawModeNormal];
    }
    
    if (!backgroundImage) {
        backgroundImage = [self backgroundImageForState:state];
        if (_adjustsImageWhenDisabled && state & UIControlStateDisabled) {
            [_backgroundImageView _setDrawMode:_UIImageViewDrawModeDisabled];
        } else if (_adjustsImageWhenHighlighted && state & UIControlStateHighlighted) {
            [_backgroundImageView _setDrawMode:_UIImageViewDrawModeHighlighted];
        } else {
            [_backgroundImageView _setDrawMode:_UIImageViewDrawModeNormal];
        }
    } else {
        [_backgroundImageView _setDrawMode:_UIImageViewDrawModeNormal];
    }
    
    _imageView.image = image;
    _backgroundImageView.image = backgroundImage;
    
    [self setNeedsLayout];
}

- (void)_setContent:(id)value forState:(UIControlState)state type:(NSString *)type
{
    // 对于每一种属性, 都是一个 Dict 进行了存储.
    NSMutableDictionary *typeContent = [_content objectForKey:type];
    
    if (!typeContent) {
        typeContent = [[NSMutableDictionary alloc] init];
        [_content setObject:typeContent forKey:type];
    }
    
    NSNumber *key = [NSNumber numberWithInt:state];
    if (value) {
        [typeContent setObject:value forKey:key];
    } else {
        [typeContent removeObjectForKey:key];
    }
    
    [self _updateContent];
}

// 所有的方法, 都聚集到_content的修改.
- (void)setTitle:(NSString *)title forState:(UIControlState)state
{
    [self _setContent:title forState:state type:UIButtonContentTypeTitle];
}

- (void)setTitleColor:(UIColor *)color forState:(UIControlState)state
{
    [self _setContent:color forState:state type:UIButtonContentTypeTitleColor];
}

- (void)setTitleShadowColor:(UIColor *)color forState:(UIControlState)state
{
    [self _setContent:color forState:state type:UIButtonContentTypeTitleShadowColor];
}

- (void)setBackgroundImage:(UIImage *)image forState:(UIControlState)state
{
    [self _setContent:image forState:state type:UIButtonContentTypeBackgroundImage];
}

- (void)setImage:(UIImage *)image forState:(UIControlState)state
{
    _adjustedDisabledImage = _adjustedHighlightImage = nil;
    [self _setContent:image forState:state type:UIButtonContentTypeImage];
}

- (NSString *)titleForState:(UIControlState)state
{
    return [self _normalContentForState:state type:UIButtonContentTypeTitle];
}

- (UIColor *)titleColorForState:(UIControlState)state
{
    return [self _normalContentForState:state type:UIButtonContentTypeTitleColor];
}

- (UIColor *)titleShadowColorForState:(UIControlState)state
{
    return [self _normalContentForState:state type:UIButtonContentTypeTitleShadowColor];
}

- (UIImage *)backgroundImageForState:(UIControlState)state
{
    return [self _normalContentForState:state type:UIButtonContentTypeBackgroundImage];
}

- (UIImage *)imageForState:(UIControlState)state
{
    return [self _normalContentForState:state type:UIButtonContentTypeImage];
}

#pragma mark -

// 一个切口, 可以让外界自定义背景区域, 在 layoutSubViews 中使用.
- (CGRect)backgroundRectForBounds:(CGRect)bounds
{
    return bounds;
}

- (CGRect)contentRectForBounds:(CGRect)bounds
{
    return UIEdgeInsetsInsetRect(bounds,_contentEdgeInsets);
}

- (CGSize)_titleSizeForState:(UIControlState)state
{
    NSString *title = [self titleForState:state];
    CGSize titleSize = [title sizeWithFont:_titleLabel.font constrainedToSize:CGSizeMake(CGFLOAT_MAX,CGFLOAT_MAX)];
    return ([title length] > 0)?  titleSize: CGSizeZero;
}

- (CGSize)_imageSizeForState:(UIControlState)state
{
    UIImage *image = [self imageForState:state];
    return image ? image.size : CGSizeZero;
}

- (CGRect)_componentRectForSize:(CGSize)size inContentRect:(CGRect)contentRect withState:(UIControlState)state
{
    CGRect rect;

    rect.origin = contentRect.origin;
    rect.size = size;
    
    // clamp the right edge of the rect to the contentRect - this is what the real UIButton appears to do.
    if (CGRectGetMaxX(rect) > CGRectGetMaxX(contentRect)) {
        rect.size.width -= CGRectGetMaxX(rect) - CGRectGetMaxX(contentRect);
    }
    
    switch (self.contentHorizontalAlignment) {
        case UIControlContentHorizontalAlignmentCenter:
            rect.origin.x += floorf((contentRect.size.width/2.f) - (rect.size.width/2.f));
            break;
            
        case UIControlContentHorizontalAlignmentRight:
            rect.origin.x += contentRect.size.width - rect.size.width;
            break;
            
        case UIControlContentHorizontalAlignmentFill:
            rect.size.width = contentRect.size.width;
            break;
            
        case UIControlContentHorizontalAlignmentLeft:
            // don't do anything - it's already left aligned
            break;
    }
    
    switch (self.contentVerticalAlignment) {
        case UIControlContentVerticalAlignmentCenter:
            rect.origin.y += floorf((contentRect.size.height/2.f) - (rect.size.height/2.f));
            break;
            
        case UIControlContentVerticalAlignmentBottom:
            rect.origin.y += contentRect.size.height - rect.size.height;
            break;
            
        case UIControlContentVerticalAlignmentFill:
            rect.size.height = contentRect.size.height;
            break;
            
        case UIControlContentVerticalAlignmentTop:
            // don't do anything - it's already top aligned
            break;
    }
    
    return rect;
}

- (CGRect)titleRectForContentRect:(CGRect)contentRect
{
    const UIControlState state = self.state;
    
    UIEdgeInsets inset = _titleEdgeInsets;
    inset.left += [self _imageSizeForState:state].width;
    
    return [self _componentRectForSize:[self _titleSizeForState:state]
                         inContentRect:UIEdgeInsetsInsetRect(contentRect,inset)
                             withState:state];
}

- (CGRect)imageRectForContentRect:(CGRect)contentRect
{
    const UIControlState state = self.state;
    
    UIEdgeInsets inset = _imageEdgeInsets;
    inset.right += [self titleRectForContentRect:contentRect].size.width;
    
    return [self _componentRectForSize:[self _imageSizeForState:state] inContentRect:UIEdgeInsetsInsetRect(contentRect,inset) withState:state];
}

// 在这个方法的内部, 会调整 ImageView, Label, 和 BackGroundImageView 的 frame.
- (void)layoutSubviews
{
    // 在 layoutSubviews 的时候, 根据 insets 的值, 会调整 label 和 iamgeView 的位置.
    [super layoutSubviews];
    
    const CGRect bounds = self.bounds;
    const CGRect contentRect = [self contentRectForBounds:bounds];

    _backgroundImageView.frame = [self backgroundRectForBounds:bounds];
    _titleLabel.frame = [self titleRectForContentRect:contentRect];
    _imageView.frame = [self imageRectForContentRect:contentRect];
}

// 重写 UIControl 的方法, 增加了对于 ImageView, Label, BackgroundImageView 的内容处理.
- (void)_stateDidChange
{
    [super _stateDidChange];
    [self _updateContent];
}

// 参数完全没有用到, 完全靠自己的内容, sizeToFit 会调用到这个方法. 所以, 重写这个方法, 在这个方法里面
- (CGSize)sizeThatFits:(CGSize)targetSize
{
    const UIControlState state = self.state;
    
    const CGSize imageSize = [self _imageSizeForState:state];
    const CGSize titleSize = [self _titleSizeForState:state];
    
    CGSize fitSize;
    fitSize.width = _contentEdgeInsets.left + _contentEdgeInsets.right + titleSize.width + imageSize.width;
    fitSize.height = _contentEdgeInsets.top + _contentEdgeInsets.bottom + MAX(titleSize.height,imageSize.height);
    
    UIImage* background = [self currentBackgroundImage];
    if(background) {
        CGSize backgroundSize = background.size;
        fitSize.width = MAX(fitSize.width, backgroundSize.width);
        fitSize.height = MAX(fitSize.height, backgroundSize.height);
    }
    
    return fitSize;
}

@end
