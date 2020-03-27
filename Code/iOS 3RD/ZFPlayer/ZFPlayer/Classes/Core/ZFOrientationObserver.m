#import "ZFOrientationObserver.h"
#import "ZFPlayer.h"

#define SysVersion [[UIDevice currentDevice] systemVersion].floatValue

@interface ZFFullViewController : UIViewController

@property (nonatomic, assign) UIInterfaceOrientationMask interfaceOrientationMask;

@end

@implementation ZFFullViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor redColor];
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    if (self.interfaceOrientationMask) {
        return self.interfaceOrientationMask;
    }
    return UIInterfaceOrientationMaskLandscape;
}

@end

// 寻找屏幕上面最最顶层的一个VC.

@interface UIWindow (CurrentViewController)

/*!
 @method currentViewController
 @return Returns the topViewController in stack of topMostController.
 */
+ (UIViewController*)zf_currentViewController;

@end

@implementation UIWindow (CurrentViewController)

+ (UIViewController*)zf_currentViewController; {
    UIWindow *window = [[UIApplication sharedApplication].delegate window];
    UIViewController *topViewController = [window rootViewController];
    while (true) {
        if (topViewController.presentedViewController) {
            topViewController = topViewController.presentedViewController;
        } else if ([topViewController isKindOfClass:[UINavigationController class]] && [(UINavigationController*)topViewController topViewController]) {
            topViewController = [(UINavigationController *)topViewController topViewController];
        } else if ([topViewController isKindOfClass:[UITabBarController class]]) {
            UITabBarController *tab = (UITabBarController *)topViewController;
            topViewController = tab.selectedViewController;
        } else {
            break;
        }
    }
    return topViewController;
}

@end

@interface ZFOrientationObserver ()

@property (nonatomic, weak) UIView *playerView;
@property (nonatomic, strong) UIView *cell;

@property (nonatomic, assign, getter=isFullScreen) BOOL fullScreen;
@property (nonatomic, assign) NSInteger playerViewTag;
@property (nonatomic, assign) ZFRotateType roateType;
@property (nonatomic, strong) UIView *blackView;
@property (nonatomic, strong) UIWindow *customWindow;

@end

@implementation ZFOrientationObserver

- (instancetype)init {
    self = [super init];
    if (self) {
        _rotateDuration = 0.30;
        _fullScreenMode = ZFFullScreenModeLandscape;
        _supportInterfaceOrientation = ZFInterfaceOrientationMaskAllButUpsideDown; // 支持的方向.
        _allowOrentitaionRotation = YES;
        _roateType = ZFRotateTypeNormal;
    }
    return self;
}

- (void)updateRotateView:(UIView *)rotateView
           containerView:(UIView *)containerView {
    self.playerView = rotateView;
    self.containerView = containerView;
}

- (void)cellModelRotateView:(UIView *)rotateView
           rotateViewAtCell:(UIView *)cell
              playerViewTag:(NSInteger)playerViewTag {
    self.roateType = ZFRotateTypeCell;
    self.playerView = rotateView;
    self.cell = cell;
    self.playerViewTag = playerViewTag;
}

- (void)cellOtherModelRotateView:(UIView *)rotateView containerView:(UIView *)containerView {
    self.roateType = ZFRotateTypeCellOther;
    self.playerView = rotateView;
    self.containerView = containerView;
}

- (void)dealloc {
    [self removeDeviceOrientationObserver];
    [self removeBlackView];
}

- (void)addBlackView:(UIView *)superview {
    if (!self.fullScreen) { return; }
    [superview insertSubview:self.blackView belowSubview:self.playerView];
    self.blackView.frame = superview.bounds;
}

- (void)removeBlackView {
    [self.blackView removeFromSuperview];
}

#pragma mark - DeviceObserver

- (void)addDeviceOrientationObserver {
    if (![UIDevice currentDevice].generatesDeviceOrientationNotifications) {
        // beginGeneratingDeviceOrientationNotifications, 之后, 设备旋转了才会发出通知来.
        [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    }
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDeviceOrientationChange) name:UIDeviceOrientationDidChangeNotification object:nil];
}

