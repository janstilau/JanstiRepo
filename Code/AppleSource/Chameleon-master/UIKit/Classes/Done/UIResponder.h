#import "UIEvent.h"

/**
 专门做事件处理的类.
 
 Discussion
 Responder objects—that is, instances of UIResponder—constitute the event-handling backbone of a UIKit app. Many key objects are also responders, including the UIApplication object, UIViewController objects, and all UIView objects (which includes UIWindow). As events occur, UIKit dispatches them to your app's responder objects for handling.

 There are several kinds of events, including touch events, motion events, remote-control events, and press events. To handle a specific type of event, a responder must override the corresponding methods. For example, to handle touch events, a responder implements the touchesBegan:withEvent:, touchesMoved:withEvent:, touchesEnded:withEvent:, and touchesCancelled:withEvent: methods. In the case of touches, the responder uses the event information provided by UIKit to track changes to those touches and to update the app's interface appropriately.

 In addition to handling events, UIKit responders also manage the forwarding of unhandled events to other parts of your app. If a given responder does not handle an event, it forwards that event to the next event in the responder chain. UIKit manages the responder chain dynamically, using predefined rules to determine which object should be next to receive an event. For example, a view forwards events to its superview, and the root view of a hierarchy forwards events to its view controller.

 Responders process UIEvent objects but can also accept custom input through an input view. The system's keyboard is the most obvious example of an input view. When the user taps a UITextField and UITextView object onscreen, the view becomes the first responder and displays its input view, which is the system keyboard. Similarly, you can create custom input views and display them when other responders become active. To associate a custom input view with a responder, assign that view to the inputView property of the responder.

 For information about responders and the responder chain, see Event Handling Guide for UIKit Apps.
 */

@interface UIResponder : NSObject
- (UIResponder *)nextResponder;
- (BOOL)isFirstResponder;
- (BOOL)canBecomeFirstResponder;
- (BOOL)becomeFirstResponder;
- (BOOL)canResignFirstResponder;
- (BOOL)resignFirstResponder;

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender;

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event;

- (void)motionBegan:(UIEventSubtype)motion withEvent:(UIEvent *)event;
- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event;
- (void)motionCancelled:(UIEventSubtype)motion withEvent:(UIEvent *)event;

@property (nonatomic, readonly) NSArray *keyCommands;

@property (readonly, strong) UIView *inputAccessoryView;
@property (readonly, strong) UIView *inputView;
@property (readonly) NSUndoManager *undoManager;
@end

typedef NS_OPTIONS(NSInteger, UIKeyModifierFlags) {
    UIKeyModifierAlphaShift     = 1 << 16,  // capslock
    UIKeyModifierShift          = 1 << 17,
    UIKeyModifierControl        = 1 << 18,
    UIKeyModifierAlternate      = 1 << 19,
    UIKeyModifierCommand        = 1 << 20,
    UIKeyModifierNumericPad     = 1 << 21,
};

extern NSString *const UIKeyInputUpArrow;
extern NSString *const UIKeyInputDownArrow;
extern NSString *const UIKeyInputLeftArrow;
extern NSString *const UIKeyInputRightArrow;
extern NSString *const UIKeyInputEscape;

@interface UIKeyCommand : NSObject <NSCopying, NSSecureCoding>
+ (UIKeyCommand *)keyCommandWithInput:(NSString *)input modifierFlags:(UIKeyModifierFlags)modifierFlags action:(SEL)action;
@property (nonatomic,readonly) NSString *input;
@property (nonatomic,readonly) UIKeyModifierFlags modifierFlags;
@end

@interface NSObject (UIResponderStandardEditActions)
- (void)copy:(id)sender;
- (void)cut:(id)sender;
- (void)delete:(id)sender;
- (void)paste:(id)sender;
- (void)select:(id)sender;
- (void)selectAll:(id)sender;

- (void)makeTextWritingDirectionLeftToRight:(id)sender;
- (void)makeTextWritingDirectionRightToLeft:(id)sender;
- (void)toggleBoldface:(id)sender;
- (void)toggleItalics:(id)sender;
- (void)toggleUnderline:(id)sender;

- (void)increaseSize:(id)sender;
- (void)decreaseSize:(id)sender;
@end
