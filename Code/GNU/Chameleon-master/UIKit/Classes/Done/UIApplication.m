#import "UIApplicationAppKitIntegration.h"
#import "UIScreenAppKitIntegration.h"
#import "UIWindow+UIPrivate.h"
#import "UIKitView.h"
#import "UIBackgroundTask.h"
#import "UINSApplicationDelegate.h"
#import <Cocoa/Cocoa.h>

NSString *const UIApplicationWillChangeStatusBarOrientationNotification = @"UIApplicationWillChangeStatusBarOrientationNotification";
NSString *const UIApplicationDidChangeStatusBarOrientationNotification = @"UIApplicationDidChangeStatusBarOrientationNotification";
NSString *const UIApplicationWillEnterForegroundNotification = @"UIApplicationWillEnterForegroundNotification";
NSString *const UIApplicationWillTerminateNotification = @"UIApplicationWillTerminateNotification";
NSString *const UIApplicationWillResignActiveNotification = @"UIApplicationWillResignActiveNotification";
NSString *const UIApplicationDidEnterBackgroundNotification = @"UIApplicationDidEnterBackgroundNotification";
NSString *const UIApplicationDidBecomeActiveNotification = @"UIApplicationDidBecomeActiveNotification";
NSString *const UIApplicationDidFinishLaunchingNotification = @"UIApplicationDidFinishLaunchingNotification";

NSString *const UIApplicationNetworkActivityIndicatorChangedNotification = @"UIApplicationNetworkActivityIndicatorChangedNotification";

NSString *const UIApplicationLaunchOptionsURLKey = @"UIApplicationLaunchOptionsURLKey";
NSString *const UIApplicationLaunchOptionsSourceApplicationKey = @"UIApplicationLaunchOptionsSourceApplicationKey";
NSString *const UIApplicationLaunchOptionsRemoteNotificationKey = @"UIApplicationLaunchOptionsRemoteNotificationKey";
NSString *const UIApplicationLaunchOptionsAnnotationKey = @"UIApplicationLaunchOptionsAnnotationKey";
NSString *const UIApplicationLaunchOptionsLocalNotificationKey = @"UIApplicationLaunchOptionsLocalNotificationKey";
NSString *const UIApplicationLaunchOptionsLocationKey = @"UIApplicationLaunchOptionsLocationKey";

NSString *const UIApplicationDidReceiveMemoryWarningNotification = @"UIApplicationDidReceiveMemoryWarningNotification";

NSString *const UITrackingRunLoopMode = @"UITrackingRunLoopMode";

const UIBackgroundTaskIdentifier UIBackgroundTaskInvalid = NSUIntegerMax; // correct?
const NSTimeInterval UIMinimumKeepAliveTimeout = 0;

static UIApplication *_theApplication = nil;

@implementation UIApplication {
    NSUInteger _ignoringInteractionEvents;
    NSDate *_backgroundTasksExpirationDate;
    NSMutableArray *_backgroundTasks;
}

+ (UIApplication *)sharedApplication
{
    if (!_theApplication) {
        _theApplication = [[self alloc] init];
    }
    
    return _theApplication;
}

- (id)init
{
    if ((self=[super init])) {
        _backgroundTasks = [[NSMutableArray alloc] init];
        _applicationState = UIApplicationStateActive;
        _applicationSupportsShakeToEdit = YES;		// yeah... not *really* true, but UIKit defaults to YES :)
        
        /*
         这些通知的具体源头, 不知道在哪里, 不过 Application 在这里进行了接收.
         */
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_applicationWillFinishLaunching:) name:NSApplicationWillFinishLaunchingNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_applicationDidFinishLaunching:) name:NSApplicationDidFinishLaunchingNotification object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_applicationWillTerminate:) name:NSApplicationWillTerminateNotification object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_applicationWillResignActive:) name:NSApplicationWillResignActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_applicationDidBecomeActive:) name:NSApplicationDidBecomeActiveNotification object:nil];
        
        [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(_applicationWillResignActive:) name:NSWorkspaceScreensDidSleepNotification object:nil];
        [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(_applicationDidBecomeActive:) name:NSWorkspaceScreensDidWakeNotification object:nil];
        
        [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(_computerWillSleep:) name:NSWorkspaceWillSleepNotification object:nil];
        [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(_computerDidWakeUp:) name:NSWorkspaceDidWakeNotification object:nil];
    }
    return self;
}

- (NSTimeInterval)statusBarOrientationAnimationDuration
{
    return 0.3;
}

- (BOOL)isStatusBarHidden
{
    return YES;
}

