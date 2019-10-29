#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, UITouchPhase) {
    UITouchPhaseBegan,
    UITouchPhaseMoved,
    UITouchPhaseStationary,
    UITouchPhaseEnded,
    UITouchPhaseCancelled,
};

@class UIView, UIWindow;

/**
 You access touch objects through UIEvent objects passed into responder objects for event handling. A touch object includes accessors for:

 The view or window in which the touch occurred

 The location of the touch within the view or window

 The approximate radius of the touch

 The force of the touch (on devices that support 3D Touch or Apple Pencil)

 A touch object also contains a timestamp indicating when the touch occurred, an integer representing the number of times the user tapped the screen, and the phase of the touch in the form of a constant that describes whether the touch began, moved, or ended, or whether the system canceled the touch.

 To learn how to work with swipes, read Handling Swipe and Drag Gestures in Event Handling Guide for UIKit Apps.

 A touch object persists throughout a multi-touch sequence. You may store a reference to a touch while handling a multi-touch sequence, as long as you release that reference when the sequence ends. If you need to store information about a touch outside of a multi-touch sequence, copy that information from the touch.

 The gestureRecognizers property of a touch contains the gesture recognizers currently handling the touch. Each gesture recognizer is an instance of a concrete subclass of UIGestureRecognizer.
 */

@interface UITouch : NSObject
- (CGPoint)locationInView:(UIView *)inView;
- (CGPoint)previousLocationInView:(UIView *)inView;

@property (nonatomic, readonly) NSTimeInterval timestamp;
@property (nonatomic, readonly) NSUInteger tapCount;
@property (nonatomic, readonly) UITouchPhase phase;
@property (nonatomic, readonly, strong) UIView *view;
@property (nonatomic, readonly, strong) UIWindow *window;
@property (nonatomic, readonly, copy) NSArray *gestureRecognizers;
@end
