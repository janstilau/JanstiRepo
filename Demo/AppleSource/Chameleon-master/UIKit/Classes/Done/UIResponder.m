#import "UIResponder.h"
#import "UIWindow+UIPrivate.h"
#import "UIInputController.h"

@implementation UIResponder

// 默认是返回 nil, 各个子类要根据自己的实现, 返回不同的数据. UIView 返回自己的 superView 或者 UIViewController.
- (UIResponder *)nextResponder
{
    return nil;
}

// _firstResponder 这个概念是和 Window 联系在一起的. 所以, 要首先找到相应的 window 对象.
- (UIWindow *)_responderWindow
{
    if ([self isKindOfClass:[UIView class]]) {
        return [(UIView *)self window];
    } else {
        return [[self nextResponder] _responderWindow];
    }
}

// 判断 window 对象保存的是不是自己.
- (BOOL)isFirstResponder
{
    return ([[self _responderWindow] _firstResponder] == self);
}

// 默认返回 NO, 这个会在下面的 becomeFirstResponder 中调用.
- (BOOL)canBecomeFirstResponder
{
    return NO;
}

- (BOOL)becomeFirstResponder
{
    if ([self isFirstResponder]) {
        return YES;
    }
    
    UIWindow *window = [self _responderWindow];
    UIResponder *firstResponder = [window _firstResponder];
    if (window && [self canBecomeFirstResponder]) { // 只有当前in the active view hierarchy, 并且可以成为第一响应者.
        BOOL didResign = NO;
        // 有了 canResignFirstResponder 的判断, resignFirstResponder 里面就应该可以正常调用, 否则就应该算是逻辑错误了.
        if (firstResponder && [firstResponder canResignFirstResponder]) {
            didResign = [firstResponder resignFirstResponder];
        } else {
            didResign = YES;
        }
        
        if (didResign) { // 只有在当前响应者放弃了响应者权利之后, 才能进行下面的逻辑.
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

// 以下的实现, 都是简简单单的调用下一个响应者对应的方法.
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