- (CGRect)statusBarFrame
{
    return CGRectZero;
}

- (NSTimeInterval)backgroundTimeRemaining
{
    return [_backgroundTasksExpirationDate timeIntervalSinceNow];
}

// 一般不设置.
- (void)setNetworkActivityIndicatorVisible:(BOOL)b
{
    if (b != [self isNetworkActivityIndicatorVisible]) {
        _networkActivityIndicatorVisible = b;
        [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationNetworkActivityIndicatorChangedNotification object:self];
    }
}

- (void)beginIgnoringInteractionEvents
{
    _ignoringInteractionEvents++;
}

- (void)endIgnoringInteractionEvents
{
    _ignoringInteractionEvents--;
}

- (BOOL)isIgnoringInteractionEvents
{
    return (_ignoringInteractionEvents > 0);
}

- (UIInterfaceOrientation)statusBarOrientation
{
    return UIInterfaceOrientationPortrait;
}

- (void)setStatusBarOrientation:(UIInterfaceOrientation)orientation
{
}

- (UIStatusBarStyle)statusBarStyle
{
    return UIStatusBarStyleDefault;
}

- (void)setStatusBarStyle:(UIStatusBarStyle)statusBarStyle
{
}

- (void)setStatusBarStyle:(UIStatusBarStyle)statusBarStyle animated:(BOOL)animated
{
}

- (void)setStatusBarHidden:(BOOL)hidden withAnimation:(UIStatusBarAnimation)animation
{
}

- (void)registerForRemoteNotificationTypes:(UIRemoteNotificationType)types
{
}

- (void)unregisterForRemoteNotifications
{
}

- (UIRemoteNotificationType)enabledRemoteNotificationTypes
{
    return UIRemoteNotificationTypeNone;
}

- (void)presentLocalNotificationNow:(UILocalNotification *)notification
{
}

- (void)cancelAllLocalNotifications
{
}

- (void)cancelLocalNotification:(UILocalNotification *)notification
{
}

- (NSArray *)scheduledLocalNotifications
{
    return nil;
}

- (void)setScheduledLocalNotifications:(NSArray *)scheduledLocalNotifications
{
}

- (UIBackgroundTaskIdentifier)beginBackgroundTaskWithExpirationHandler:(void(^)(void))handler
{
    UIBackgroundTask *task = [[UIBackgroundTask alloc] initWithExpirationHandler:handler];
    [_backgroundTasks addObject:task];
    return task.taskIdentifier;
}

- (void)endBackgroundTask:(UIBackgroundTaskIdentifier)identifier
{
    for (UIBackgroundTask *task in _backgroundTasks) {
        if (task.taskIdentifier == identifier) {
            [_backgroundTasks removeObject:task];
            break;
        }
    }
}

- (BOOL)_enterBackground
{
    if (self.applicationState != UIApplicationStateBackground) {
        _applicationState = UIApplicationStateBackground; // 修改状态.
        
        if ([_delegate respondsToSelector:@selector(applicationDidEnterBackground:)]) {
            [_delegate applicationDidEnterBackground:self];
        }
        
        [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidEnterBackgroundNotification object:self];
        
        return YES;
    } else {
        return NO;
    }
}

- (void)_enterForeground
{
    if (self.applicationState == UIApplicationStateBackground) {
        if ([_delegate respondsToSelector:@selector(applicationWillEnterForeground:)]) {
            [_delegate applicationWillEnterForeground:self];
        }
        
        [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationWillEnterForegroundNotification object:self];
        
        _applicationState = UIApplicationStateInactive;
    }
}

- (BOOL)_runRunLoopForBackgroundTasksBeforeDate:(NSDate *)date
{
    // check if all tasks were done, and if so, break
    if ([_backgroundTasks count] == 0) {
        return NO;
    }
    
    // run the runloop in the default mode so things like connections and timers still work for processing our
    // background tasks. we'll make sure not to run this any longer than 1 second at a time, otherwise the alert
    // might hang around for a lot longer than is necessary since we might not have anything to run in the default
    // mode for awhile or something which would keep this method from returning.
    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:date];
    
    // otherwise check if we've timed out and if we are, break
    if ([[NSDate date] timeIntervalSinceReferenceDate] >= [_backgroundTasksExpirationDate timeIntervalSinceReferenceDate]) {
        return NO;
    }
    
    return YES;
}

- (void)_cancelBackgroundTasks
{
    // if there's any remaining tasks, run their expiration handlers
    for (UIBackgroundTask *task in [_backgroundTasks copy]) {
        if (task.expirationHandler) {
            task.expirationHandler();
        }
    }
    
    // remove any lingering tasks so we're back to being empty
    [_backgroundTasks removeAllObjects];
}

