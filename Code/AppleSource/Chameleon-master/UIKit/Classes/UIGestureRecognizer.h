#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, UIGestureRecognizerState) {
    UIGestureRecognizerStatePossible, // 最原始的状态.
    UIGestureRecognizerStateBegan,
    UIGestureRecognizerStateChanged,
    UIGestureRecognizerStateEnded,
    UIGestureRecognizerStateCancelled,
    UIGestureRecognizerStateFailed,
    UIGestureRecognizerStateRecognized = UIGestureRecognizerStateEnded
};

@class UIView, UIGestureRecognizer, UITouch, UIEvent;

@protocol UIGestureRecognizerDelegate <NSObject>
@optional
/**
 When a gesture recognizer attempts to transition from the Possible (NSGestureRecognizerStatePossible) state to a different state, such as NSGestureRecognizerStateBegan, the gesture recognizer calls this method to see if the transition should occur. Returning NO from this delegate method causes the gesture recognizer to transition to the NSGestureRecognizerStateFailed state.
 */
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer;
/**
 Called, for a new touch, before the system calls the touchesBegan:withEvent: method on the gesture recognizer. Return NO to prevent the gesture recognizer from seeing this touch.
 */
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch;
/**
 This method is called when recognition of a gesture by either gestureRecognizer and otherGestureRecognizer would block the other gesture recognizer from recognizing its gesture. Returning YES is guaranteed to allow simultaneous recognition; returning NO is not guaranteed to prevent simultaneous recognition because the other gesture recognizer’s delegate may return YES.
 */
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer;
@end

@interface UIGestureRecognizer : NSObject
- (id)initWithTarget:(id)target action:(SEL)action;

- (void)addTarget:(id)target action:(SEL)action;
- (void)removeTarget:(id)target action:(SEL)action;

/**
 Creates a dependency relationship between the receiver and another gesture recognizer when the objects are created.
 */
- (void)requireGestureRecognizerToFail:(UIGestureRecognizer *)otherGestureRecognizer;
- (CGPoint)locationInView:(UIView *)view;

- (NSUInteger)numberOfTouches;

@property (nonatomic, assign) id<UIGestureRecognizerDelegate> delegate;
@property (nonatomic) BOOL delaysTouchesBegan;
@property (nonatomic) BOOL delaysTouchesEnded;
@property (nonatomic) BOOL cancelsTouchesInView;
@property (nonatomic, getter=isEnabled) BOOL enabled;
@property (nonatomic, readonly) UIGestureRecognizerState state;
@property (nonatomic, readonly) UIView *view;
@end
