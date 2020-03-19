#import <UIKit/UIKit.h>

@interface ZFFloatView : UIView

/// The parent View
@property(nonatomic, weak) UIView *parentView;

/// Safe margins, mainly for those with Navbar and tabbar
@property(nonatomic, assign) UIEdgeInsets safeInsets;

@end
