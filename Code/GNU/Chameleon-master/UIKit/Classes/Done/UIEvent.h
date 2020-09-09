#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, UIEventType) {
    UIEventTypeTouches,
    UIEventTypeMotion,
    UIEventTypeKeyboard,
    UIEventTypeAction
};

typedef NS_ENUM(NSInteger, UIEventSubtype) {
    UIEventSubtypeNone        = 0,
    UIEventSubtypeMotionShake = 1,
};

@class UIWindow, UIView, UIGestureRecognizer;

/*
 Apps can receive many different types of events, including touch events, motion events, remote-control events, and press events.
 Touch events are the most common and are delivered to the view in which the touch originally occurred.
 Motion events are UIKit triggered and are separate from the motion events reported by the Core Motion framework. Remote-control events allow a responder object to receive commands from an external accessory or headset so that it can manage manage audio and video—for example, playing a video or skipping to the next audio track.
 Press events represent interactions with a game controller, AppleTV remote, or other device that has physical buttons. You can determine the type of an event using the type and subtype properties.

 A touch event object contains the touches (that is, the fingers on the screen) that have some relation to the event.
 A touch event object may contain one or more touches, and each touch is represented by a UITouch object.
 When a touch event occurs, the system routes it to the appropriate responder and calls the appropriate method, such as touchesBegan:withEvent:.
 The responder then uses the touches to determine an appropriate course of action.

 During a multitouch sequence, UIKit reuses the same UIEvent object when delivering updated touch data to your app. You should never retain an event object or any object returned from an event object. If you need to retain data outside of the responder method you use to process that data, copy that data from the UITouch or UIEvent object to your local data structures.
 */

@interface UIEvent : NSObject

- (NSSet *)allTouches;
- (NSSet *)touchesForView:(UIView *)view;
- (NSSet *)touchesForWindow:(UIWindow *)window;
- (NSSet *)touchesForGestureRecognizer:(UIGestureRecognizer *)gesture;

@property (nonatomic, readonly) NSTimeInterval timestamp;
@property (nonatomic, readonly) UIEventType type;
@property (nonatomic, readonly) UIEventSubtype subtype;
@end