- (void)removeDeviceOrientationObserver {
    if (![UIDevice currentDevice].generatesDeviceOrientationNotifications) {
        // endGeneratingDeviceOrientationNotifications 之后, 设备旋转就不会发出通知了.
        [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIDeviceOrientationDidChangeNotification object:nil];
}

- (void)handleDeviceOrientationChange {
    // 如果, 是竖屏全屏, 或者不让旋转, 那么直接返回. 也就是, 屏幕旋转的后续没有了.
    if (!_allowOrentitaionRotation) { return; }
    if (self.fullScreenMode == ZFFullScreenModePortrait) { return; }
    // 首先检查一下设备的朝向是否有效.
    if (!UIDeviceOrientationIsValidInterfaceOrientation([UIDevice currentDevice].orientation)) {
        _currentOrientation = UIInterfaceOrientationUnknown;
        return;
    }
    // 如果当前的朝向, 和现有的朝向相同, 不用做任何变化.
    UIInterfaceOrientation currentOrientation = (UIInterfaceOrientation)[UIDevice currentDevice].orientation;
    if (_currentOrientation == currentOrientation) { return; }
    
    _currentOrientation = currentOrientation;
    switch (_currentOrientation) {
        case UIInterfaceOrientationPortrait: {
            if (![self isSupportedPortrait]) { return; }
            [self enterLandscapeFullScreen:UIInterfaceOrientationPortrait animated:YES];
        } break;
        case UIInterfaceOrientationLandscapeLeft: {
            if (![self isSupportedLandscapeLeft]) { return; }
            [self enterLandscapeFullScreen:UIInterfaceOrientationLandscapeLeft animated:YES];
        }break;
        case UIInterfaceOrientationLandscapeRight: {
            if (![self isSupportedLandscapeRight]) { return; }
            [self enterLandscapeFullScreen:UIInterfaceOrientationLandscapeRight animated:YES];
        }break;
        default: break;
    }
}

- (void)forceDeviceOrientation:(UIInterfaceOrientation)orientation animated:(BOOL)animated {
    UIView *superview = nil;
    if (UIInterfaceOrientationIsLandscape(orientation)) {
        /// It's not set from the other side of the screen to this side
        if (!self.isFullScreen) {
            self.playerView.frame = [self.playerView convertRect:self.playerView.frame toView:superview];
        }
        self.fullScreen = YES;
        superview = self.keyWindow;
    } else {
        if (!self.fullScreen) return;
        self.fullScreen = NO;
        if (self.roateType == ZFRotateTypeCell) superview = [self.cell viewWithTag:self.playerViewTag];
        else superview = self.containerView;
        [self removeBlackView];
    }
    if (self.orientationWillChange) self.orientationWillChange(self, self.isFullScreen);
    
    [superview addSubview:self.playerView];
    if (animated) {
        [UIView animateWithDuration:_rotateDuration animations:^{
            self.playerView.frame = superview.bounds;
            [self.playerView layoutIfNeeded];
            [self interfaceOrientation:orientation];
        } completion:^(BOOL finished) {
            [self addBlackView:superview];
            if (self.orientationDidChanged) self.orientationDidChanged(self, self.isFullScreen);
        }];
    } else {
        self.playerView.frame = superview.bounds;
        [self.playerView layoutIfNeeded];
        [UIView animateWithDuration:0 animations:^{
            [self interfaceOrientation:orientation];
        }];
        [self addBlackView:superview];
        if (self.orientationDidChanged) self.orientationDidChanged(self, self.isFullScreen);
    }
}

// 如果是左右朝向, 进入全屏, 其实就是把 playerView 加到了屏幕之上. 如果是竖屏朝向, 其实就是吧 palyerView 回复到原来记录的 containerView 上.
- (void)_enterLandscapeFullScreen:(UIInterfaceOrientation)orientation animated:(BOOL)animated {
    UIView *superview = nil;
    CGRect frame;
    if (UIInterfaceOrientationIsLandscape(orientation)) { // 如果进入到全屏, 就把playerView加到屏幕上.
        superview = self.keyWindow;
        if (!self.isFullScreen) {
            self.playerView.frame = [self.playerView convertRect:self.playerView.frame toView:superview];
        }
        [superview addSubview:self.playerView];
        self.fullScreen = YES;
        if (self.orientationWillChange) self.orientationWillChange(self, self.isFullScreen);
        
        // 这个 ZFFullViewController 的作用是什么.
        ZFFullViewController *fullVC = [[ZFFullViewController alloc] init];
        if (orientation == UIInterfaceOrientationLandscapeLeft) {
            fullVC.interfaceOrientationMask = UIInterfaceOrientationMaskLandscapeLeft;
        } else {
            fullVC.interfaceOrientationMask = UIInterfaceOrientationMaskLandscapeRight;
        }
        self.customWindow.rootViewController = fullVC;
    } else {
        self.fullScreen = NO;
        if (self.orientationWillChange) self.orientationWillChange(self, self.isFullScreen);
        
        // 这个 ZFFullViewController 的作用是什么.
        ZFFullViewController *fullVC = [[ZFFullViewController alloc] init];
        fullVC.interfaceOrientationMask = UIInterfaceOrientationMaskPortrait;
        self.customWindow.rootViewController = fullVC;
        
        if (self.roateType == ZFRotateTypeCell) {
            superview = [self.cell viewWithTag:self.playerViewTag];
        } else {
            superview = self.containerView;
        }
        [self removeBlackView];
    }
    frame = [superview convertRect:superview.bounds toView:self.keyWindow];
    
    if (animated) {
        [UIView animateWithDuration:_rotateDuration animations:^{ // 首先, 旋转并且缩小 PlayerView.
            self.playerView.transform = [self getTransformRotationAngle:orientation];
            [UIView animateWithDuration:self->_rotateDuration animations:^{
                self.playerView.frame = frame;
                [self.playerView layoutIfNeeded];
            }];
        } completion:^(BOOL finished) {
            [superview addSubview:self.playerView];
            self.playerView.frame = superview.bounds; // 在动画结束后, 把 playerView, 贴到父 View 上.
            [self addBlackView:superview];
            if (self.orientationDidChanged) self.orientationDidChanged(self, self.isFullScreen);
        }];
    } else {
        self.playerView.transform = [self getTransformRotationAngle:orientation];
        [superview addSubview:self.playerView];
        self.playerView.frame = superview.bounds;
        [self.playerView layoutIfNeeded];
        [self addBlackView:superview];
        if (self.orientationDidChanged) self.orientationDidChanged(self, self.isFullScreen);
    }
}

- (void)interfaceOrientation:(UIInterfaceOrientation)orientation {
    if ([[UIDevice currentDevice] respondsToSelector:@selector(setOrientation:)]) {
        SEL selector = NSSelectorFromString(@"setOrientation:");
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[UIDevice instanceMethodSignatureForSelector:selector]];
        [invocation setSelector:selector];
        [invocation setTarget:[UIDevice currentDevice]];
        UIInterfaceOrientation val = orientation;
        [invocation setArgument:&val atIndex:2];
        [invocation invoke];
    }
}

