#import "UIWindow+UIPrivate.h"
#import "UIView+UIPrivate.h"
#import "UIScreen+UIPrivate.h"
#import "UIScreenAppKitIntegration.h"
#import "UIApplication.h"
#import "UITouch+UIPrivate.h"
#import "UIScreenMode.h"
#import "UIResponderAppKitIntegration.h"
#import "UIViewController.h"
#import "UIGestureRecognizer+UIPrivate.h"
#import "UITouchEvent.h"
#import "UIKitView.h"
#import <AppKit/NSCursor.h>
#import <QuartzCore/QuartzCore.h>

const UIWindowLevel UIWindowLevelNormal = 0;
const UIWindowLevel UIWindowLevelStatusBar = 1000;
const UIWindowLevel UIWindowLevelAlert = 2000;

NSString *const UIWindowDidBecomeVisibleNotification = @"UIWindowDidBecomeVisibleNotification";
NSString *const UIWindowDidBecomeHiddenNotification = @"UIWindowDidBecomeHiddenNotification";
NSString *const UIWindowDidBecomeKeyNotification = @"UIWindowDidBecomeKeyNotification";
NSString *const UIWindowDidResignKeyNotification = @"UIWindowDidResignKeyNotification";

NSString *const UIKeyboardWillShowNotification = @"UIKeyboardWillShowNotification";
NSString *const UIKeyboardDidShowNotification = @"UIKeyboardDidShowNotification";
NSString *const UIKeyboardWillHideNotification = @"UIKeyboardWillHideNotification";
NSString *const UIKeyboardDidHideNotification = @"UIKeyboardDidHideNotification";
NSString *const UIKeyboardWillChangeFrameNotification = @"UIKeyboardWillChangeFrameNotification";

NSString *const UIKeyboardFrameBeginUserInfoKey = @"UIKeyboardFrameBeginUserInfoKey";
NSString *const UIKeyboardFrameEndUserInfoKey = @"UIKeyboardFrameEndUserInfoKey";
NSString *const UIKeyboardAnimationDurationUserInfoKey = @"UIKeyboardAnimationDurationUserInfoKey";
NSString *const UIKeyboardAnimationCurveUserInfoKey = @"UIKeyboardAnimationCurveUserInfoKey";

// deprecated
NSString *const UIKeyboardCenterBeginUserInfoKey = @"UIKeyboardCenterBeginUserInfoKey";
NSString *const UIKeyboardCenterEndUserInfoKey = @"UIKeyboardCenterEndUserInfoKey";
NSString *const UIKeyboardBoundsUserInfoKey = @"UIKeyboardBoundsUserInfoKey";

@implementation UIWindow {
    __weak UIResponder *_firstResponder;
    NSUndoManager *_undoManager;
}

- (id)initWithFrame:(CGRect)theFrame
{
    if ((self=[super initWithFrame:theFrame])) {
        _undoManager = [[NSUndoManager alloc] init];
        [self _makeHidden];	// do this first because before the screen is set, it will prevent any visibility notifications from being sent.
        self.screen = [UIScreen mainScreen];
        self.opaque = NO;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_NSWindowDidBecomeKeyNotification:) name:NSWindowDidBecomeKeyNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_NSWindowDidResignKeyNotification:) name:NSWindowDidResignKeyNotification object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self _makeHidden];	// I don't really like this here, but the real UIKit seems to do something like this on window destruction as it sends a notification and we also need to remove it from the app's list of windows
    
    // since UIView's dealloc is called after this one, it's hard ot say what might happen in there due to all of the subview removal stuff
    // so it's safer to make sure these things are nil now rather than potential garbage. I don't like how much work UIView's -dealloc is doing
    // but at the moment I don't see a good way around it...
    _screen = nil;
    _undoManager = nil;
    _rootViewController = nil;
    
}

- (UIResponder *)_firstResponder
{
    return _firstResponder;
}

- (void)_setFirstResponder:(UIResponder *)newFirstResponder
{
    _firstResponder = newFirstResponder;
}

- (NSUndoManager *)undoManager
{
    return _undoManager;
}

- (UIView *)superview
{
    return nil;		// lies!
}

- (void)removeFromSuperview
{
    // does nothing
}

- (UIWindow *)window
{
    return self;
}

