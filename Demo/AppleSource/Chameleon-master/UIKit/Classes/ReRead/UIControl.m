#import "UIControl+UIPrivate.h"
#import "UIEvent.h"
#import "UITouch.h"
#import "UIApplication.h"
#import "UIControlAction.h"

@implementation UIControl {
    NSMutableArray *_registeredActions; // 最核心的数据, UIControl 和 UIView 的不同的根源.
}

- (id)initWithFrame:(CGRect)frame
{
    if ((self=[super initWithFrame:frame])) {
        _registeredActions = [[NSMutableArray alloc] init];
        self.enabled = YES;
        self.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
        self.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    }
    return self;
}

// 和自己的想法不同, 这里是通过组合出一个数据类, 然后将所有的操作, 保存在数据类里面. 合适的数据类, 可以大大的减少逻辑的复杂性.
- (void)addTarget:(id)target action:(SEL)action forControlEvents:(UIControlEvents)controlEvents
{
    UIControlAction *controlAction = [[UIControlAction alloc] init];
    controlAction.target = target;
    controlAction.action = action;
    controlAction.controlEvents = controlEvents;
    [_registeredActions addObject:controlAction];
}

- (void)removeTarget:(id)target action:(SEL)action forControlEvents:(UIControlEvents)controlEvents
{
    NSMutableArray *discard = [[NSMutableArray alloc] init];
    
    for (UIControlAction *controlAction in _registeredActions) {
        if (controlAction.target == target && (action == NULL || controlAction.controlEvents == controlEvents)) {
            [discard addObject:controlAction];
        }
    }
    
    [_registeredActions removeObjectsInArray:discard];
}

- (NSArray *)actionsForTarget:(id)target forControlEvent:(UIControlEvents)controlEvent
{
    NSMutableArray *actions = [[NSMutableArray alloc] init];
    
    for (UIControlAction *controlAction in _registeredActions) {
        if ((target == nil || controlAction.target == target) && (controlAction.controlEvents & controlEvent) ) {
            [actions addObject:NSStringFromSelector(controlAction.action)];
        }
    }
    
    if ([actions count] == 0) {
        return nil;
    } else {
        return actions;
    }
}

- (NSSet *)allTargets
{
    return [NSSet setWithArray:[_registeredActions valueForKey:@"target"]];
}

- (UIControlEvents)allControlEvents
{
    UIControlEvents allEvents = 0;
    
    for (UIControlAction *controlAction in _registeredActions) {
        allEvents |= controlAction.controlEvents;
    }
    
    return allEvents;
}

- (void)_sendActionsForControlEvents:(UIControlEvents)controlEvents withEvent:(UIEvent *)event
{
    for (UIControlAction *controlAction in _registeredActions) {
        if (controlAction.controlEvents & controlEvents) {
            [self sendAction:controlAction.action to:controlAction.target forEvent:event];
        }
    }
}

// 真正的方法实现. 当触发的时候, 会汇集到这个方法, 然后调用相应的回调.
- (void)sendAction:(SEL)action to:(id)target forEvent:(UIEvent *)event
{
    /**
     Normally, this method is invoked by a UIControl object that the user has touched.
     The default implementation dispatches the action method to the given target object or, if no target is specified, to the first responder. Subclasses may override this method to perform special dispatching of action messages.
     
     By default, this method pushes two parameters when calling the target. These last two parameters are optional for the receiver because it is up to the caller (usually a UIControl object) to remove any parameters it added. This design enables the action selector to be one of the following:
     
     - (void)action
     
     - (void)action:(id)sender
     
     - (void)action:(id)sender forEvent:(UIEvent *)even
     */
    
    /*
     If aTarget is nil, sharedApplication looks for an object that can respond to the message—that is, an object that implements a method matching anAction. It begins with the first responder of the key window. If the first responder can’t respond, it tries the first responder’s next responder and continues following next responder links up the responder chain. If none of the objects in the key window’s responder chain can handle the message, sharedApplication attempts to send the message to the key window’s delegate.

     If the delegate doesn’t respond and the main window is different from the key window, sharedApplication begins again with the first responder in the main window. If objects in the main window can’t respond, sharedApplication attempts to send the message to the main window’s delegate. If still no object has responded, sharedApplication tries to handle the message itself. If sharedApplication can’t respond, it attempts to send the message to its own delegate.
     */
    [[UIApplication sharedApplication] sendAction:action to:target from:self forEvent:event];
}

