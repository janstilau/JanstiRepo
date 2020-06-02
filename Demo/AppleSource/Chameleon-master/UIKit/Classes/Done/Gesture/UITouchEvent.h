#import "UIEvent.h"

@class UITouch;

typedef NS_ENUM(NSInteger, UITouchEventGesture) {
    UITouchEventGestureNone,        // a normal click-drag touch (not a standard OSX gesture)

    // handle standard OSX gestures
    UITouchEventGestureBegin,       // when OSX sends the begin gesture event, but hasn't identified the exact gesture yet
    UITouchEventGesturePinch,
    UITouchEventGestureRotate,
    UITouchEventGesturePan,
    
    // discrete gestures that violate all the rules
    UITouchEventGestureScrollWheel,
    UITouchEventGestureRightClick,
    UITouchEventGestureMouseMove,
    UITouchEventGestureMouseEntered,
    UITouchEventGestureMouseExited,
    UITouchEventGestureSwipe,
};

@interface UITouchEvent : UIEvent
- (id)initWithTouch:(UITouch *)touch;
- (void)endTouchEvent;

@property (nonatomic, readonly, strong) UITouch *touch;
@property (nonatomic, readwrite, assign) UITouchEventGesture touchEventGesture;     // default UITouchEventGestureNone
@property (nonatomic, readonly) BOOL isDiscreteGesture;     // YES for the mouse UITouchEventGesture types

// used for the various OSX gestures
@property (nonatomic, readwrite, assign) CGPoint translation;
@property (nonatomic, readwrite, assign) CGFloat rotation;
@property (nonatomic, readwrite, assign) CGFloat magnification;

@end