/*
 Window 的 nextResponder, 就是 Application
 */
- (UIResponder *)nextResponder
{
    return [UIApplication sharedApplication];
}

- (void)setRootViewController:(UIViewController *)rootViewController
{
    if (rootViewController != _rootViewController) {
        [self.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
        
        const BOOL was = [UIView areAnimationsEnabled];
        [UIView setAnimationsEnabled:NO];
        _rootViewController = rootViewController;
        _rootViewController.view.frame = self.bounds;
        [self addSubview:_rootViewController.view];
        [self layoutIfNeeded];
        [UIView setAnimationsEnabled:was];
    }
}

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    _rootViewController.view.frame = self.bounds;
}

- (void)setScreen:(UIScreen *)theScreen
{
    if (theScreen != _screen) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:UIScreenModeDidChangeNotification object:_screen];
        
        const BOOL wasHidden = self.hidden;
        [self _makeHidden];

        [self.layer removeFromSuperlayer];
        _screen = theScreen;
        [[_screen _layer] addSublayer:self.layer];

        if (!wasHidden) {
            [self _makeVisible];
        }

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_screenModeChangedNotification:) name:UIScreenModeDidChangeNotification object:_screen];
    }
}

- (void)_screenModeChangedNotification:(NSNotification *)note
{
    UIScreenMode *previousMode = [[note userInfo] objectForKey:@"_previousMode"];
    UIScreenMode *newMode = _screen.currentMode;

    if (!CGSizeEqualToSize(previousMode.size,newMode.size)) {
        [self _superviewSizeDidChangeFrom:previousMode.size to:newMode.size];
    }
}

- (CGPoint)convertPoint:(CGPoint)toConvert toWindow:(UIWindow *)toWindow
{
    if (toWindow == self) {
        return toConvert;
    } else {
        // Convert to screen coordinates
        toConvert.x += self.frame.origin.x;
        toConvert.y += self.frame.origin.y;
        
        if (toWindow) {
            // Now convert the screen coords into the other screen's coordinate space
            toConvert = [self.screen convertPoint:toConvert toScreen:toWindow.screen];

            // And now convert it from the new screen's space into the window's space
            toConvert.x -= toWindow.frame.origin.x;
            toConvert.y -= toWindow.frame.origin.y;
        }
        
        return toConvert;
    }
}

- (CGPoint)convertPoint:(CGPoint)toConvert fromWindow:(UIWindow *)fromWindow
{
    if (fromWindow == self) {
        return toConvert;
    } else {
        if (fromWindow) {
            // Convert to screen coordinates
            toConvert.x += fromWindow.frame.origin.x;
            toConvert.y += fromWindow.frame.origin.y;
            
            // Change to this screen.
            toConvert = [self.screen convertPoint:toConvert fromScreen:fromWindow.screen];
        }
        
        // Convert to window coordinates
        toConvert.x -= self.frame.origin.x;
        toConvert.y -= self.frame.origin.y;

        return toConvert;
    }
}

- (CGRect)convertRect:(CGRect)toConvert fromWindow:(UIWindow *)fromWindow
{
    CGPoint convertedOrigin = [self convertPoint:toConvert.origin fromWindow:fromWindow];
    return CGRectMake(convertedOrigin.x, convertedOrigin.y, toConvert.size.width, toConvert.size.height);
}

- (CGRect)convertRect:(CGRect)toConvert toWindow:(UIWindow *)toWindow
{
    CGPoint convertedOrigin = [self convertPoint:toConvert.origin toWindow:toWindow];
    return CGRectMake(convertedOrigin.x, convertedOrigin.y, toConvert.size.width, toConvert.size.height);
}

- (void)makeKeyWindow
{
    if (!self.isKeyWindow && self.screen) {
        // this check is here because if the underlying screen's UIKitView is AppKit's keyWindow, then
        // we must resign it because UIKit thinks it's currently the key window, too, so we do that here.
        if ([self.screen.keyWindow isKeyWindow]) {
            [self.screen.keyWindow resignKeyWindow];
        }
        
        // now we set the screen's key window to ourself - note that this doesn't really make it the key
        // window yet from an external point of view...
        [self.screen _setKeyWindow:self];
        
        // if it turns out we're now the key window, it means this window is ultimately within a UIKitView
        // that's the current AppKit key window, too, so we make it so. if we are NOT the key window, we
        // need to try to tell AppKit to make the UIKitView we're on the key window. If that works out,
        // we will get a notification and -becomeKeyWindow will be called from there, so we don't have to
        // do anything else in here.
        if (self.isKeyWindow) {
            [self becomeKeyWindow];
        } else {
            [[self.screen.UIKitView window] makeFirstResponder:self.screen.UIKitView];
            [[self.screen.UIKitView window] makeKeyWindow];
        }
    }
}