// 在 touch 的过程中, 会调用这几个函数, 来判断是否 touch 应该继续.
- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
    return YES;
}

- (BOOL)continueTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
    return YES;
}

- (void)endTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
}

- (void)cancelTrackingWithEvent:(UIEvent *)event
{
}

// 在 UIControl 里面, 没有对于 super 的调用操作. 所以, 这也是为什么 UIButton 没有了向上传递事件的原因.
// UIControl 通过检测 touch 的过程, 将action的调用逻辑, 封装到了自己的内部.
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    _touchInside = YES;
    _tracking = [self beginTrackingWithTouch:touch withEvent:event];
    
    self.highlighted = YES; // 更改 highLighted 状态. 这个状态的改变, 会引起视图的变化.
    
    if (_tracking) { // beginTrackingWithTouch 控制的状态.
        UIControlEvents currentEvents = UIControlEventTouchDown;
        
        if (touch.tapCount > 1) {
            currentEvents |= UIControlEventTouchDownRepeat;
        }
        // 所以, event 到底是什么, 是根据 touch 的交互用代码判断出来的.
        // 在 _sendActionsForControlEvents 方法里, 根据 event 进行 target action 的调用.
        [self _sendActionsForControlEvents:currentEvents withEvent:event];
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    const BOOL wasTouchInside = _touchInside;
    _touchInside = [self pointInside:[touch locationInView:self] withEvent:event];
    
    self.highlighted = _touchInside;
    
    if (_tracking) {
        // 这里, tracking 要两次判断, 第一次判断之前的状态, 第二次判断现有的状态.
        _tracking = [self continueTrackingWithTouch:touch withEvent:event];
        if (_tracking) {
            UIControlEvents currentEvents = ((_touchInside)? UIControlEventTouchDragInside : UIControlEventTouchDragOutside);
            
            if (!wasTouchInside && _touchInside) {
                // 如果之前没有进入, 现在进入了, 就是dragEnter
                currentEvents |= UIControlEventTouchDragEnter;
            } else if (wasTouchInside && !_touchInside) {
                // 如果之前在进入状态, 现在拉出了, 就是 dragExit
                currentEvents |= UIControlEventTouchDragExit;
            }
            // currentEvents 的值, 还是代码通过追踪touch过程计算出来的.
            [self _sendActionsForControlEvents:currentEvents withEvent:event];
        }
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    _touchInside = [self pointInside:[touch locationInView:self] withEvent:event];
    
    self.highlighted = NO;
    
    if (_tracking) {
        [self endTrackingWithTouch:touch withEvent:event];
        [self _sendActionsForControlEvents:((_touchInside)? UIControlEventTouchUpInside : UIControlEventTouchUpOutside) withEvent:event];
    }
    
    _tracking = NO;
    _touchInside = NO;
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    self.highlighted = NO;
    
    if (_tracking) {
        [self cancelTrackingWithEvent:event];
        [self _sendActionsForControlEvents:UIControlEventTouchCancel withEvent:event];
    }
    
    _touchInside = NO;
    _tracking = NO;
}

- (void)setEnabled:(BOOL)newEnabled
{
    if (newEnabled != _enabled) {
        _enabled = newEnabled;
        [self _stateDidChange];
        self.userInteractionEnabled = _enabled;
    }
}

- (void)setHighlighted:(BOOL)newHighlighted
{
    if (newHighlighted != _highlighted) {
        _highlighted = newHighlighted;
        [self _stateDidChange];
    }
}

- (void)setSelected:(BOOL)newSelected
{
    if (newSelected != _selected) {
        _selected = newSelected;
        [self _stateDidChange];
    }
}

// 更新状态. 这里仅仅做状态的改变, 真正的绘制过程, 不同的子类要根据当前的状态, 绘制不同的展示. 也就是下面的 state 的状态.
// 在 UIButton 里面, 重写了这个方法, 进行了 Button 不同状态下的 Label 和 ImageView 的更新.
- (void)_stateDidChange
{
    [self setNeedsDisplay];
    [self setNeedsLayout];
}

- (UIControlState)state
{
    UIControlState state = UIControlStateNormal;
    
    if (_highlighted)	state |= UIControlStateHighlighted;
    if (!_enabled)		state |= UIControlStateDisabled;
    if (_selected)		state |= UIControlStateSelected;
    
    return state;
}

@end
