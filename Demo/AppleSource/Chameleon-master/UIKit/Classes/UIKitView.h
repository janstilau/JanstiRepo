#import <Cocoa/Cocoa.h>
#import "UIApplicationDelegate.h"
#import "UIScreen.h"
#import "UIWindow.h"

@interface UIKitView : NSView

// returns the UIView (or nil) that successfully responds to a -hitTest:withEvent: at the given point.
// the point is specified in this view's coordinate system (unlike NSView's hitTest method).
- (UIView *)hitTestUIView:(NSPoint)point;

// this is an optional method
// it will set the sharedApplication's delegate to appDelegate. if delay is >0, it will then look in the app bundle for
// various default.png images (ideally it would replicate the search pattern that the iPad does, but for now it's just
// uses Default-Landscape.png). If delay <= 0, it skips doing any launch stuff and just calls the delegate's
// applicationDidFinishLaunching: method. It's up to the app delegate to create its own window, just as it is in the real
// UIKit when not using a XIB.
// ** IMPORTANT: appDelegate is *not* retained! **
- (void)launchApplicationWithDelegate:(id<UIApplicationDelegate>)appDelegate afterDelay:(NSTimeInterval)delay;

// these are sort of hacks used internally. I don't know if there's much need for them from the outside, really.
- (void)cancelTouchesInView:(UIView *)view;
- (void)sendStationaryTouches;

// this is an optional property to make it quick and easy to get a window to start adding views to.
// created on-demand to be the size of the UIScreen.bounds, flexible width/height, and calls makeKeyAndVisible when it is first created
@property (nonatomic, strong, readonly) UIWindow *UIWindow;

// a UIKitView owns a single UIScreen. when the UIKitView is part of an NSWindow hierarchy, the UIScreen appears as a connected screen in
// [UIScreen screens], etc.
@property (nonatomic, strong, readonly) UIScreen *UIScreen;
@end
