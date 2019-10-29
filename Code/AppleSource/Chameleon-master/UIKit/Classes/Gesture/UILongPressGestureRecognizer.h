#import "UIGestureRecognizer.h"


@interface UILongPressGestureRecognizer : UIGestureRecognizer
@property (nonatomic) CFTimeInterval minimumPressDuration;
@property (nonatomic) CGFloat allowableMovement;
@property (nonatomic) NSUInteger numberOfTapsRequired;
@property (nonatomic) NSInteger numberOfTouchesRequired;
@end
