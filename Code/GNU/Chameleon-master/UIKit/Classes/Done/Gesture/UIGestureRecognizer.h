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


/*
 
 如果, 我们自己想要实现 pan, tap 等效果, 其实在 View 里面监听 touchBegin, move 等方法就可以了.
 但是, 如果每个 view 里面都把相关的逻辑写一遍, 会造成大量的代码冗余. 因为实际上, 判断 pan, tap, doubleClick 的逻辑是非常相似的, 仅仅是判断出来的回调不一样.
 UIGestureRecognizer 做的就是把相关的逻辑进行提取的工作.
 view 上面关联了 gesture, 在 UIWindow 进行 sendEvent 的时候, 会先把相关的 event 分发到相关的 view 关联的 gesture 上. 这也就是为什么各个 gesture 会有 delay 的原因.
 gesture 中, 有着 touch begin, end, move 等函数, 在这些函数的内部, 可以追踪值, 进行 gesture 的状态的变化.
 当确定是该 gesture 后, 会触发 gesture 的回调.
 
 A gesture-recognizer object—or, simply, a gesture recognizer—decouples the logic for recognizing a sequence of touches (or other input) and acting on that recognition.
 When one of these objects recognizes a common gesture or, in some cases, a change in the gesture, it sends an action message to each designated target object.
 
 */

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
