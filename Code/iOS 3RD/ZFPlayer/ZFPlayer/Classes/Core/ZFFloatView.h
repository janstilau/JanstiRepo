#import <UIKit/UIKit.h>

// 这个 View 所做的, 仅仅是添加一个 PanGesture, 然后这个 PanGesture 会不断的调整自己在 parentView 中的位置.

@interface ZFFloatView : UIView

/// The parent View
@property(nonatomic, weak) UIView *parentView;

/// Safe margins, mainly for those with Navbar and tabbar
@property(nonatomic, assign) UIEdgeInsets safeInsets;

@end
