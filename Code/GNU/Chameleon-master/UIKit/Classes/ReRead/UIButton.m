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
/*
 这种通过专门的字符串 key 值作为状态的提取的方式, 其实并不利于代码的管理.
 专门写出一个数据类来, 能够更快更清晰.
 */

@implementation UIButton {
    /*
     content 是真正的数据的容器, 存储不同状态, 存储不同状态下的图片, 文字信息等等.
     */
    NSMutableDictionary *_content;
    UIImage *_adjustedHighlightImage;
    UIImage *_adjustedDisabledImage;
}

/*
 在这里, buttonType 处理的很简单, 就是不是 custom 的 button, 有着特殊的显示而已.
 */
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
        
        
        
        _adjustsImageWhenHighlighted = YES;
        _adjustsImageWhenDisabled = YES;
        _showsTouchWhenHighlighted = NO;
        
        self.opaque = NO;
        
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.lineBreakMode = UILineBreakModeMiddleTruncation;
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.textAlignment = UITextAlignmentLeft;
        _titleLabel.shadowOffset = CGSizeZero;
        _imageView = [[UIImageView alloc] init];
        _backgroundImageView = [[UIImageView alloc] init];
        
        [self addSubview:_backgroundImageView];
        [self addSubview:_imageView];
        [self addSubview:_titleLabel];
        /*
         UIButton 其实就是一个子 View 的管理类, 这个管理类, 主要用于在不同的状态下, 进行各个子 View 的显示工作.
         */
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

/*
 这里, 命名有些问题
 这里 normal 是一个保底的方法, 如果 state 里面没有对应 type 的内容, 才会到 normal 下读取内容.
 */
- (id)_normalContentForState:(UIControlState)state type:(NSString *)type
{
    return [self _contentForState:state type:type] ?: [self _contentForState:UIControlStateNormal type:type];
}

/*
 所有的 UI 层面的处理, 都是在这个方法里面统一进行处理.
 任何状态的改变, 或者状态下显示内容的改变, 都会触发到这个方法.
 */
- (void)_updateContent
{
    const UIControlState state = self.state;
    
    _titleLabel.text = [self titleForState:state];
    _titleLabel.textColor = [self titleColorForState:state] ?: [self _defaultTitleColor];
    _titleLabel.shadowColor = [self titleShadowColorForState:state] ?: [self _defaultTitleShadowColor];
    
    UIImage *image = [self _contentForState:state type:UIButtonContentTypeImage];
    UIImage *backgroundImage = [self _contentForState:state type:UIButtonContentTypeBackgroundImage];
    
    /*
     _adjustsImageWhenHighlighted
     _adjustsImageWhenDisabled
     这两个值, 之前没有注意到, 不过, 他影响的也就是在不同状态下的图片显示问题. 在这个库里面, 是在 imageView 的层面上,
     在绘制的时候, 进行相应的修改操作.
     */
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

/*
 就是修改相应的 content 字典里面的内容.
 */
- (void)_setContent:(id)value forState:(UIControlState)state type:(NSString *)type
{
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

/*
 所有的操作, 都聚焦到了 (void)_setContent:(id)value forState:(UIControlState)state type:(NSString *)type
 这个方法的内部, 所有的逻辑, 统一到一个方法, 方便维护.
 */
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

/*
 所有的 get 方法, 也都是通过 _content 字典, 进行的维护.
 */
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

/*
 父类暴露给子类的一个自定义 backgroundImageView Frame 的一个切口. bounds 是 Button 的 bounds
 */
- (CGRect)backgroundRectForBounds:(CGRect)bounds
{
    return bounds;
}

/*
 父类暴露给子类的一个自定义内容布局位置的一个切口. bounds 是 Button 的 bounds
*/
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

/*
 UIControlContentAlignment 的值, 目前来看仅仅在 Button 里面用到了.
 */
- (CGRect)_componentRectForSize:(CGSize)size inContentRect:(CGRect)contentRect withState:(UIControlState)state
{
    CGRect rect;
    
    rect.origin = contentRect.origin;
    rect.size = size;
    
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

- (void)layoutSubviews
{
    // 在 layoutSubviews 的时候, 根据 insets 的值, 会调整 label 和 iamgeView 的位置.
    [super layoutSubviews];
    
    const CGRect bounds = self.bounds;
    const CGRect contentRect = [self contentRectForBounds:bounds];
    
    /*
     首先, 根据 _contentEdgeInsets 计算出内容的 frame 信息 contentRect
     然后根据 contentRect 和 _imageEdgeInsets, titleEdgeInsets 计算出, 图片文字的 frame 信息.
     最终, 根据 horizontion, vetical alignment 的信息, 计算出 titleLabel, imageView 的最终的位置信息.
     */
    _backgroundImageView.frame = [self backgroundRectForBounds:bounds];
    _titleLabel.frame = [self titleRectForContentRect:contentRect];
    _imageView.frame = [self imageRectForContentRect:contentRect];
}

/*
 重写了 UIControl 的方法, 使得 UIButton 可以在 state 改变的时候, 进行 UI 层面的变化.
 */
- (void)_stateDidChange
{
    [super _stateDidChange];
    [self _updateContent];
}

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