- (void)_runBackgroundTasks:(void (^)(void))run_tasks
{
    run_tasks();
}

- (NSApplicationTerminateReply)terminateApplicationBeforeDate:(NSDate *)timeoutDate
{
    [self _enterBackground];
    
    _backgroundTasksExpirationDate = timeoutDate;
    
    // we will briefly block here for a short time and run the runloop in an attempt to let the background tasks finish up before
    // actually prompting the user with an annoying alert. users are much more used to an app hanging for a brief moment while
    // quitting than they are with an alert appearing/disappearing suddenly that they might have had trouble reading and processing
    // before it's gone. that sort of thing creates anxiety.
    NSDate *blockingBackgroundExpiration = [NSDate dateWithTimeIntervalSinceNow:1.33];
    
    for (;;) {
        if (![self _runRunLoopForBackgroundTasksBeforeDate:blockingBackgroundExpiration] || [NSDate timeIntervalSinceReferenceDate] >= [blockingBackgroundExpiration timeIntervalSinceReferenceDate]) {
            break;
        }
    }
    
    // if it turns out we're all done with tasks (or maybe had none to begin with), we'll clean up the structures
    // and tell our app we can terminate immediately now.
    if ([_backgroundTasks count] == 0) {
        [self _cancelBackgroundTasks];
        
        // and reset our timer since we're done
        _backgroundTasksExpirationDate = nil;
        
        // and return
        return NSTerminateNow;
    }
    
    // otherwise... we have to do a deferred thing so we can show an alert while we wait for background tasks to finish...
    
    void (^taskFinisher)(void) = ^{
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setAlertStyle:NSInformationalAlertStyle];
        [alert setShowsSuppressionButton:NO];
        [alert setMessageText:@"Quitting"];
        [alert setInformativeText:@"Finishing some tasks..."];
        [alert addButtonWithTitle:@"Quit Now"];
        [alert layout];
        
        // to avoid upsetting the user with an alert that flashes too quickly to read, we'll later artifically ensure that
        // the alert has been visible for at least some small amount of time to give them a chance to see and understand it.
        NSDate *minimumDisplayTime = [NSDate dateWithTimeIntervalSinceNow:2.33];
        
        NSModalSession session = [NSApp beginModalSessionForWindow:alert.window];
        
        // run the runloop and wait for tasks to finish
        while ([NSApp runModalSession:session] == NSRunContinuesResponse) {
            if (![self _runRunLoopForBackgroundTasksBeforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]]) {
                break;
            }
        }
        
        // when we exit the runloop loop, then we're done with the tasks. either they are all finished or the time has run out
        // so we need to clean things up here as if we're all finished. if there's any remaining tasks, run their expiration handlers
        [self _cancelBackgroundTasks];
        
        // and reset our timer since we're done
        _backgroundTasksExpirationDate = nil;
        
        // now just in case all of this happened too quickly and the user might not have had time to read and understand the alert,
        // we will kill some time for a bit as long as the alert is still visible. runModalSession: will not return NSRunContinuesResponse
        // if the user closed the alert, so in that case then this delay won't happen at all. however if the tasks finished too quickly
        // then what this does is kill time until the user clicks the quit button or the timer expires.
        while ([NSApp runModalSession:session] == NSRunContinuesResponse) {
            if ([NSDate timeIntervalSinceReferenceDate] >= [minimumDisplayTime timeIntervalSinceReferenceDate]) {
                break;
            }
        }
        
        
        [NSApp endModalSession:session];
        
        // tell the real NSApp we're all done here
        [NSApp replyToApplicationShouldTerminate:YES];
    };
    
    // I need to delay this but run it on the main thread and also be able to run it in the panel run loop mode
    // because we're probably in that run loop mode due to how -applicationShouldTerminate: does things. I don't
    // know if I could do this same thing with a couple of simple GCD calls, but whatever, this works too. :)
    [self performSelectorOnMainThread:@selector(_runBackgroundTasks:)
                           withObject:[taskFinisher copy]
                        waitUntilDone:NO
                                modes:[NSArray arrayWithObjects:NSModalPanelRunLoopMode, NSRunLoopCommonModes, nil]];
    
    return NSTerminateLater;
}

