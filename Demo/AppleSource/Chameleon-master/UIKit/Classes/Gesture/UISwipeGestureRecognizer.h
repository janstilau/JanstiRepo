#import "UIGestureRecognizer.h"

// OSX's native swipe gesture doesn't seem to support the idea of varying numbers of touches involved in
// the gesture, so this will recognize for any OSX swipe regardless of touch count!

typedef NS_OPTIONS(NSUInteger, UISwipeGestureRecognizerDirection) {
    UISwipeGestureRecognizerDirectionRight = 1 << 0,
    UISwipeGestureRecognizerDirectionLeft  = 1 << 1,
    UISwipeGestureRecognizerDirectionUp    = 1 << 2,
    UISwipeGestureRecognizerDirectionDown  = 1 << 3
};

@interface UISwipeGestureRecognizer : UIGestureRecognizer
@property (nonatomic) UISwipeGestureRecognizerDirection direction;
@property (nonatomic) NSUInteger numberOfTouchesRequired;
@end
