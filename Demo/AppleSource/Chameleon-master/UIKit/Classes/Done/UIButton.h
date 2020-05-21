#import "UIControl.h"

typedef NS_ENUM(NSInteger, UIButtonType) {
    UIButtonTypeCustom = 0,
    UIButtonTypeRoundedRect,
    UIButtonTypeDetailDisclosure,
    UIButtonTypeInfoLight,
    UIButtonTypeInfoDark,
    UIButtonTypeContactAdd,
};

@class UILabel, UIImageView, UIImage;

/**
 * 从这个类的实现来看, UIButton 实际上做的, 不是点击回调这些事情, 而是对于不同状态下的界面的不同展示.
 * 在 Highlight, Selected, Enable 等各个状态下, 一个 Button 应该有不同的展示, 而这种展示, 随着当前状态的不同, 会及时进行更新.
 * UIControl 追踪着 touch 事件, 在这个过程中, 会不断地更改 state, UIControl 默认是调用 setNeedsDisplay 进行重绘. 而 Button 将不同状态的文字, 图片, 背景图显示进行了存储, 在 state 更改之后, 会对这些进行替换, 达到按钮的按压效果.
 */

@interface UIButton : UIControl {
@package
    UIButtonType _buttonType;
}
+ (id)buttonWithType:(UIButtonType)buttonType;

- (void)setTitle:(NSString *)title forState:(UIControlState)state;
- (void)setTitleColor:(UIColor *)color forState:(UIControlState)state;
- (void)setTitleShadowColor:(UIColor *)color forState:(UIControlState)state;
- (void)setBackgroundImage:(UIImage *)image forState:(UIControlState)state;
- (void)setImage:(UIImage *)image forState:(UIControlState)state;

- (NSString *)titleForState:(UIControlState)state;
- (UIColor *)titleColorForState:(UIControlState)state;
- (UIColor *)titleShadowColorForState:(UIControlState)state;
- (UIImage *)backgroundImageForState:(UIControlState)state;
- (UIImage *)imageForState:(UIControlState)state;

- (CGRect)backgroundRectForBounds:(CGRect)bounds;
- (CGRect)contentRectForBounds:(CGRect)bounds;
- (CGRect)titleRectForContentRect:(CGRect)contentRect;
- (CGRect)imageRectForContentRect:(CGRect)contentRect;

@property (nonatomic, readonly) UIButtonType buttonType;

@property (nonatomic,readonly,strong) UILabel *titleLabel;
@property (nonatomic,readonly,strong) UIImageView *imageView;
@property (nonatomic, strong) UIImageView *backgroundImageView;

@property (nonatomic) BOOL reversesTitleShadowWhenHighlighted;
@property (nonatomic) BOOL adjustsImageWhenHighlighted; // 影响到unEnable时候的图片显示
@property (nonatomic) BOOL adjustsImageWhenDisabled; // 影响到高亮时候的图片显示
@property (nonatomic) BOOL showsTouchWhenHighlighted;		// no effect
@property (nonatomic) UIEdgeInsets contentEdgeInsets; // 在最终的 layoutSubviews 的时候起作用
@property (nonatomic) UIEdgeInsets titleEdgeInsets; // 在最终的 layoutSubviews 的时候起作用
@property (nonatomic) UIEdgeInsets imageEdgeInsets; // 在最终的 layoutSubviews 的时候起作用

@property (nonatomic, readonly, strong) NSString *currentTitle;
@property (nonatomic, readonly, strong) UIColor *currentTitleColor;
@property (nonatomic, readonly, strong) UIColor *currentTitleShadowColor;
@property (nonatomic, readonly, strong) UIImage *currentImage;
@property (nonatomic, readonly, strong) UIImage *currentBackgroundImage;
@end
