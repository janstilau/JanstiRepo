#import "UIGestureRecognizer.h"

// NOTE: This will only match the scroll gestures on touch input devices. If you also
// need classic wheel mice, you have to use UIScrollWheelGestureRecognizer as well.
// Additional note: This will not register the system's automatically generated
// momentum scroll events - those will come through by way of the classic wheel
// recognizer as well. They are handled differently because OSX sends them outside
// of the gestureBegin/gestureEnded sequence. This turned out to be somewhat handy
// for UIScrollView but it certainly might make using the gesture recognizer in
// a standalone setting somewhat more annoying. We'll have to see how it plays out.

@interface UIPanGestureRecognizer : UIGestureRecognizer
- (CGPoint)translationInView:(UIView *)view;
- (void)setTranslation:(CGPoint)translation inView:(UIView *)view;
- (CGPoint)velocityInView:(UIView *)view;

@property (nonatomic) NSUInteger maximumNumberOfTouches;
@property (nonatomic) NSUInteger minimumNumberOfTouches;
@end
