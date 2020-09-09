#import "UIResponder.h"
#import "UIWindow+UIPrivate.h"
#import "UIInputController.h"

@implementation UIResponder

- (UIResponder *)nextResponder
{
    return nil;
}

/*
 isFirstResponder 是和 windown 绑定在一起的.
 在 NSWindown 下, 有着 firstResponder 的概念, 不过 iOS 里面没有了.
 */
- (UIWindow *)_responderWindow
{
    if ([self isKindOfClass:[UIView class]]) {
        return [(UIView *)self window];
    } else {
        return [[self nextResponder] _responderWindow];
    }
}

/*
 直接通过 windown 保存的 _firstResponder 进行的判断.
 */
- (BOOL)isFirstResponder
{
    return ([[self _responderWindow] _firstResponder] == self);
}

/*
 canBecomeFirstResponder 控制的是, becomeFirstResponder 中的流程.
 */
- (BOOL)canBecomeFirstResponder
{
    return NO;
}

/*
 简单来说, 就是将自身, 变为 window 的 _firstResponder.
 还会成为键盘操作的响应者.
 */
- (BOOL)becomeFirstResponder
{
    if ([self isFirstResponder]) {
        return YES;
    }
    /*
     FirstResponder 是一个 Window 的概念. 所以, 首先要找到 Window.
     */
    UIWindow *window = [self _responderWindow];
    UIResponder *firstResponder = [window _firstResponder];
    if (window && [self canBecomeFirstResponder]) { // 只有当前in the active view hierarchy, 并且可以成为第一响应者.
        BOOL didResign = NO;
        
        if (firstResponder && [firstResponder canResignFirstResponder]) {
            didResign = [firstResponder resignFirstResponder];
        } else {
            didResign = YES;
        }
        // 只有在当前响应者放弃了响应者权利之后, 才能进行下面的逻辑.
        if (didResign) {
            [window _setFirstResponder:self]; // 一个简单的赋值操作.
            if ([self conformsToProtocol:@protocol(UIKeyInput)]) {
                // 这里应该是为了可以让键盘弹出的操作.
                UIInputController *controller = [UIInputController sharedInputController];
                controller.inputAccessoryView = self.inputAccessoryView;
                controller.inputView = self.inputView;
                controller.keyInputResponder = (UIResponder<UIKeyInput> *)self;
                [controller setInputVisible:YES animated:YES];
                [window makeKeyWindow];
            }
            return YES;
        }
    }
    
    return NO;
}

/*

 UITextView 的代理方法里面, 有着对于 canResignFirstResponder 的描述.
 
 Asks the delegate if editing should stop in the specified text view.
 Declaration

 - (BOOL)textViewShouldEndEditing:(UITextView *)textView;
 Discussion

 This method is called when the text view is asked to resign the first responder status. This might occur when the user tries to change the editing focus to another control. Before the focus actually changes, however, the text view calls this method to give your delegate a chance to decide whether it should.
 Normally, you would return YES from this method to allow the text view to resign the first responder status. You might return NO, however, in cases where your delegate wants to validate the contents of the text view. By returning NO, you could prevent the user from switching to another control until the text view contained a valid value.
 Be aware that this method provides only a recommendation about whether editing should end. Even if you return NO from this method, it is possible that editing might still end. For example, this might happen when the text view is forced to resign the first responder status by being removed from its parent view or window.
 Implementation of this method by the delegate is optional. If it is not present, the first responder status is resigned as if this method had returned YES.
 Parameters

 textView
 The text view for which editing is about to end.
 Returns

 YES if editing should stop; otherwise, NO if the editing session should continue
 */
- (BOOL)canResignFirstResponder
{
    return YES;
}

/*
 将 window 的 firstResponder 设置为 nil.
 */
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

/*
 各种 touch 方法, 默认实现就是向上传递.
 当, 某个 responder 想要中断这个传递过程的时候, 不调用 super 就可以了.
 比如, UIControl 是完全结果了 touch 的过程, 所以它就不会将 touch 的处理逻辑, 再往上进行传递了.
 */
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