- (void)_computerWillSleep:(NSNotification *)note
{
    if ([self _enterBackground]) {
        // docs say we have 30 seconds to return from our handler for the sleep notification, so we'll let background tasks
        // take up to 29 of them with the idea that hopefully this means that any cancelation handlers that might need to run
        // have a full second or so to finish up before we're forced to sleep.
        // since we can just block here we don't need to put the app into a modal state or popup a window or anything because
        // the machine is about to go to sleep.. so we'll just do things in a blocking way in this case while still handling
        // any pending background tasks.
        
        _backgroundTasksExpirationDate = [[NSDate alloc] initWithTimeIntervalSinceNow:29];
        
        for (;;) {
            if (![self _runRunLoopForBackgroundTasksBeforeDate:_backgroundTasksExpirationDate]) {
                break;
            }
        }
        
        [self _cancelBackgroundTasks];
        
        // and reset our timer since we're done
        _backgroundTasksExpirationDate = nil;
    }
}

- (void)_computerDidWakeUp:(NSNotification *)note
{
    [self _enterForeground];
}

- (NSArray *)windows
{
    NSMutableArray *windows = [NSMutableArray new];
    
    for (UIScreen *screen in [UIScreen screens]) {
        [windows addObjectsFromArray:screen.windows];
    }
    
    return [windows sortedArrayUsingDescriptors:@[[[NSSortDescriptor alloc] initWithKey:@"windowLevel" ascending:YES]]];
}

// 所谓的 keyWindow 是 makeKeyAndVisible 调用设定的, 之所有有 keyWindow 这个概念, 是因为在桌面端, 可能会有 window.
- (UIWindow *)keyWindow
{
    for (UIWindow *window in self.windows) {
        if (window.isKeyWindow) {
            return window;
        }
    }
    
    return nil;
}


- (BOOL)sendAction:(SEL)action to:(id)target from:(id)sender forEvent:(UIEvent *)event
{
    if (!target) { // 如果没有 target , 就从发送者开始找, 而这个发送者, 一般来说, 就是第一响应者.
        id responder = sender;
        while (responder) {
            if ([responder respondsToSelector:action]) {
                target = responder;
                break;
            } else if ([responder respondsToSelector:@selector(nextResponder)]) {
                responder = [responder nextResponder];
            } else {
                responder = nil;
            }
        }
    }
    if (target) {
        /*
         找到了 target, 直接调用.
         这里有点问题, 默认了所有的 action 有着同样的方法签名.
         这里应该根据 signature 找到参数的个数, 进行分开处理才对.
         */
        typedef void(*EventActionMethod)(id, SEL, id, UIEvent *);
        EventActionMethod method = (EventActionMethod)[target methodForSelector:action];
        method(target, action, sender, event);
        return YES;
    }
    
    return NO;
}

/*
 事件的分发, 可以看到, 是直接把事件, 交给了 Window.
 */
- (void)sendEvent:(UIEvent *)event
{
    if (event.type ==  UIEventTypeTouches) {
        [self.windows makeObjectsPerformSelector:@selector(sendEvent:) withObject:event];
    } else {
        [self.keyWindow sendEvent:event];
    }
}

- (BOOL)openURL:(NSURL *)url
{
    return url? [[NSWorkspace sharedWorkspace] openURL:url] : NO;
}

- (BOOL)canOpenURL:(NSURL *)url
{
    return (url? [[NSWorkspace sharedWorkspace] URLForApplicationToOpenURL:url] : nil) != nil;
}

- (void)_applicationWillFinishLaunching:(NSNotification *)note
{
    NSDictionary *options = nil;
    
    if ([_delegate respondsToSelector:@selector(application:willFinishLaunchingOnDesktopWithOptions:)]) {
        [_delegate application:self willFinishLaunchingOnDesktopWithOptions:options];
    }
    
    if ([_delegate respondsToSelector:@selector(application:willFinishLaunchingWithOptions:)]) {
        [_delegate application:self willFinishLaunchingWithOptions:options];
    }
}

- (void)_applicationDidFinishLaunching:(NSNotification *)note
{
    NSDictionary *options = nil;
    
    if ([_delegate respondsToSelector:@selector(application:didFinishLaunchingOnDesktopWithOptions:)]) {
        [_delegate application:self didFinishLaunchingOnDesktopWithOptions:options];
    }
    
    if ([_delegate respondsToSelector:@selector(application:didFinishLaunchingWithOptions:)]) {
        [_delegate application:self didFinishLaunchingWithOptions:options];
    } else if ([_delegate respondsToSelector:@selector(applicationDidFinishLaunching:)]) {
        [_delegate applicationDidFinishLaunching:self];
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidFinishLaunchingNotification object:self];
}