/// Gets the rotation Angle of the transformation.
- (CGAffineTransform)getTransformRotationAngle:(UIInterfaceOrientation)orientation {
    if (orientation == UIInterfaceOrientationPortrait) {
        return CGAffineTransformIdentity;
    } else if (orientation == UIInterfaceOrientationLandscapeLeft) {
        return CGAffineTransformMakeRotation(-M_PI_2);
    } else if(orientation == UIInterfaceOrientationLandscapeRight) {
        return CGAffineTransformMakeRotation(M_PI_2);
    }
    return CGAffineTransformIdentity;
}

#pragma mark - public

- (void)enterLandscapeFullScreen:(UIInterfaceOrientation)orientation animated:(BOOL)animated {
    if (self.fullScreenMode == ZFFullScreenModePortrait) return;
    _currentOrientation = orientation;
//    if (self.forceDeviceOrientation) {
//        [self forceDeviceOrientation:orientation animated:animated];
//    } else {
//        [self normalOrientation:orientation animated:animated];
//    }
     [self _enterLandscapeFullScreen:orientation animated:animated];
}

- (void)enterPortraitFullScreen:(BOOL)fullScreen animated:(BOOL)animated {
    if (self.fullScreenMode == ZFFullScreenModeLandscape) return;
    UIView *superview = nil;
    if (fullScreen) {
        superview = self.keyWindow;
        self.playerView.frame = [self.playerView convertRect:self.playerView.frame toView:superview];
        [superview addSubview:self.playerView];
        self.fullScreen = YES;
    } else {
        if (self.roateType == ZFRotateTypeCell) {
            superview = [self.cell viewWithTag:self.playerViewTag];
        } else {
            superview = self.containerView;
        }
        self.fullScreen = NO;
    }
    if (self.orientationWillChange) self.orientationWillChange(self, self.isFullScreen);
    CGRect frame = [superview convertRect:superview.bounds toView:self.keyWindow];
    if (animated) {
        [UIView animateWithDuration:_rotateDuration animations:^{
            self.playerView.frame = frame;
            [self.playerView layoutIfNeeded];
        } completion:^(BOOL finished) {
            [superview addSubview:self.playerView];
            self.playerView.frame = superview.bounds;
            if (self.orientationDidChanged) self.orientationDidChanged(self, self.isFullScreen);
        }];
    } else {
        [superview addSubview:self.playerView];
        self.playerView.frame = superview.bounds;
        [self.playerView layoutIfNeeded];
        if (self.orientationDidChanged) self.orientationDidChanged(self, self.isFullScreen);
    }
}

