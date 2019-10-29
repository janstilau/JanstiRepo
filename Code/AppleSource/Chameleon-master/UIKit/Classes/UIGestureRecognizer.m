#import "UIGestureRecognizer.h"
#import "UIGestureRecognizerSubclass.h"
#import "UITouch+UIPrivate.h"
#import "UIAction.h"
#import "UIApplication.h"
#import "UITouchEvent.h"

@implementation UIGestureRecognizer {
    NSMutableArray *_registeredActions; // 对于 target, action 的包装.
    NSMutableArray *_trackingTouches;
    __unsafe_unretained UIView *_view; // gesture 相关联的 view
    
    struct {
        unsigned shouldBegin : 1;
        unsigned shouldReceiveTouch : 1;
        unsigned shouldRecognizeSimultaneouslyWithGestureRecognizer : 1;
    } _delegateHas;
}

- (id)initWithTarget:(id)target action:(SEL)action
{
    if ((self=[super init])) {
        _state = UIGestureRecognizerStatePossible;
        _cancelsTouchesInView = YES;
        _delaysTouchesBegan = NO;
        _delaysTouchesEnded = YES;
        _enabled = YES;

        _registeredActions = [[NSMutableArray alloc] initWithCapacity:1];
        _trackingTouches = [[NSMutableArray alloc] initWithCapacity:1];
        
        [self addTarget:target action:action];
    }
    return self;
}


- (void)addTarget:(id)target action:(SEL)action
{
    UIAction *actionRecord = [[UIAction alloc] init];
    actionRecord.target = target;
    actionRecord.action = action;
    [_registeredActions addObject:actionRecord];
}

- (void)removeTarget:(id)target action:(SEL)action
{
    UIAction *actionRecord = [[UIAction alloc] init];
    actionRecord.target = target;
    actionRecord.action = action;
    // 之所以可以这样调用, 是因为 UIAction 的 isEqual 方法进行了复写.
    [_registeredActions removeObject:actionRecord];
}

- (void)_setView:(UIView *)v
{
    if (v != _view) {
        [self reset]; // not sure about this, but I think it makes sense
        _view = v;
    }
}

- (void)setDelegate:(id<UIGestureRecognizerDelegate>)aDelegate
{
    if (aDelegate != _delegate) {
        _delegate = aDelegate;
        _delegateHas.shouldBegin = [_delegate respondsToSelector:@selector(gestureRecognizerShouldBegin:)];
        _delegateHas.shouldReceiveTouch = [_delegate respondsToSelector:@selector(gestureRecognizer:shouldReceiveTouch:)];
        _delegateHas.shouldRecognizeSimultaneouslyWithGestureRecognizer = [_delegate respondsToSelector:@selector(gestureRecognizer:shouldRecognizeSimultaneouslyWithGestureRecognizer:)];
    }
}

- (void)requireGestureRecognizerToFail:(UIGestureRecognizer *)otherGestureRecognizer
{
    // 居然没有实现....
}

- (NSUInteger)numberOfTouches
{
    return [_trackingTouches count];
}

- (CGPoint)locationInView:(UIView *)view
{
    // by default, this should compute the centroid of all the involved points
    // of course as of this writing, Chameleon only supports one point but at least
    // it may be semi-correct if that ever changes. :D YAY FOR COMPLEXITY!
    
    CGFloat x = 0;
    CGFloat y = 0;
    CGFloat k = 0;
    
    for (UITouch *touch in _trackingTouches) {
        const CGPoint p = [touch locationInView:view];
        x += p.x;
        y += p.y;
        k++;
    }
    
    if (k > 0) {
        return CGPointMake(x/k, y/k);
    } else {
        return CGPointZero;
    }
}

- (CGPoint)locationOfTouch:(NSUInteger)touchIndex inView:(UIView *)view
{
    return [[_trackingTouches objectAtIndex:touchIndex] locationInView:view];
}