- (BOOL)isKeyWindow
{
    // only return YES if we have a screen and our screen's UIKitView is on the AppKit key window
    
    if (self.screen.keyWindow == self) {
        return [[self.screen.UIKitView window] isKeyWindow];
    }

    return NO;
}

- (void)becomeKeyWindow
{
    if ([[self _firstResponder] respondsToSelector:@selector(becomeKeyWindow)]) {
        [(id)[self _firstResponder] becomeKeyWindow];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:UIWindowDidBecomeKeyNotification object:self];
}

- (void)resignKeyWindow
{
    if ([[self _firstResponder] respondsToSelector:@selector(resignKeyWindow)]) {
        [(id)[self _firstResponder] resignKeyWindow];
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:UIWindowDidResignKeyNotification object:self];
}

- (void)_NSWindowDidBecomeKeyNotification:(NSNotification *)note
{
    NSWindow *nativeWindow = [note object];

    // when the underlying screen's NSWindow becomes key, we can use the keyWindow property the screen itself
    // to know if this UIWindow should become key again now or not. If things match up, we fire off -becomeKeyWindow
    // again to let the app know this happened. Normally iOS doesn't run into situations where the user can change
    // the key window out from under the app, so this is going to be somewhat unusual UIKit behavior...
    if ([[self.screen.UIKitView window] isEqual:nativeWindow]) {
        if (self.screen.keyWindow == self) {
            [self becomeKeyWindow];
        }
    }
}

- (void)_NSWindowDidResignKeyNotification:(NSNotification *)note
{
    NSWindow *nativeWindow = [note object];
    
    // if the resigned key window is the same window that hosts our underlying screen, then we need to resign
    // this UIWindow, too. note that it does NOT actually unset the keyWindow property for the UIScreen!
    // this is because if the user clicks back in the screen's window, we need a way to reconnect this UIWindow
    // as the key window, too, so that's how that is done.
    if ([[self.screen.UIKitView window] isEqual:nativeWindow]) {
        if (self.screen.keyWindow == self) {
            [self resignKeyWindow];
        }
    }
}

- (void)_makeHidden
{
    if (!self.hidden) {
        [super setHidden:YES];
        
        if (self.screen) {
            [self.screen _removeWindow:self];
            [[NSNotificationCenter defaultCenter] postNotificationName:UIWindowDidBecomeHiddenNotification object:self];
        }
    }
}

- (void)_makeVisible
{
    if (self.hidden) {
        [super setHidden:NO];

        if (self.screen) {
            [self.screen _addWindow:self];
            [[NSNotificationCenter defaultCenter] postNotificationName:UIWindowDidBecomeVisibleNotification object:self];
        }
    }
}

- (void)setHidden:(BOOL)hide
{
    if (hide) {
        [self _makeHidden];
    } else {
        [self _makeVisible];
    }
}

- (void)makeKeyAndVisible
{
    [self _makeVisible];
    [self makeKeyWindow];
}

- (void)setWindowLevel:(UIWindowLevel)level
{
    self.layer.zPosition = level;
}

- (UIWindowLevel)windowLevel
{
    return self.layer.zPosition;
}

/*
The UIApplication object calls this method to dispatch events to the window.
Window objects dispatch touch events to the view in which the touch occurred, and dispatch other types of events to the most appropriate target object.
 You can call this method as needed in your app to dispatch custom events that you create. For example, you might call this method to dispatch a custom event to the window’s responder chain.
 */
- (void)sendEvent:(UIEvent *)event
{
    if ([event isKindOfClass:[UITouchEvent class]]) {
        [self _processTouchEvent:(UITouchEvent *)event];
    }
}


