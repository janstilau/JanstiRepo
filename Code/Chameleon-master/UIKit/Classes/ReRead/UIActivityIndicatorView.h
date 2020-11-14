#import "UIView.h"

typedef NS_ENUM(NSInteger, UIActivityIndicatorViewStyle) {
    UIActivityIndicatorViewStyleWhiteLarge,
    UIActivityIndicatorViewStyleWhite,
    UIActivityIndicatorViewStyleGray,
};

@interface UIActivityIndicatorView : UIView
- (id)initWithActivityIndicatorStyle:(UIActivityIndicatorViewStyle)style;
- (void)startAnimating;
- (void)stopAnimating;
- (BOOL)isAnimating;

@property BOOL hidesWhenStopped;
@property UIActivityIndicatorViewStyle activityIndicatorViewStyle;
@property (readwrite, nonatomic, retain) UIColor *color;
@end