- (void)setState:(UIGestureRecognizerState)state
{
    if (_delegateHas.shouldBegin && _state == UIGestureRecognizerStatePossible && (state == UIGestureRecognizerStateRecognized || state == UIGestureRecognizerStateBegan)) {
        if (![_delegate gestureRecognizerShouldBegin:self]) {
            state = UIGestureRecognizerStateFailed;
        }
    }
    
    // the docs didn't say explicitly if these state transitions were verified, but I suspect they are. if anything, a check like this
    // should help debug things. it also helps me better understand the whole thing, so it's not a total waste of time :)

    typedef struct { UIGestureRecognizerState fromState, toState; BOOL shouldNotify; } StateTransition;

    #define NumberOfStateTransitions 9
    static const StateTransition allowedTransitions[NumberOfStateTransitions] = {
        // discrete gestures
        {UIGestureRecognizerStatePossible,		UIGestureRecognizerStateRecognized,     YES},
        {UIGestureRecognizerStatePossible,		UIGestureRecognizerStateFailed,          NO},

        // continuous gestures
        {UIGestureRecognizerStatePossible,		UIGestureRecognizerStateBegan,          YES},
        {UIGestureRecognizerStateBegan,			UIGestureRecognizerStateChanged,        YES},
        {UIGestureRecognizerStateBegan,			UIGestureRecognizerStateCancelled,      YES},
        {UIGestureRecognizerStateBegan,			UIGestureRecognizerStateEnded,          YES},
        {UIGestureRecognizerStateChanged,		UIGestureRecognizerStateChanged,        YES},
        {UIGestureRecognizerStateChanged,		UIGestureRecognizerStateCancelled,      YES},
        {UIGestureRecognizerStateChanged,		UIGestureRecognizerStateEnded,          YES}
    };
    
    const StateTransition *transition = NULL;

    for (NSUInteger t=0; t<NumberOfStateTransitions; t++) {
        if (allowedTransitions[t].fromState == _state && allowedTransitions[t].toState == state) {
            transition = &allowedTransitions[t];
            break;
        }
    }

    NSAssert2((transition != NULL), @"invalid state transition from %ld to %ld", _state, state);

    if (transition) {
        _state = transition->toState;
        
        if (transition->shouldNotify) {
            for (UIAction *actionRecord in _registeredActions) {
                // docs mention that the action messages are sent on the next run loop, so we'll do that here.
                // note that this means that reset can't happen until the next run loop, either otherwise
                // the state property is going to be wrong when the action handler looks at it, so as a result
                // I'm also delaying the reset call (if necessary) below in -continueTrackingWithEvent:
                [actionRecord.target performSelector:actionRecord.action withObject:self afterDelay:0];
            }
        }
    }
}

- (void)reset
{
    // note - this is also supposed to ignore any currently tracked touches
    // the touches themselves may not have gone away, so we don't just remove them from tracking, I think,
    // but instead just mark them as ignored by this gesture until the touches eventually end themselves.
    // in any case, this isn't implemented right now because we only have a single touch and so far I
    // haven't needed it.
    
    _state = UIGestureRecognizerStatePossible;
}

- (BOOL)canPreventGestureRecognizer:(UIGestureRecognizer *)preventedGestureRecognizer
{
    return YES;
}

- (BOOL)canBePreventedByGestureRecognizer:(UIGestureRecognizer *)preventingGestureRecognizer
{
    return YES;
}

- (void)ignoreTouch:(UITouch *)touch forEvent:(UIEvent*)event
{
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
}

- (void)_beginTrackingTouch:(UITouch *)touch withEvent:(UITouchEvent *)event
{
    if (self.enabled) {
        if (!_delegateHas.shouldReceiveTouch || [_delegate gestureRecognizer:self shouldReceiveTouch:touch]) {
            [touch _addGestureRecognizer:self];
            [_trackingTouches addObject:touch];
        }
    }
}

- (void)_continueTrackingWithEvent:(UITouchEvent *)event
{
    NSMutableSet *began = [NSMutableSet new];
    NSMutableSet *moved = [NSMutableSet new];
    NSMutableSet *ended = [NSMutableSet new];
    NSMutableSet *cancelled = [NSMutableSet new];
    BOOL multitouchSequenceIsEnded = YES;
    
    for (UITouch *touch in _trackingTouches) {
        if (touch.phase == UITouchPhaseBegan) {
            multitouchSequenceIsEnded = NO;
            [began addObject:touch];
        } else if (touch.phase == UITouchPhaseMoved) {
            multitouchSequenceIsEnded = NO;
            [moved addObject:touch];
        } else if (touch.phase == UITouchPhaseStationary) {
            multitouchSequenceIsEnded = NO;
        } else if (touch.phase == UITouchPhaseEnded) {
            [ended addObject:touch];
        } else if (touch.phase == UITouchPhaseCancelled) {
            [cancelled addObject:touch];
        }
    }

    if (_state == UIGestureRecognizerStatePossible || _state == UIGestureRecognizerStateBegan || _state == UIGestureRecognizerStateChanged) {
        if ([began count]) {
            [self touchesBegan:began withEvent:event];
        }

        if ([moved count]) {
            [self touchesMoved:moved withEvent:event];
        }
        
        if ([ended count]) {
            [self touchesEnded:ended withEvent:event];
        }
        
        if ([cancelled count]) {
            [self touchesCancelled:cancelled withEvent:event];
        }
    }
    
    // if all the touches are ended or cancelled, then the multitouch sequence must be over - so we can reset
    // our state back to normal and clear all the tracked touches, etc. to get ready for a new touch sequence
    // in the future.
    // this also applies to the special discrete gesture events because those events are only sent once!
    if (multitouchSequenceIsEnded || event.isDiscreteGesture) {
        // see note above in -setState: about the delay here!
        [self performSelector:@selector(reset) withObject:nil afterDelay:0];
    }
}

- (void)_endTrackingTouch:(UITouch *)touch withEvent:(UITouchEvent *)event
{
    [touch _removeGestureRecognizer:self];
    [_trackingTouches removeObject:touch];
}

@end
