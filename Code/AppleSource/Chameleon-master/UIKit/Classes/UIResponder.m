#import "UIResponder.h"
#import "UIWindow+UIPrivate.h"
#import "UIInputController.h"

@implementation UIResponder

- (UIResponder *)nextResponder
{
    return nil;
}

- (UIWindow *)_responderWindow
{
    if ([self isKindOfClass:[UIView class]]) {
        return [(UIView *)self window];
    } else {
        return [[self nextResponder] _responderWindow];
    }
}

- (BOOL)isFirstResponder
{
    return ([[self _responderWindow] _firstResponder] == self);
}

- (BOOL)canBecomeFirstResponder
{
    return NO;
}

- (BOOL)becomeFirstResponder
{
    if ([self isFirstResponder]) {
        return YES;
    } else {
        UIWindow *window = [self _responderWindow];
        UIResponder *firstResponder = [window _firstResponder];
        
        if (window && [self canBecomeFirstResponder]) {
            BOOL didResign = NO;
            
            if (firstResponder && [firstResponder canResignFirstResponder]) {
                didResign = [firstResponder resignFirstResponder];
            } else {
                didResign = YES;
            }
            
            if (didResign) {
                [window _setFirstResponder:self];
                
                if ([self conformsToProtocol:@protocol(UIKeyInput)]) {
                    // I have no idea how iOS manages this stuff, but here I'm modeling UIMenuController since it also uses the first
                    // responder to do its work. My thinking is that if there were an on-screen keyboard, something here could detect
                    // if self conforms to UITextInputTraits and UIKeyInput and/or UITextInput and then build/fetch the correct keyboard
                    // and assign that to the inputView property which would seperate the keyboard and inputs themselves from the stuff
                    // that actually displays them on screen. Of course on the Mac we don't need an on-screen keyboard, but there's
                    // possibly an argument to be made for supporting custom inputViews anyway.
                    UIInputController *controller = [UIInputController sharedInputController];
                    controller.inputAccessoryView = self.inputAccessoryView;
                    controller.inputView = self.inputView;
                    controller.keyInputResponder = (UIResponder<UIKeyInput> *)self;
                    [controller setInputVisible:YES animated:YES];
                    
                    // key input won't very well work without this
                    [window makeKeyWindow];
                }
                
                return YES;
            }
        }
        
        return NO;
    }
}

- (BOOL)canResignFirstResponder
{
    return YES;
}

- (BOOL)resignFirstResponder
{
    if ([self isFirstResponder]) {
        [[self _responderWindow] _setFirstResponder:nil];
        [[UIInputController sharedInputController] setInputVisible:NO animated:YES];
    }
    
    return YES;
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender
{
    if ([[self class] instancesRespondToSelector:action]) {
        return YES;
    } else {
        return [[self nextResponder] canPerformAction:action withSender:sender];
    }
}

- (NSArray *)keyCommands
{
    return nil;
}

- (UIView *)inputAccessoryView
{
    return nil;
}

- (UIView *)inputView
{
    return nil;
}

- (NSUndoManager *)undoManager
{
    return [[self nextResponder] undoManager];
}

// curiously, the documentation states that all of the following methods do nothing by default but that
// "immediate UIKit subclasses of UIResponder, particularly UIView, forward the message up the responder chain."
// oddly, though, if I use class_getInstanceMethod() to print the address of the actual C function being used
// by UIView, UIViewController, and UIResponder, they all point to the same function. So.... someone is wrong.
// I'm going to leave it like this for now because this is a lot simpler, IMO, and seems nicely logical.

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [[self nextResponder] touchesBegan:touches withEvent:event];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    [[self nextResponder] touchesMoved:touches withEvent:event];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [[self nextResponder] touchesEnded:touches withEvent:event];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [[self nextResponder] touchesCancelled:touches withEvent:event];
}

- (void)motionBegan:(UIEventSubtype)motion withEvent:(UIEvent *)event
{
    [[self nextResponder] motionBegan:motion withEvent:event];
}

- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event
{
    [[self nextResponder] motionEnded:motion withEvent:event];
}

- (void)motionCancelled:(UIEventSubtype)motion withEvent:(UIEvent *)event
{
    [[self nextResponder] motionCancelled:motion withEvent:event];
}

@end


@implementation UIKeyCommand

+ (UIKeyCommand *)keyCommandWithInput:(NSString *)input modifierFlags:(UIKeyModifierFlags)modifierFlags action:(SEL)action
{
    // TODO
    return nil;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (id)initWithCoder:(NSCoder *)decoder
{
    // note, this requires NSSecureCoding, so you have to do something like this:
    //id obj = [decoder decodeObjectOfClass:[MyClass class] forKey:@"myKey"];
    
    // TODO
    return [self init];
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
    // TODO
}

- (id)copyWithZone:(NSZone *)zone
{
    // this should be okay, because this is an immutable object
    return self;
}

@end

NSString *const UIKeyInputUpArrow = @"UIKeyInputUpArrow";
NSString *const UIKeyInputDownArrow = @"UIKeyInputDownArrow";
NSString *const UIKeyInputLeftArrow = @"UIKeyInputLeftArrow";
NSString *const UIKeyInputRightArrow = @"UIKeyInputRightArrow";
NSString *const UIKeyInputEscape = @"UIKeyInputEscape";
