#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, ZFFullScreenMode) {
    ZFFullScreenModeAutomatic,  // Determine full screen mode automatically
    ZFFullScreenModeLandscape,  // Landscape full screen mode
    ZFFullScreenModePortrait    // Portrait full screen Model
};

/// Full screen mode on the view
typedef NS_ENUM(NSUInteger, ZFRotateType) {
    ZFRotateTypeNormal,         // Normal
    ZFRotateTypeCell,           // Cell
    ZFRotateTypeCellOther       // Cell mode add to other view
};

/**
 Rotation of support direction
 */
typedef NS_OPTIONS(NSUInteger, ZFInterfaceOrientationMask) {
    ZFInterfaceOrientationMaskPortrait = (1 << 0),
    ZFInterfaceOrientationMaskLandscapeLeft = (1 << 1),
    ZFInterfaceOrientationMaskLandscapeRight = (1 << 2),
    ZFInterfaceOrientationMaskPortraitUpsideDown = (1 << 3),
    ZFInterfaceOrientationMaskLandscape = (ZFInterfaceOrientationMaskLandscapeLeft | ZFInterfaceOrientationMaskLandscapeRight),
    ZFInterfaceOrientationMaskAll = (ZFInterfaceOrientationMaskPortrait | ZFInterfaceOrientationMaskLandscapeLeft | ZFInterfaceOrientationMaskLandscapeRight | ZFInterfaceOrientationMaskPortraitUpsideDown),
    ZFInterfaceOrientationMaskAllButUpsideDown = (ZFInterfaceOrientationMaskPortrait | ZFInterfaceOrientationMaskLandscapeLeft | ZFInterfaceOrientationMaskLandscapeRight),
};

// 这个类主要就是监听设备的旋转, 然后会调用对于 palyerView 的一个动画, 这个动画, 可以完成对于全屏切换的效果.

@interface ZFOrientationObserver : NSObject

/// update the rotateView and containerView.
- (void)updateRotateView:(UIView *)rotateView
           containerView:(UIView *)containerView;

/// list play
- (void)cellModelRotateView:(UIView *)rotateView
           rotateViewAtCell:(UIView *)cell
              playerViewTag:(NSInteger)playerViewTag;

/// cell other view rotation
- (void)cellOtherModelRotateView:(UIView *)rotateView
                   containerView:(UIView *)containerView;

/// Container view of a full screen state player.
@property (nonatomic, strong) UIView *keyWindow;

/// Container view of a small screen state player.
@property (nonatomic, weak) UIView *containerView;

/// If the full screen.
@property (nonatomic, readonly, getter=isFullScreen) BOOL fullScreen;

/// Use device orientation, default NO.
@property (nonatomic, assign) BOOL forceDeviceOrientation;

/// Lock screen orientation
@property (nonatomic, getter=isLockedScreen) BOOL lockedScreen;

// 旋转的回调. 目前来说, 是触发自定义旋转. 传递到 ControlView 上, 然后让 ControlView 重新布局.
@property (nonatomic, copy, nullable) void(^orientationWillChange)(ZFOrientationObserver *observer, BOOL isFullScreen);
@property (nonatomic, copy, nullable) void(^orientationDidChanged)(ZFOrientationObserver *observer, BOOL isFullScreen);

@property (nonatomic) ZFFullScreenMode fullScreenMode; // 在哪种方向上全屏

/// rotate duration, default is 0.30
@property (nonatomic) float rotateDuration;

/// The statusbar hidden.
@property (nonatomic, getter=isStatusBarHidden) BOOL statusBarHidden;


// readonly. 只能由方法改变, 或者由内部机制改变.
@property (nonatomic, readonly) UIInterfaceOrientation currentOrientation;

/// Whether allow the video orientation rotate.
/// default is YES.
// 如果不让旋转, 那么就是不监听设备的旋转了, 但是按全屏按钮, 还是会全屏的.
@property (nonatomic) BOOL allowOrentitaionRotation;

/// The support Interface Orientation,default is ZFInterfaceOrientationMaskAllButUpsideDown
@property (nonatomic, assign) ZFInterfaceOrientationMask supportInterfaceOrientation;

// 这两个方法, 完全交给了外界. 由外界来控制, 到底应不应该监听屏幕的旋转.
- (void)addDeviceOrientationObserver;
- (void)removeDeviceOrientationObserver;

/// Enter the fullScreen while the ZFFullScreenMode is ZFFullScreenModeLandscape.
- (void)enterLandscapeFullScreen:(UIInterfaceOrientation)orientation animated:(BOOL)animated;

/// Enter the fullScreen while the ZFFullScreenMode is ZFFullScreenModePortrait.
- (void)enterPortraitFullScreen:(BOOL)fullScreen animated:(BOOL)animated;

/// Exit the fullScreen.
- (void)exitFullScreenWithAnimated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END