- (void)_applicationWillTerminate:(NSNotification *)note
{
    if ([_delegate respondsToSelector:@selector(applicationWillTerminateOnDesktop:)]) {
        [_delegate applicationWillTerminateOnDesktop:self];
    }
    
    if ([_delegate respondsToSelector:@selector(applicationWillTerminate:)]) {
        [_delegate applicationWillTerminate:self];
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationWillTerminateNotification object:self];
}

- (void)_applicationWillResignActive:(NSNotification *)note
{
    if (self.applicationState == UIApplicationStateActive) {
        if ([_delegate respondsToSelector:@selector(applicationWillResignActive:)]) {
            [_delegate applicationWillResignActive:self];
        }
        
        [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationWillResignActiveNotification object:self];
        
        _applicationState = UIApplicationStateInactive;
    }
}

- (void)_applicationDidBecomeActive:(NSNotification *)note
{
    if (self.applicationState == UIApplicationStateInactive) {
        _applicationState = UIApplicationStateActive;
        
        if ([_delegate respondsToSelector:@selector(applicationDidBecomeActive:)]) {
            [_delegate applicationDidBecomeActive:self];
        }
        
        [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidBecomeActiveNotification object:self];
    }
}

// this is only here because there's a real private API in Apple's UIKit that does something similar
- (void)_performMemoryWarning
{
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidReceiveMemoryWarningNotification object:self];
}

@end


@implementation UIApplication(UIApplicationDeprecated)

- (void)setStatusBarHidden:(BOOL)hidden animated:(BOOL)animated
{
}

@end

int UIApplicationMain(int argc, char *argv[], NSString *principalClassName, NSString *delegateClassName)
{
    @autoreleasepool {
        UIApplication *app = principalClassName? [NSClassFromString(principalClassName) sharedApplication] : [UIApplication sharedApplication];
        id<UIApplicationDelegate> delegate = delegateClassName? [NSClassFromString(delegateClassName) new] : nil;
        
        [app setDelegate:delegate];
        
        NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
        NSString *mainNibName = [infoDictionary objectForKey:@"NSMainNibFile"];
        NSArray *topLevelObjects = nil;
        NSNib *mainNib = [[NSNib alloc] initWithNibNamed:mainNibName bundle:[NSBundle mainBundle]];
        
        [mainNib instantiateWithOwner:app topLevelObjects:&topLevelObjects];
        
        id<NSApplicationDelegate> backgroundTaskCatchingDelegate = [UINSApplicationDelegate new];
        [[NSApplication sharedApplication] setDelegate:backgroundTaskCatchingDelegate];
        /*
         在 Run 这个方法里面, 开启了运行循环操作.
         */
        [[NSApplication sharedApplication] run];
        
        // the only purpose of this is to confuse ARC. I'm not sure how else to do it.
        // without this here, ARC thinks it can dealloc some stuff before we're really done
        // with it, and since we're never really going to be done with this stuff, it has to
        // be kept around as long as the app runs, but since the app never actually gets here
        // it will never be executed but this prevents ARC from preemptively releasing things.
        // meh.
        [@[app, delegate, topLevelObjects, backgroundTaskCatchingDelegate] count];
    }
    
    // this never happens
    return 0;
}

void UIApplicationSendStationaryTouches(void)
{
    for (UIScreen *screen in [UIScreen screens]) {
        [screen.UIKitView sendStationaryTouches];
    }
}

void UIApplicationInterruptTouchesInView(UIView *view)
{
    // the intent here was that there needed to be a way to force-cancel touches to somewhat replicate situations that
    // might arise on OSX that you could kinda/sorta pretend were phonecall-like events where you'd want a touch or
    // gesture or something to cancel. these situations come up when things like popovers and modal menus are presented,
    //
    // If the need arises, my intent here is to send a notification or something on the *next* runloop to all UIKitViews
    // attached to screens to tell them to kill off their current touch sequence (if any). It seems important that this
    // happen on the *next* runloop cycle and not immediately because there were cases where the touch cancelling would
    // happen in response to something like a touch ended event, so we can't just blindly cancel a touch while it's in
    // the process of being evalulated since that could lead to very inconsistent behavior and really weird edge cases.
    // by deferring the cancel, it would then be able to take the right action if the touch phase was something *other*
    // than ended or cancelled by the time it attemped cancellation.
    
    if (!view) {
        for (UIScreen *screen in [UIScreen screens]) {
            [screen.UIKitView performSelector:@selector(cancelTouchesInView:) withObject:nil afterDelay:0];
        }
    } else {
        [view.window.screen.UIKitView performSelector:@selector(cancelTouchesInView:) withObject:view afterDelay:0];
    }
}