#import "UIControl.h"

@class UIImage;

@interface UIBarItem : NSObject <UIAppearance>

- (void)setTitleTextAttributes:(NSDictionary *)attributes forState:(UIControlState)state;
- (NSDictionary *)titleTextAttributesForState:(UIControlState)state;

@property (nonatomic, getter=isEnabled) BOOL enabled;
@property (nonatomic, strong) UIImage *image;
@property (nonatomic, assign) UIEdgeInsets imageInsets;
@property (nonatomic, copy) NSString *title;
@property (nonatomic) NSInteger tag;

@end