/*
 在这个时候, UITouchEvent 的 touch 中的 View 已经固定了下来了, UIView 的 hitTest 方法, 是在 sendEvent 之前就会被调用的.
 在 sendEvent 里面, 直接就是调用 event 中存储的 View, 调用相应的 touch 方法了.
 */
- (void)_processTouchEvent:(UITouchEvent *)event
{
    UIView *view = event.touch.view;

    // 在 touch 刚开始的时候, 将 touch 所在 View 和 所有 superView 上的所有 gesture, 添加到 touch 中去.
    if (event.touch.phase == UITouchPhaseBegan) {
        for (UIView *subview = view; subview != nil; subview = [subview superview]) {
            for (UIGestureRecognizer *gesture in subview.gestureRecognizers) {
                [gesture _beginTrackingTouch:event.touch withEvent:event];
            }
        }
    }

    BOOL gestureRecognized = NO;
    BOOL possibleGestures = NO;
    BOOL delaysTouchesBegan = NO;
    BOOL delaysTouchesEnded = NO;
    BOOL cancelsTouches = NO;

    /*
     这里非常重要, gesture 和 view 都在这里进行了处理.
     
     A gesture recognizer operates on touches hit-tested to a specific view and all of that view’s subviews. It thus must be associated with that view. To make that association you must call the UIView method addGestureRecognizer:. A gesture recognizer doesn’t participate in the view’s responder chain.
     
     这里, 猜测, 如果一个 View 增加了 gesture, 那么 event.touch.view 是它的子 View, 这个父 View 的 gesture 也会添加到 touch.gestureRecognizers 中去.
     
     cancelsTouchesInView 如果 gesture 识别了手势, 那么 view 就会收到 cancel 的方法调用, 并且之后也不会接收到 touch 方法调用了.
     delaysTouchesBegan 在 gesture 开始识别阶段, 如果 gesture 还没有识别出来, view 不会接收到 touch 调用, 如果识别出来了, view 就不会接收到调用, 如果 gesture 识别失败了, 才会接收到 touch 调用
     delaysTouchesEnded 和上面一样, 如果 gesture 还没有识别出来, touchedn 的调用, view 就先不收到. 如果 gesture 识别出了, view 接受到的就是 cancel 调用, 否则才会是 end 调用.
     
     为什么 UIControl 上面添加一个 gesture, 就经常性的不能触发回调.
     默认 delaysTouchesBegan 0, delaysTouchesEnded 1, cancelsTouchesInView 1, 当后面的两个为 1 的时候, 手势识别出来, view 就会接收到 cancel 的调用.
     但是 UIControl 里面, 很多事件是要在 touchEnd 里面触发的, 所以, UIControl 里面, 失去了 touchEnd 函数被调用的机会, 所以就不能正常的触发回调了.
     */
    for (UIGestureRecognizer *gesture in event.touch.gestureRecognizers) {
        [gesture _continueTrackingWithEvent:event]; // 手势的处理过程.
        
        const BOOL recognized = (gesture.state == UIGestureRecognizerStateRecognized ||
                                 gesture.state == UIGestureRecognizerStateBegan);
        const BOOL possible = (gesture.state == UIGestureRecognizerStatePossible);
        
        gestureRecognized |= recognized;
        possibleGestures |= possible;
        
        if (recognized || possible) {
            delaysTouchesBegan |= gesture.delaysTouchesBegan;
            
            // special case for scroll views so that -delaysContentTouches works somewhat as expected
            // likely this is pretty wrong, but it should work well enough for most normal cases, I suspect.
            if ([gesture.view isKindOfClass:[UIScrollView class]]) {
                UIScrollView *scrollView = (UIScrollView *)gesture.view;
                
                if ([gesture isEqual:scrollView.panGestureRecognizer] ||
                    [gesture isEqual:scrollView.scrollWheelGestureRecognizer]) {
                    delaysTouchesBegan |= scrollView.delaysContentTouches;
                }
            }
        }
        
        if (recognized) {
            delaysTouchesEnded |= gesture.delaysTouchesEnded;
            cancelsTouches |= gesture.cancelsTouchesInView;
        }
    }
    
    if (event.isDiscreteGesture) {
        /*
         如果 event 不是触摸事件的话.
         */
        if (!gestureRecognized || (gestureRecognized && !cancelsTouches && !delaysTouchesBegan)) {
            if (event.touchEventGesture == UITouchEventGestureRightClick) {
                [view rightClick:event.touch withEvent:event];
            } else if (event.touchEventGesture == UITouchEventGestureScrollWheel) {
                [view scrollWheelMoved:event.translation withEvent:event];
            } else if (event.touchEventGesture == UITouchEventGestureMouseMove) {
                [view mouseMoved:event.touch withEvent:event];
            } else if (event.touchEventGesture == UITouchEventGestureMouseEntered) {
                [view mouseEntered:event.touch.view withEvent:event];
            } else if (event.touchEventGesture == UITouchEventGestureMouseExited) {
                [view mouseExited:event.touch.view withEvent:event];
            }
        }
    } else {
        
        // 调用 touch 所在 view 的各个 touch 方法.
        if (event.touch.phase == UITouchPhaseBegan) {
            if ((!gestureRecognized && !possibleGestures) || !delaysTouchesBegan) {
                [view touchesBegan:event.allTouches withEvent:event];
                event.touch.wasDeliveredToView = YES;
            }
        } else if (delaysTouchesBegan && gestureRecognized && !event.touch.wasDeliveredToView) {
            // if we were delaying touches began and a gesture gets recognized, and we never sent it to the view,
            // we need to throw it away and be sure we never send it to the view for the duration of the gesture
            // so we do this by marking it both delivered and cancelled without actually sending it to the view.
            event.touch.wasDeliveredToView = YES;
            event.touch.wasCancelledInView = YES;
        } else if (delaysTouchesBegan &&
                   !gestureRecognized &&
                   !possibleGestures &&
                   !event.touch.wasDeliveredToView &&
                   event.touch.phase != UITouchPhaseCancelled) {
            // need to fake-send a touches began using the cached time and location in the touch
            // a followup move or ended or cancelled touch will be sent below if necessary
            const NSTimeInterval currentTimestamp = event.touch.timestamp;
            const UITouchPhase currentPhase = event.touch.phase;
            const CGPoint currentLocation = event.touch.locationOnScreen;
            
            event.touch.timestamp = event.touch.beganPhaseTimestamp;
            event.touch.locationOnScreen = event.touch.beganPhaseLocationOnScreen;
            event.touch.phase = UITouchPhaseBegan;
            
            [view touchesBegan:event.allTouches withEvent:event];
            event.touch.wasDeliveredToView = YES;
            
            event.touch.phase = currentPhase;
            event.touch.locationOnScreen = currentLocation;
            event.touch.timestamp = currentTimestamp;
        }
        
        if (event.touch.phase != UITouchPhaseBegan &&
            event.touch.wasDeliveredToView &&
            !event.touch.wasCancelledInView) {
            if (event.touch.phase == UITouchPhaseCancelled) {
                [view touchesCancelled:event.allTouches withEvent:event];
                event.touch.wasCancelledInView = YES;
            } else if (gestureRecognized && (cancelsTouches || (event.touch.phase == UITouchPhaseEnded && delaysTouchesEnded))) {
                // since we're supposed to cancel touches, mark it cancelled, send it to the view, and
                // then change it back to whatever it was because there might be other gesture recognizers
                // that are still using the touch for whatever reason and aren't going to expect it suddenly
                // cancelled. (technically cancelled touches are, I think, meant to be a last resort..
                // the sort of thing that happens when a phone call comes in or a modal window comes up)
                const UITouchPhase currentPhase = event.touch.phase;
                
                event.touch.phase = UITouchPhaseCancelled;
                
                [view touchesCancelled:event.allTouches withEvent:event];
                event.touch.wasCancelledInView = YES;
                
                event.touch.phase = currentPhase;
            } else if (event.touch.phase == UITouchPhaseMoved) {
                [view touchesMoved:event.allTouches withEvent:event];
            } else if (event.touch.phase == UITouchPhaseEnded) {
                [view touchesEnded:event.allTouches withEvent:event];
            }
        }
    }
    
    NSCursor *newCursor = [view mouseCursorForEvent:event] ?: [NSCursor arrowCursor];
    
    if ([NSCursor currentCursor] != newCursor) {
        [newCursor set];
    }
}

@end
