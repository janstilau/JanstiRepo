#import "UIScreen.h"
#import "UIImage+UIPrivate.h"
#import "UIImageView.h"
#import "UIApplication.h"
#import "UIViewLayoutManager.h"
#import "UIScreenMode+UIPrivate.h"
#import "UIWindow.h"
#import "UIKitView.h"
#import "UIView+UIPrivate.h"
#import <AppKit/AppKit.h>
#import <QuartzCore/QuartzCore.h>

NSString *const UIScreenDidConnectNotification = @"UIScreenDidConnectNotification";
NSString *const UIScreenDidDisconnectNotification = @"UIScreenDidDisconnectNotification";
NSString *const UIScreenModeDidChangeNotification = @"UIScreenModeDidChangeNotification";

NSMutableArray *_allScreens = nil;

@implementation UIScreen {
    UIImageView *_grabber;
    CALayer *_layer;
    NSMutableArray *_windows;
    __weak UIKitView *_UIKitView;
    __weak UIWindow *_keyWindow;
}

+ (void)initialize
{
    if (self == [UIScreen class]) {
        _allScreens = [[NSMutableArray alloc] init];
    }
}

+ (UIScreen *)mainScreen
{
    return ([_allScreens count] > 0)? [[_allScreens objectAtIndex:0] nonretainedObjectValue] : nil;
}

+ (NSArray *)screens
{
    NSMutableArray *screens = [NSMutableArray arrayWithCapacity:[_allScreens count]];

    for (NSValue *v in _allScreens) {
        [screens addObject:[v nonretainedObjectValue]];
    }

    return screens;
}

- (id)init
{
    if ((self = [super init])) {
        _layer = [CALayer layer];
        _layer.delegate = self;		// required to get the magic of the UIViewLayoutManager...
        _layer.layoutManager = [UIViewLayoutManager layoutManager];
        
        _windows = [[NSMutableArray alloc] init];
        _brightness = 1;
        
        _grabber = [[UIImageView alloc] initWithImage:[UIImage _windowResizeGrabberImage]];
        _grabber.layer.zPosition = 10000;
        [_layer addSublayer:_grabber.layer];
    }
    return self;
}

- (CGFloat)scale
{
    if ([[_UIKitView window] respondsToSelector:@selector(backingScaleFactor)]) {
        return [[_UIKitView window] backingScaleFactor];
    } else {
        return 1;
    }
}

- (BOOL)_hasResizeIndicator
{
    NSWindow *realWindow = [_UIKitView window];
    NSView *contentView = [realWindow contentView];

    if (_UIKitView && realWindow && contentView && ([realWindow styleMask] & NSResizableWindowMask) && [realWindow showsResizeIndicator] && !NSEqualSizes([realWindow minSize], [realWindow maxSize])) {
        const CGRect myBounds = NSRectToCGRect([_UIKitView bounds]);
        const CGPoint myLowerRight = CGPointMake(CGRectGetMaxX(myBounds),CGRectGetMaxY(myBounds));
        const CGRect contentViewBounds = NSRectToCGRect([contentView frame]);
        const CGPoint contentViewLowerRight = CGPointMake(CGRectGetMaxX(contentViewBounds),0);
        const CGPoint convertedPoint = NSPointToCGPoint([_UIKitView convertPoint:NSPointFromCGPoint(myLowerRight) toView:contentView]);

        if (CGPointEqualToPoint(convertedPoint,contentViewLowerRight) && [realWindow showsResizeIndicator]) {
            return YES;
        }
    }

    return NO;
}

- (void)_layoutSubviews
{
    if ([self _hasResizeIndicator]) {
        const CGSize grabberSize = _grabber.frame.size;
        const CGSize layerSize = _layer.bounds.size;
        CGRect grabberRect = _grabber.frame;
        grabberRect.origin = CGPointMake(layerSize.width-grabberSize.width,layerSize.height-grabberSize.height);
        _grabber.frame = grabberRect;
        _grabber.hidden = NO;
    } else if (!_grabber.hidden) {
        _grabber.hidden = YES;
    }
}

- (id)actionForLayer:(CALayer *)layer forKey:(NSString *)event
{
    return [NSNull null];
}

- (CGRect)applicationFrame
{
    const float statusBarHeight = [UIApplication sharedApplication].statusBarHidden? 0 : 20;
    const CGSize size = [self bounds].size;
    return CGRectMake(0,statusBarHeight,size.width,size.height-statusBarHeight);
}

- (CGRect)bounds
{
    return _layer.bounds;
}

- (CALayer *)_layer
{
    return _layer;
}

- (void)_UIKitViewFrameDidChange
{
    NSDictionary *userInfo = (self.currentMode)? [NSDictionary dictionaryWithObject:self.currentMode forKey:@"_previousMode"] : nil;
    self.currentMode = [UIScreenMode screenModeWithNSView:_UIKitView];
    [[NSNotificationCenter defaultCenter] postNotificationName:UIScreenModeDidChangeNotification object:self userInfo:userInfo];
}

- (void)_NSScreenDidChange
{
    [self.windows makeObjectsPerformSelector:@selector(_didMoveToScreen)];
}

- (void)_setUIKitView:(id)theView
{
    if (_UIKitView != theView) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:NSViewFrameDidChangeNotification object:_UIKitView];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidChangeScreenNotification object:nil];
        
        if ((_UIKitView = theView)) {
            [_allScreens addObject:[NSValue valueWithNonretainedObject:self]];
            self.currentMode = [UIScreenMode screenModeWithNSView:_UIKitView];
            [[NSNotificationCenter defaultCenter] postNotificationName:UIScreenDidConnectNotification object:self];
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_UIKitViewFrameDidChange) name:NSViewFrameDidChangeNotification object:_UIKitView];
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_NSScreenDidChange) name:NSWindowDidChangeScreenNotification object:[_UIKitView window]];
            [self _NSScreenDidChange];
        } else {
            self.currentMode = nil;
            [_allScreens removeObject:[NSValue valueWithNonretainedObject:self]];
            [[NSNotificationCenter defaultCenter] postNotificationName:UIScreenDidDisconnectNotification object:self];
        }
    }
}

- (UIKitView *)UIKitView
{
    return _UIKitView;
}

- (NSArray *)availableModes
{
    return (self.currentMode)? [NSArray arrayWithObject:self.currentMode] : nil;
}

- (void)_addWindow:(UIWindow *)window
{
    [_windows addObject:[NSValue valueWithNonretainedObject:window]];
}

- (void)_removeWindow:(UIWindow *)window
{
    if (_keyWindow == window) {
        _keyWindow = nil;
    }

    [_windows removeObject:[NSValue valueWithNonretainedObject:window]];
}

- (NSArray *)windows
{
    return [_windows valueForKey:@"nonretainedObjectValue"];
}

- (UIWindow *)keyWindow
{
    return _keyWindow;
}

- (void)_setKeyWindow:(UIWindow *)window
{
    _keyWindow = window;
}

@end