- (void)exitFullScreenWithAnimated:(BOOL)animated {
    if (self.fullScreenMode == ZFFullScreenModeLandscape) {
        [self enterLandscapeFullScreen:UIInterfaceOrientationPortrait animated:animated];
    } else if (self.fullScreenMode == ZFFullScreenModePortrait) {
        [self enterPortraitFullScreen:NO animated:animated];
    }
}

#pragma mark - private

/// is support portrait
- (BOOL)isSupportedPortrait {
    return _supportInterfaceOrientation & ZFInterfaceOrientationMaskPortrait;
}

/// is support landscapeLeft
- (BOOL)isSupportedLandscapeLeft {
    return _supportInterfaceOrientation & ZFInterfaceOrientationMaskLandscapeLeft;
}

/// is support landscapeRight
- (BOOL)isSupportedLandscapeRight {
    return _supportInterfaceOrientation & ZFInterfaceOrientationMaskLandscapeRight;
}

#pragma mark - getter

- (UIView *)blackView {
    if (!_blackView) {
        _blackView = [UIView new];
        _blackView.backgroundColor = [UIColor blackColor];
    }
    return _blackView;
}

- (UIWindow *)customWindow {
    if (!_customWindow) {
        if (@available(iOS 13.0, *)) {
            UIWindowScene *windowScene = nil;
            for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive) {
                    windowScene = (UIWindowScene *)scene;
                }
                if (!windowScene && [UIApplication sharedApplication].connectedScenes.count == 1) {
                    windowScene = (UIWindowScene *)scene;
                }
            }
            if (windowScene) {
                _customWindow = [[UIWindow alloc] initWithWindowScene:windowScene];
            } else {
                _customWindow = [[UIWindow alloc] initWithFrame:CGRectZero];
            }
        } else {
            _customWindow = [[UIWindow alloc] initWithFrame:CGRectZero];
        }
    }
    return _customWindow;
}

#pragma mark - setter

// 如果在锁屏的状态, 那么就更换对于屏幕旋转的监听.
- (void)setLockedScreen:(BOOL)lockedScreen {
    _lockedScreen = lockedScreen;
    if (lockedScreen) {
        [self removeDeviceOrientationObserver];
    } else {
        [self addDeviceOrientationObserver];
    }
}

- (UIView *)keyWindow {
    return [UIApplication sharedApplication].keyWindow;
}

// 在全屏的时候, 调用statusBar的更新.
// 这里调用了 Update 方法, 而实际上控制的如何显示的代码, 是写在各个 VC 里面.

- (void)setFullScreen:(BOOL)fullScreen {
    _fullScreen = fullScreen;
    [[UIWindow zf_currentViewController] setNeedsStatusBarAppearanceUpdate];
    [UIViewController attemptRotationToDeviceOrientation];
}

- (void)setStatusBarHidden:(BOOL)statusBarHidden {
    _statusBarHidden = statusBarHidden;
    [[UIWindow zf_currentViewController] setNeedsStatusBarAppearanceUpdate];
}

@end
