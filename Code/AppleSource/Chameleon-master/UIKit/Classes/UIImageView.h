#import "UIView.h"

@class UIImage, CAKeyframeAnimation;


/**
 UIImageView 管理的是显示的 Image 对象, 它的显示是将这个 image 绘制到自己的区域. 此外, 它还管理着动画, 在这里, 动画是根据序列帧的方式实现的.
 */
@interface UIImageView : UIView
- (id)initWithImage:(UIImage *)theImage;
- (void)startAnimating;
- (void)stopAnimating;
- (BOOL)isAnimating;

@property (nonatomic, strong) UIImage *highlightedImage;
@property (nonatomic, getter=isHighlighted) BOOL highlighted;

@property (nonatomic, strong) UIImage *image;
@property (nonatomic, copy) NSArray *animationImages;
@property (nonatomic, copy) NSArray *highlightedAnimationImages;
@property (nonatomic) NSTimeInterval animationDuration;
@property (nonatomic) NSInteger animationRepeatCount;
@end
