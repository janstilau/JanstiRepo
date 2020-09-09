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
        /*
         这个值, 目前在本类里面没有用到, 只是在 UIButton 里面, 根据这个值进行了显示的控制.
         */
        self.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
        self.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    }
    return self;
}

/*
 通过一个数据类, 将各种操作, 组合在一起, 然后存储起来, 以便后续的操作.
 The control does not retain the object in the target parameter.
 It is your responsibility to maintain a strong reference to the target object while it is attached to a control.
 这里实现有点问题, target 是不应该进行 retain 操作的.
 */
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
        if (controlAction.target == target &&
            (action == NULL || controlAction.controlEvents == controlEvents)) {
            [discard addObject:controlAction];
        }
    }
    [_registeredActions removeObjectsInArray:discard];
}

/*
 所有的这些, 都是建立在, 实现存储了 target,action,event 的基础之上的.
 */
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

/*
 所以, 实际上没有触发这回事发生.
 都是数据发生改变的对象, 主动告知监听者, 监听者才能够知道事件发生了.
 */
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
    /*
     Normally, this method is invoked by a UIControl object that the user has touched.
     The default implementation dispatches the action method to the given target object or, if no target is specified, to the first responder.
     Subclasses may override this method to perform special dispatching of action messages.
     By default, this method pushes two parameters when calling the target. These last two parameters are optional for the receiver because it is up to the caller (usually a UIControl object) to remove any parameters it added. This design enables the action selector to be one of the following:
     
     - (void)action
     
     - (void)action:(id)sender
     
     - (void)action:(id)sender forEvent:(UIEvent *)even
     */
    
    /*
     If aTarget is nil, sharedApplication looks for an object that can respond to the message—that is, an object that implements a method matching anAction. It begins with the first responder of the key window. If the first responder can’t respond, it tries the first responder’s next responder and continues following next responder links up the responder chain. If none of the objects in the key window’s responder chain can handle the message, sharedApplication attempts to send the message to the key window’s delegate.
     
     If the delegate doesn’t respond and the main window is different from the key window, sharedApplication begins again with the first responder in the main window. If objects in the main window can’t respond, sharedApplication attempts to send the message to the main window’s delegate. If still no object has responded, sharedApplication tries to handle the message itself.
     If sharedApplication can’t respond, it attempts to send the message to its own delegate.
     */
    [[UIApplication sharedApplication] sendAction:action to:target from:self forEvent:event];
}

/*
 Called when a touch event enters the control’s bounds.
 也就是在  - (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event 方法内部.
 如果这个方法返回 NO, 那么整个触摸流程就终止了.
 因为在
 - (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event,
 - (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
 代码里面, 只有 tracking 为 YES 的情况下, 才进行后续的逻辑处理.
 */
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

/*
 在 UIControl 里面, 没有对于 super 的调用操作. 所以, 这也是为什么 UIButton 没有了向上传递事件的原因.
 */

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    _touchInside = YES;
    _tracking = [self beginTrackingWithTouch:touch withEvent:event];
    
    self.highlighted = YES; // 更改 highLighted 状态. 这个状态的改变, 会引起视图的变化.
    
    /*
     在触摸刚开始的时候, 触发的时间, 仅仅是 touchDown
     */
    if (_tracking) {
        UIControlEvents currentEvents = UIControlEventTouchDown;
        if (touch.tapCount > 1) {
            currentEvents |= UIControlEventTouchDownRepeat;
        }
        [self _sendActionsForControlEvents:currentEvents withEvent:event];
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    const BOOL wasTouchInside = _touchInside;
    _touchInside = [self pointInside:[touch locationInView:self] withEvent:event];
    /*
     根据当前的 touch 的位置, 来判断是否还是 touchInside
     */
    self.highlighted = _touchInside;
    
    /*
     根据上一次 touch 的位置, 和当前 touch 的位置, 判断 event 的状态.
     */
    if (_tracking) {
        // 这里, tracking 要两次判断, 第一次判断之前的状态, 第二次判断现有的状态.
        _tracking = [self continueTrackingWithTouch:touch withEvent:event];
        if (_tracking) {
            UIControlEvents currentEvents = (_touchInside? UIControlEventTouchDragInside : UIControlEventTouchDragOutside);
            if (!wasTouchInside && _touchInside) {
                currentEvents |= UIControlEventTouchDragEnter;
            } else if (wasTouchInside && !_touchInside) {
                currentEvents |= UIControlEventTouchDragExit;
            }
            [self _sendActionsForControlEvents:currentEvents withEvent:event];
        }
    }
    
    /*
     从这里, 我们可以想象下 gesture 的处理流程, 一定也是记录了上一次的位置, 和这一次的位置, 根据两次位置的不同, 进行相应的事件的触发.
     */
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    _touchInside = [self pointInside:[touch locationInView:self] withEvent:event];
    
    self.highlighted = NO;
    
    /*
     根据最后的结束的位置, 决定 event 的状态.
     */
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

/*
 以下的几个量, 首先能够控制 UIControl 的各个子类的界面变化.
 对于 enable 来说, 除了界面上的变化, 还有 userInteractionEnabled 的变化.
 所以, Enabled 控制起始是分开的. 界面上的变化子类完成, 触摸事件上的变化 UIView 的属性完成.
 */
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

/*
 Enable, Selected, Highlighted 发生了变化.
 stateDidChange 之后, 应该影响到 UI 变化.
 UIControl 里面, 是没有任何的 UI 相关的事情的, 仅仅是事件处理的逻辑.
 各个 UIControl 的子类, 应该重写这些方法, 读取 以上三个值, 进行 UI 方面的变化逻辑.
 */
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
