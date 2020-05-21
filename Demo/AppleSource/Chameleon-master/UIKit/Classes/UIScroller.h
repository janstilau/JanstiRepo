#import "UIView.h"
#import "UIScrollView.h"

@class UIImageView, UIScroller;

CGFloat UIScrollerWidthForBoundsSize(CGSize boundsSize);

@protocol _UIScrollerDelegate
- (void)_UIScrollerDidBeginDragging:(UIScroller *)scroller withEvent:(UIEvent *)event;
- (void)_UIScroller:(UIScroller *)scroller contentOffsetDidChange:(CGFloat)newOffset;
- (void)_UIScrollerDidEndDragging:(UIScroller *)scroller withEvent:(UIEvent *)event;
@end

// 滑动条. 
@interface UIScroller : UIView

// NOTE: UIScroller set's its own alpha to 0 when it is created, so it is NOT visible by default!
// the flash/quickFlash methods alter its own alpha in order to fade in/out, etc.

- (void)flash;
- (void)quickFlash;

@property (nonatomic, assign) BOOL alwaysVisible;		// if YES, -flash has no effect on the scroller's alpha, setting YES fades alpha to 1, setting NO fades it out if it was visible
@property (nonatomic, assign) id<_UIScrollerDelegate> delegate;
@property (nonatomic, assign) CGFloat contentSize;		// used to calulate how big the slider knob should be (uses its own frame height/width and compares against this value)
@property (nonatomic, assign) CGFloat contentOffset;	// set this after contentSize is set or else it'll normalize in unexpected ways
@property (nonatomic) UIScrollViewIndicatorStyle indicatorStyle;

@end
