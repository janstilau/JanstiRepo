#import "UIControl.h"

@class UIImageView, UIImage;

/*
 作者没有实现这个类. 猜测是监听 touch 的事件, 然后不断的更改自己的 progress 状态, 然后不断的刷新. 并且 send 特定的事件出去.
 */

@interface UISlider : UIControl
- (UIImage *)minimumTrackImageForState:(UIControlState)state;
- (void)setMinimumTrackImage:(UIImage *)image forState:(UIControlState)state;
- (UIImage *)maximumTrackImageForState:(UIControlState)state;
- (void)setMaximumTrackImage:(UIImage *)image forState:(UIControlState)state;
- (UIImage *)thumbImageForState:(UIControlState)state;
- (void)setThumbImage:(UIImage *)image forState:(UIControlState)state;

@property (nonatomic) float value;
@property (nonatomic) float minimumValue;
@property (nonatomic) float maximumValue;

@property (nonatomic, strong) UIImage *minimumValueImage;
@property (nonatomic, strong) UIImage *maximumValueImage;
@property (nonatomic, strong) UIColor *minimumTrackTintColor;
@property (nonatomic, readonly) UIImage *currentMinimumTrackImage;
@property (nonatomic, strong) UIColor *maximumTrackTintColor;
@property (nonatomic, readonly) UIImage *currentMaximumTrackImage;
@property (nonatomic, strong) UIColor *thumbTintColor;
@property (nonatomic, readonly) UIImage *currentThumbImage;
@end
