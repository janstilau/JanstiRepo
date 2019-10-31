#import "UIView.h"
#import "UIInterface.h"

typedef NS_ENUM(NSInteger, UIToolbarPosition) {
    UIToolbarPositionAny = 0,
    UIToolbarPositionBottom = 1,
    UIToolbarPositionTop = 2,
};

@interface UIToolbar : UIView
- (void)setItems:(NSArray *)items animated:(BOOL)animated;

- (UIImage *)backgroundImageForToolbarPosition:(UIToolbarPosition)topOrBottom barMetrics:(UIBarMetrics)barMetrics;
- (void)setBackgroundImage:(UIImage *)backgroundImage forToolbarPosition:(UIToolbarPosition)topOrBottom barMetrics:(UIBarMetrics)barMetrics;

@property (nonatomic) UIBarStyle barStyle;
@property (nonatomic, strong) UIColor *tintColor;
@property (nonatomic, copy) NSArray *items;
@property (nonatomic,assign,getter=isTranslucent) BOOL translucent;
@end
