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

//
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
    [[UIApplication sharedApplication] sendAction:action to:target from:self forEvent:event];
}

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
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    _touchInside = YES;
    _tracking = [self beginTrackingWithTouch:touch withEvent:event];

    self.highlighted = YES;

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

    self.highlighted = _touchInside;

    if (_tracking) {
        _tracking = [self continueTrackingWithTouch:touch withEvent:event];
        if (_tracking) {
            UIControlEvents currentEvents = ((_touchInside)? UIControlEventTouchDragInside : UIControlEventTouchDragOutside);

            if (!wasTouchInside && _touchInside) {
                currentEvents |= UIControlEventTouchDragEnter;
            } else if (wasTouchInside && !_touchInside) {
                currentEvents |= UIControlEventTouchDragExit;
            }

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

- (void)_stateDidChange
{
    [self setNeedsDisplay];
    [self setNeedsLayout];
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

- (UIControlState)state
{
    UIControlState state = UIControlStateNormal;
    
    if (_highlighted)	state |= UIControlStateHighlighted;
    if (!_enabled)		state |= UIControlStateDisabled;
    if (_selected)		state |= UIControlStateSelected;

    return state;
}

@end
