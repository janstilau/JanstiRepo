#import "UIControl.h"

@class UIImage;

// Items on a bar behave in a way similar to buttons (instances of UIButton). They have a title, image, action, and target. You can also enable and disable an item on a bar.
// 一个专门的数据类, 被 Bar 用来实例化 Button 的.

@interface UIBarItem : NSObject <UIAppearance>

- (void)setTitleTextAttributes:(NSDictionary *)attributes forState:(UIControlState)state;
- (NSDictionary *)titleTextAttributesForState:(UIControlState)state;

@property (nonatomic, getter=isEnabled) BOOL enabled;
// You can customize the image to represent the item, and the position of the image, using image and imageInsets respectively.
@property (nonatomic, strong) UIImage *image;
@property (nonatomic, assign) UIEdgeInsets imageInsets;

@property (nonatomic, copy) NSString *title;
@property (nonatomic) NSInteger tag;

@end
