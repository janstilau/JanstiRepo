#import "ZFPlayerController.h"
#import <objc/runtime.h>
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>
#import "UIScrollView+ZFPlayer.h"
#import "ZFReachabilityManager.h"
#import "ZFPlayer.h"

@interface ZFPlayerController ()

@property (nonatomic, strong) ZFPlayerNotification *notification;
@property (nonatomic, weak) UIScrollView *scrollView;
@property (nonatomic, strong) UISlider *volumeViewSlider;
@property (nonatomic, assign) NSInteger containerViewTag;
@property (nonatomic, assign) ZFPlayerContainerType containerType;
/// The player's small container view.
@property (nonatomic, strong) ZFFloatView *smallFloatView;
/// Whether the small window is displayed.
@property (nonatomic, assign) BOOL isSmallFloatViewShow;
/// The indexPath is playing.
@property (nonatomic, nullable) NSIndexPath *playingIndexPath;

@end

@implementation ZFPlayerController

- (instancetype)init {
    self = [super init];
    if (self) {
        @weakify(self)
        [[ZFReachabilityManager sharedManager] startMonitoring];
        [[ZFReachabilityManager sharedManager] setReachabilityStatusChangeBlock:^(ZFReachabilityStatus status) {
            @strongify(self)
            if ([self.controlView respondsToSelector:@selector(videoPlayer:reachabilityChanged:)]) {
                [self.controlView videoPlayer:self reachabilityChanged:status];
            }
        }];
        [self configureVolume];
    }
    return self;
}

// 这里, MPVolumeView 这个类是直接和系统音量控制挂钩的.
// 当音量变化的时候, 这个view的滑块变化, 当滑块变化的时候, 音量变化.
// ZFPlayer 中, 直接获取到该类. 用作 Player 控制系统的音量的入口.
- (void)configureVolume {
    MPVolumeView *volumeView = [[MPVolumeView alloc] init];
    self.volumeViewSlider = nil;
    for (UIView *view in [volumeView subviews]){
        if ([view.class.description isEqualToString:@"MPVolumeSlider"]){
            self.volumeViewSlider = (UISlider *)view;
            break;
        }
    }
}

- (void)dealloc {
    [self.playerManager stop];
}

+ (instancetype)playerWithPlayerManager:(id<ZFPlayerMediaPlayback>)playerManager containerView:(nonnull UIView *)containerView {
    ZFPlayerController *player = [[self alloc] initWithPlayerManager:playerManager containerView:containerView];
    return player;
}

+ (instancetype)playerWithScrollView:(UIScrollView *)scrollView playerManager:(id<ZFPlayerMediaPlayback>)playerManager containerViewTag:(NSInteger)containerViewTag {
    ZFPlayerController *player = [[self alloc] initWithScrollView:scrollView playerManager:playerManager containerViewTag:containerViewTag];
    return player;
}

+ (instancetype)playerWithScrollView:(UIScrollView *)scrollView playerManager:(id<ZFPlayerMediaPlayback>)playerManager containerView:(UIView *)containerView {
    ZFPlayerController *player = [[self alloc] initWithScrollView:scrollView playerManager:playerManager containerView:containerView];
    return player;
}

- (instancetype)initWithPlayerManager:(id<ZFPlayerMediaPlayback>)playerManager containerView:(nonnull UIView *)containerView {
    ZFPlayerController *player = [self init];
    player.containerView = containerView;
    player.playerManager = playerManager;
    player.containerType = ZFPlayerContainerTypeView;
    return player;
}

// 最终的 designatedInit 方法. 所有的初始化都会聚集到该方法.
- (instancetype)initWithScrollView:(UIScrollView *)scrollView playerManager:(id<ZFPlayerMediaPlayback>)playerManager containerViewTag:(NSInteger)containerViewTag {
    ZFPlayerController *player = [self init];
    player.scrollView = scrollView;
    player.containerViewTag = containerViewTag;
    player.playerManager = playerManager;
    player.containerType = ZFPlayerContainerTypeCell;
    return player;
}

// 最终的 designatedInit 方法. 所有的初始化都会聚集到该方法.
- (instancetype)initWithScrollView:(UIScrollView *)scrollView playerManager:(id<ZFPlayerMediaPlayback>)playerManager
                     containerView:(UIView *)containerView {
    ZFPlayerController *player = [self init];
    player.scrollView = scrollView;
    player.containerView = containerView;
    player.playerManager = playerManager;
    player.containerType = ZFPlayerContainerTypeView;
    return player;
}

/*
AVAudioSessionCategoryAmbient
使用这个category的应用会随着静音键和屏幕关闭而静音。并且不会中止其它应用播放声音，可以和其它自带应用如iPod，safari等同时播放声音。注意：该Category无法在后台播放声音，所以开启应用打断音乐程序播放音乐应该使用这个Category。
AVAudioSessionCategorySoloAmbient
类似于AVAudioSessionCategoryAmbient 不同之处在于它会中止其它应用播放声音。 这个category为默认category。该Category无法在后台播放声音
AVAudioSessionCategoryPlayback
使用这个category的应用不会随着静音键和屏幕关闭而静音。可在后台播放声音
AVAudioSessionCategoryRecord
用于需要录音的应用，设置该category后，除了来电铃声，闹钟或日历提醒之外的其它系统声音都不会被播放。该Category只提供单纯录音功能。
AVAudioSessionCategoryPlayAndRecord
用于既需要播放声音又需要录音的应用，语音聊天应用(如微信）应该使用这个category。该Category提供录音和播放功能。如果你的应用需要用到iPhone上的听筒，该category是你唯一的选择，在该Category下声音的默认出口为听筒（在没有外接设备的情况下）。
 */

- (void)playerManagerCallbcak {
    
    // PlayerManager 中, 监听播放的各种状态, 然后通过回调的方式传出. PlayerController 里面, 将这些回调, 传递到 ControlView 中.
    // 然后, ControlView 那里, 可以直接调用 PlayerController 的播放控制的方法. 而这些方法, 又转移到了 PlayerManager 中.
    
    @weakify(self)
    self.playerManager.playerPrepareToPlay = ^(id<ZFPlayerMediaPlayback>  _Nonnull asset, NSURL * _Nonnull assetURL) {
        @strongify(self)
        self.playerManager.view.hidden = NO;
        [self.notification addNotification];
        [self addDeviceOrientationObserver];
        if (self.scrollView) {
            self.scrollView.zf_stopPlay = NO;
        }
        [self layoutPlayerSubViews];
        if (self.playerPrepareToPlay) self.playerPrepareToPlay(asset,assetURL);
        if ([self.controlView respondsToSelector:@selector(videoPlayer:prepareToPlay:)]) {
            [self.controlView videoPlayer:self prepareToPlay:assetURL];
        }
    };
    

    self.playerManager.playerReadyToPlay = ^(id<ZFPlayerMediaPlayback>  _Nonnull asset, NSURL * _Nonnull assetURL) {
        @strongify(self)
        if (self.playerReadyToPlay) self.playerReadyToPlay(asset,assetURL);
        if (!self.customAudioSession) {
            // Apps using this category don't mute when the phone's mute button is turned on, but play sound when the phone is silent
            [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionAllowBluetooth error:nil];
            // YES if the session’s active state was changed successfully, or NO if it was not.
            // 也就是说, 在上面的setCategory设置之后, 要主动调用 setActive 让上面的设置生效.
            [[AVAudioSession sharedInstance] setActive:YES error:nil];
        }
        if (self.hiddenOnWindow) self.pauseByEvent = YES;
    };
    
    self.playerManager.playerPlayTimeChanged = ^(id<ZFPlayerMediaPlayback>  _Nonnull asset, NSTimeInterval currentTime, NSTimeInterval duration) {
        @strongify(self)
        if (self.playerPlayTimeChanged) self.playerPlayTimeChanged(asset,currentTime,duration);
        if ([self.controlView respondsToSelector:@selector(videoPlayer:currentTime:totalTime:)]) {
            [self.controlView videoPlayer:self currentTime:currentTime totalTime:duration];
        }
    };
    
    self.playerManager.playerBufferTimeChanged = ^(id<ZFPlayerMediaPlayback>  _Nonnull asset, NSTimeInterval bufferTime) {
        @strongify(self)
        if (self.playerBufferTimeChanged) self.playerBufferTimeChanged(asset,bufferTime);
        if ([self.controlView respondsToSelector:@selector(videoPlayer:bufferTime:)]) {
            [self.controlView videoPlayer:self bufferTime:bufferTime];
        }
    };
    
    self.playerManager.playerPlayStateChanged = ^(id  _Nonnull asset, ZFPlayerPlaybackState playState) {
        @strongify(self)
        if (self.playerPlayStateChanged) self.playerPlayStateChanged(asset, playState);
        if ([self.controlView respondsToSelector:@selector(videoPlayer:playStateChanged:)]) {
            [self.controlView videoPlayer:self playStateChanged:playState];
        }
    };
    
    self.playerManager.playerLoadStateChanged = ^(id  _Nonnull asset, ZFPlayerLoadState loadState) {
        @strongify(self)
        if (self.playerLoadStateChanged) self.playerLoadStateChanged(asset, loadState);
        if ([self.controlView respondsToSelector:@selector(videoPlayer:loadStateChanged:)]) {
            [self.controlView videoPlayer:self loadStateChanged:loadState];
        }
    };
    
    self.playerManager.playerDidToEnd = ^(id  _Nonnull asset) {
        @strongify(self)
        if (self.playerDidToEnd) self.playerDidToEnd(asset);
        if ([self.controlView respondsToSelector:@selector(videoPlayerPlayEnd:)]) {
            [self.controlView videoPlayerPlayEnd:self];
        }
    };
    
    self.playerManager.playerPlayFailed = ^(id<ZFPlayerMediaPlayback>  _Nonnull asset, id  _Nonnull error) {
        @strongify(self)
        if (self.playerPlayFailed) self.playerPlayFailed(asset, error);
        if ([self.controlView respondsToSelector:@selector(videoPlayerPlayFailed:error:)]) {
            [self.controlView videoPlayerPlayFailed:self error:error];
        }
    };
    
    self.playerManager.presentationSizeChanged = ^(id<ZFPlayerMediaPlayback>  _Nonnull asset, CGSize size){
        @strongify(self)
        // 如果是自动进行全屏的判断, 那么会根据视屏的宽高来设置竖屏全屏还是横屏全屏.
        if (self.orientationObserver.fullScreenMode == ZFFullScreenModeAutomatic) {
            if (size.width > size.height) {
                self.orientationObserver.fullScreenMode = ZFFullScreenModeLandscape;
            } else {
                self.orientationObserver.fullScreenMode = ZFFullScreenModePortrait;
            }
        }
        if (self.presentationSizeChanged) self.presentationSizeChanged(asset, size);
        if ([self.controlView respondsToSelector:@selector(videoPlayer:presentationSizeChanged:)]) {
            [self.controlView videoPlayer:self presentationSizeChanged:size];
        }
    };
}


// 在这里, 进行了 View 的装填的工作.
- (void)layoutPlayerSubViews {
    if (self.containerView && self.playerManager.view) {
        UIView *superview = nil;
        if (self.isFullScreen) { // 如果是全屏, 就是播放视图, 装到 KeyWindow 里面.
            superview = self.orientationObserver.keyWindow;
        } else if (self.containerView) { // 否则, 就传到传进来的 ContainerView 里面.
            superview = self.containerView;
        }
        [superview addSubview:self.playerManager.view];
        [self.playerManager.view addSubview:self.controlView]; // 这里, 进行了 ControlView 的添加工作.
        
        // 这里, 做了 playerView 和 controlView 的适配工作.
        self.playerManager.view.frame = superview.bounds;
        self.playerManager.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.controlView.frame = self.playerManager.view.bounds;
        self.controlView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.orientationObserver updateRotateView:self.playerManager.view containerView:self.containerView];
    }
}

#pragma mark - getter

// 目前来说, notification 的各个回调, 没有用到太多.
- (ZFPlayerNotification *)notification {
    if (!_notification) {
        _notification = [[ZFPlayerNotification alloc] init];
        @weakify(self)
        _notification.willResignActive = ^(ZFPlayerNotification * registrar) {
            @strongify(self)
            if (self.isHiddenOnWindow) return; // 如果, 不在屏幕上显示, 不做处理.
            if (self.pauseWhenAppResignActive && self.playerManager.isPlaying) {
                self.pauseByEvent = YES;
            } else {
                [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
                [[AVAudioSession sharedInstance] setActive:YES error:nil];
            }
            self.orientationObserver.lockedScreen = YES;
            [[UIApplication sharedApplication].keyWindow endEditing:YES];
        };
        _notification.didBecomeActive = ^(ZFPlayerNotification * _Nonnull registrar) {
            @strongify(self)
            if (self.isHiddenOnWindow) return;
            if (self.isPauseByEvent) self.pauseByEvent = NO;
            self.orientationObserver.lockedScreen = NO;
        };
        _notification.oldDeviceUnavailable = ^(ZFPlayerNotification * _Nonnull registrar) {
            @strongify(self)
            if (self.playerManager.isPlaying) {
                [self.playerManager play];
            }
        };
    }
    return _notification;
}

- (ZFFloatView *)smallFloatView {
    if (!_smallFloatView) {
        _smallFloatView = [[ZFFloatView alloc] init];
        _smallFloatView.parentView = [UIApplication sharedApplication].keyWindow;
        _smallFloatView.hidden = YES;
    }
    return _smallFloatView;
}

#pragma mark - setter

- (void)setPlayerManager:(id<ZFPlayerMediaPlayback>)currentPlayerManager {
    if (!currentPlayerManager) return;
    if (_playerManager.isPreparedToPlay) {
        [_playerManager stop];
        [_playerManager.view removeFromSuperview];
        [self.orientationObserver removeDeviceOrientationObserver];
        [self.gestureControl removeGestureToView:self.playerManager.view];
    }
    _playerManager = currentPlayerManager;
    _playerManager.view.hidden = YES;
    self.gestureControl.disableTypes = self.disableGestureTypes;
    [self.gestureControl addGestureToView:currentPlayerManager.view];
    [self playerManagerCallbcak];
    [self.orientationObserver updateRotateView:currentPlayerManager.view containerView:self.containerView];
    self.controlView.player = self;
    [self layoutPlayerSubViews];
}

- (void)setContainerView:(UIView *)containerView {
    _containerView = containerView;
    if (self.scrollView) {
        self.scrollView.zf_containerView = containerView;
    }
    if (!containerView) return;
    containerView.userInteractionEnabled = YES;
    [self layoutPlayerSubViews];
}

- (void)setControlView:(UIView<ZFPlayerMediaControl> *)controlView {
    _controlView = controlView;
    if (!controlView) return;
    controlView.player = self;
    [self layoutPlayerSubViews];
}

- (void)setContainerType:(ZFPlayerContainerType)containerType {
    _containerType = containerType;
    if (self.scrollView) {
        self.scrollView.zf_containerType = containerType;
    }
}

@end

@implementation ZFPlayerController (ZFPlayerTimeControl)

- (NSTimeInterval)currentTime {
    return self.playerManager.currentTime;
}

- (NSTimeInterval)totalTime {
    return self.playerManager.totalTime;
}

- (NSTimeInterval)bufferTime {
    return self.playerManager.bufferTime;
}

- (float)progress {
    if (self.totalTime == 0) return 0;
    return self.currentTime/self.totalTime;
}

- (float)bufferProgress {
    if (self.totalTime == 0) return 0;
    return self.bufferTime/self.totalTime;
}

- (void)seekToTime:(NSTimeInterval)time completionHandler:(void (^)(BOOL))completionHandler {
    [self.playerManager seekToTime:time completionHandler:completionHandler];
}

@end

@implementation ZFPlayerController (ZFPlayerPlaybackControl)

- (void)playTheNext {
    if (self.assetURLs.count > 0) {
        NSInteger index = self.currentPlayIndex + 1;
        if (index >= self.assetURLs.count) return;
        NSURL *assetURL = [self.assetURLs objectAtIndex:index];
        self.currentAssetURL = assetURL;
        self.currentPlayIndex = [self.assetURLs indexOfObject:assetURL];
    }
}

- (void)playThePrevious {
    if (self.assetURLs.count > 0) {
        NSInteger index = self.currentPlayIndex - 1;
        if (index < 0) return;
        NSURL *assetURL = [self.assetURLs objectAtIndex:index];
        self.currentAssetURL = assetURL;
        self.currentPlayIndex = [self.assetURLs indexOfObject:assetURL];
    }
}

- (void)playTheIndex:(NSInteger)index {
    if (self.assetURLs.count > 0) {
        if (index >= self.assetURLs.count) return;
        NSURL *assetURL = [self.assetURLs objectAtIndex:index];
        self.currentAssetURL = assetURL;
        self.currentPlayIndex = index;
    }
}

- (void)stop {
    [self.notification removeNotification];
    [self.orientationObserver removeDeviceOrientationObserver];
    if (self.isFullScreen && self.exitFullScreenWhenStop) {
        [self.orientationObserver exitFullScreenWithAnimated:NO];
    }
    [self.playerManager stop];
    [self.playerManager.view removeFromSuperview];
    if (self.scrollView) {
        self.scrollView.zf_stopPlay = YES;
    }
}

- (void)replaceCurrentPlayerManager:(id<ZFPlayerMediaPlayback>)playerManager {
    self.playerManager = playerManager;
}

//// Add video to the cell
- (void)addPlayerViewToCell {
    self.isSmallFloatViewShow = NO;
    self.smallFloatView.hidden = YES;
    UIView *cell = [self.scrollView zf_getCellForIndexPath:self.playingIndexPath];
    self.containerView = [cell viewWithTag:self.containerViewTag];
    [self.containerView addSubview:self.playerManager.view];
    self.playerManager.view.frame = self.containerView.bounds;
    self.playerManager.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.orientationObserver cellModelRotateView:self.playerManager.view rotateViewAtCell:cell playerViewTag:self.containerViewTag];
    if ([self.controlView respondsToSelector:@selector(videoPlayer:floatViewShow:)]) {
        [self.controlView videoPlayer:self floatViewShow:NO];
    }
}

//// Add video to the container view
- (void)addPlayerViewToContainerView:(UIView *)containerView {
    self.isSmallFloatViewShow = NO;
    self.smallFloatView.hidden = YES;
    self.containerView = containerView;
    [self.containerView addSubview:self.playerManager.view];
    self.playerManager.view.frame = self.containerView.bounds;
    self.playerManager.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.orientationObserver cellOtherModelRotateView:self.playerManager.view containerView:self.containerView];
    if ([self.controlView respondsToSelector:@selector(videoPlayer:floatViewShow:)]) {
        [self.controlView videoPlayer:self floatViewShow:NO];
    }
}

/// Add to the keyWindow
- (void)addPlayerViewToKeyWindow {
    self.isSmallFloatViewShow = YES;
    self.smallFloatView.hidden = NO;
    [self.smallFloatView addSubview:self.playerManager.view];
    self.playerManager.view.frame = self.smallFloatView.bounds;
    self.playerManager.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.orientationObserver cellOtherModelRotateView:self.playerManager.view containerView:self.smallFloatView];
    if ([self.controlView respondsToSelector:@selector(videoPlayer:floatViewShow:)]) {
        [self.controlView videoPlayer:self floatViewShow:YES];
    }
}

- (void)stopCurrentPlayingView {
    if (self.containerView) {
        [self stop];
        self.isSmallFloatViewShow = NO;
        if (self.smallFloatView) self.smallFloatView.hidden = YES;
    }
}

- (void)stopCurrentPlayingCell {
    if (self.scrollView.zf_playingIndexPath) {
        [self stop];
        self.isSmallFloatViewShow = NO;
        self.playingIndexPath = nil;
        if (self.smallFloatView) self.smallFloatView.hidden = YES;
    }
}

#pragma mark - getter

- (NSURL *)currentAssetURL {
    return objc_getAssociatedObject(self, _cmd);
}

- (NSArray<NSURL *> *)assetURLs {
    return objc_getAssociatedObject(self, _cmd);
}

- (BOOL)isLastAssetURL {
    if (self.assetURLs.count > 0) {
        return self.currentAssetURL == self.assetURLs.lastObject;
    }
    return NO;
}

- (BOOL)isFirstAssetURL {
    if (self.assetURLs.count > 0) {
        return self.currentAssetURL == self.assetURLs.firstObject;
    }
    return NO;
}

- (BOOL)isPauseByEvent {
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

- (float)brightness {
    return [UIScreen mainScreen].brightness;
}

- (float)volume {
    CGFloat volume = self.volumeViewSlider.value;
    if (volume == 0) {
        volume = [[AVAudioSession sharedInstance] outputVolume];
    }
    return volume;
}

- (BOOL)isMuted {
    return self.volume == 0;
}

- (float)lastVolumeValue {
    return [objc_getAssociatedObject(self, _cmd) floatValue];
}

- (ZFPlayerPlaybackState)playState {
    return self.playerManager.playState;
}

- (BOOL)isPlaying {
    return self.playerManager.isPlaying;
}

- (BOOL)pauseWhenAppResignActive {
    NSNumber *number = objc_getAssociatedObject(self, _cmd);
    if (number) return number.boolValue;
    self.pauseWhenAppResignActive = YES;
    return YES;
}

- (void (^)(id<ZFPlayerMediaPlayback> _Nonnull, NSURL * _Nonnull))playerPrepareToPlay {
    return objc_getAssociatedObject(self, _cmd);
}

- (void (^)(id<ZFPlayerMediaPlayback> _Nonnull, NSURL * _Nonnull))playerReadyToPlay {
    return objc_getAssociatedObject(self, _cmd);
}

- (void (^)(id<ZFPlayerMediaPlayback> _Nonnull, NSTimeInterval, NSTimeInterval))playerPlayTimeChanged {
    return objc_getAssociatedObject(self, _cmd);
}

- (void (^)(id<ZFPlayerMediaPlayback> _Nonnull, NSTimeInterval))playerBufferTimeChanged {
    return objc_getAssociatedObject(self, _cmd);
}

- (void (^)(id<ZFPlayerMediaPlayback> _Nonnull, ZFPlayerPlaybackState))playerPlayStateChanged {
    return objc_getAssociatedObject(self, _cmd);
}

- (void (^)(id<ZFPlayerMediaPlayback> _Nonnull, ZFPlayerLoadState))playerLoadStateChanged {
    return objc_getAssociatedObject(self, _cmd);
}

- (void (^)(id<ZFPlayerMediaPlayback> _Nonnull))playerDidToEnd {
    return objc_getAssociatedObject(self, _cmd);
}

- (void (^)(id<ZFPlayerMediaPlayback> _Nonnull, id _Nonnull))playerPlayFailed {
    return objc_getAssociatedObject(self, _cmd);
}

- (void (^)(id<ZFPlayerMediaPlayback> _Nonnull, CGSize ))presentationSizeChanged {
    return objc_getAssociatedObject(self, _cmd);
}

- (NSInteger)currentPlayIndex {
    return [objc_getAssociatedObject(self, _cmd) integerValue];
}

- (BOOL)isHiddenOnWindow {
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

- (BOOL)customAudioSession {
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

#pragma mark - setter

- (void)setCurrentAssetURL:(NSURL *)assetURL {
    objc_setAssociatedObject(self, @selector(currentAssetURL), assetURL, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    self.playerManager.assetURL = assetURL;
}

- (void)setAssetURLs:(NSArray<NSURL *> * _Nullable)assetURLs {
    objc_setAssociatedObject(self, @selector(assetURLs), assetURLs, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)setVolume:(float)volume {
    volume = MIN(MAX(0, volume), 1);
    objc_setAssociatedObject(self, @selector(volume), @(volume), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    self.volumeViewSlider.value = volume;
}

- (void)setMuted:(BOOL)muted {
    if (muted) {
        if (self.volumeViewSlider.value > 0) {
            self.lastVolumeValue = self.volumeViewSlider.value;
        }
        self.volumeViewSlider.value = 0;
    } else {
        self.volumeViewSlider.value = self.lastVolumeValue;
    }
}

- (void)setLastVolumeValue:(float)lastVolumeValue {
    objc_setAssociatedObject(self, @selector(lastVolumeValue), @(lastVolumeValue), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)setBrightness:(float)brightness {
    brightness = MIN(MAX(0, brightness), 1);
    objc_setAssociatedObject(self, @selector(brightness), @(brightness), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [UIScreen mainScreen].brightness = brightness;
}

// 在 pauseByEvent 的 set 方法里面, 做了真正的播放的控制.
- (void)setPauseByEvent:(BOOL)pauseByEvent {
    objc_setAssociatedObject(self, @selector(isPauseByEvent), @(pauseByEvent), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (pauseByEvent) {
        [self.playerManager pause];
    } else {
        [self.playerManager play];
    }
}

- (void)setPauseWhenAppResignActive:(BOOL)pauseWhenAppResignActive {
    objc_setAssociatedObject(self, @selector(pauseWhenAppResignActive), @(pauseWhenAppResignActive), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)setPlayerPrepareToPlay:(void (^)(id<ZFPlayerMediaPlayback> _Nonnull, NSURL * _Nonnull))playerPrepareToPlay {
    objc_setAssociatedObject(self, @selector(playerPrepareToPlay), playerPrepareToPlay, OBJC_ASSOCIATION_COPY);
}

- (void)setPlayerReadyToPlay:(void (^)(id<ZFPlayerMediaPlayback> _Nonnull, NSURL * _Nonnull))playerReadyToPlay {
    objc_setAssociatedObject(self, @selector(playerReadyToPlay), playerReadyToPlay, OBJC_ASSOCIATION_COPY);
}

- (void)setPlayerPlayTimeChanged:(void (^)(id<ZFPlayerMediaPlayback> _Nonnull, NSTimeInterval, NSTimeInterval))playerPlayTimeChanged {
    objc_setAssociatedObject(self, @selector(playerPlayTimeChanged), playerPlayTimeChanged, OBJC_ASSOCIATION_COPY);
}

- (void)setPlayerBufferTimeChanged:(void (^)(id<ZFPlayerMediaPlayback> _Nonnull, NSTimeInterval))playerBufferTimeChanged {
    objc_setAssociatedObject(self, @selector(playerBufferTimeChanged), playerBufferTimeChanged, OBJC_ASSOCIATION_COPY);
}

- (void)setPlayerPlayStateChanged:(void (^)(id<ZFPlayerMediaPlayback> _Nonnull, ZFPlayerPlaybackState))playerPlayStateChanged {
    objc_setAssociatedObject(self, @selector(playerPlayStateChanged), playerPlayStateChanged, OBJC_ASSOCIATION_COPY);
}

- (void)setPlayerLoadStateChanged:(void (^)(id<ZFPlayerMediaPlayback> _Nonnull, ZFPlayerLoadState))playerLoadStateChanged {
    objc_setAssociatedObject(self, @selector(playerLoadStateChanged), playerLoadStateChanged, OBJC_ASSOCIATION_COPY);
}

- (void)setPlayerDidToEnd:(void (^)(id<ZFPlayerMediaPlayback> _Nonnull))playerDidToEnd {
    objc_setAssociatedObject(self, @selector(playerDidToEnd), playerDidToEnd, OBJC_ASSOCIATION_COPY);
}

- (void)setPlayerPlayFailed:(void (^)(id<ZFPlayerMediaPlayback> _Nonnull, id _Nonnull))playerPlayFailed {
    objc_setAssociatedObject(self, @selector(playerPlayFailed), playerPlayFailed, OBJC_ASSOCIATION_COPY);
}

- (void)setPresentationSizeChanged:(void (^)(id<ZFPlayerMediaPlayback> _Nonnull, CGSize))presentationSizeChanged {
    objc_setAssociatedObject(self, @selector(presentationSizeChanged), presentationSizeChanged, OBJC_ASSOCIATION_COPY);
}

- (void)setCurrentPlayIndex:(NSInteger)currentPlayIndex {
    objc_setAssociatedObject(self, @selector(currentPlayIndex), @(currentPlayIndex), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)setHiddenOnWindow:(BOOL)hidden {
    objc_setAssociatedObject(self, @selector(isHiddenOnWindow), @(hidden), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (self.scrollView) self.scrollView.zf_hiddenOnWindow = hidden; // ScrollView 有着相关的逻辑, 也依靠是否显示的值.
    if (!self.playerManager.isPreparedToPlay) return; // 如果现在视频不是在已经准备完善的状态, 不做处理.
    if (hidden) {
        // 如果, 不显示在屏幕上, 那就停止监听屏幕的转动. 并且控制播放器的暂停
        [self removeDeviceOrientationObserver];
        if (self.playerManager.isPlaying) self.pauseByEvent = YES;
    } else {
        [self addDeviceOrientationObserver];
        if (self.isPauseByEvent) self.pauseByEvent = NO;
    }
}

- (void)setCustomAudioSession:(BOOL)customAudioSession {
    objc_setAssociatedObject(self, @selector(customAudioSession), @(customAudioSession), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

@implementation ZFPlayerController (ZFPlayerOrientationRotation)

- (void)addDeviceOrientationObserver {
    [self.orientationObserver addDeviceOrientationObserver];
}

- (void)removeDeviceOrientationObserver {
    [self.orientationObserver removeDeviceOrientationObserver];
}

- (void)enterLandscapeFullScreen:(UIInterfaceOrientation)orientation animated:(BOOL)animated {
    self.orientationObserver.fullScreenMode = ZFFullScreenModeLandscape;
    [self.orientationObserver enterLandscapeFullScreen:orientation animated:animated];
}

- (void)enterPortraitFullScreen:(BOOL)fullScreen animated:(BOOL)animated {
    self.orientationObserver.fullScreenMode = ZFFullScreenModePortrait;
    [self.orientationObserver enterPortraitFullScreen:fullScreen animated:animated];
}

- (void)enterFullScreen:(BOOL)fullScreen animated:(BOOL)animated {
    if (self.orientationObserver.fullScreenMode == ZFFullScreenModePortrait) {
        [self.orientationObserver enterPortraitFullScreen:fullScreen animated:animated];
    } else {
        UIInterfaceOrientation orientation = UIInterfaceOrientationUnknown;
        orientation = fullScreen? UIInterfaceOrientationLandscapeRight : UIInterfaceOrientationPortrait;
        [self.orientationObserver enterLandscapeFullScreen:orientation animated:animated];
    }
}

- (BOOL)shouldForceDeviceOrientation {
    if (self.forceDeviceOrientation) return YES;
    return NO;
}

#pragma mark - getter

// 手机的转向由一个专门的类进行处理. 
- (ZFOrientationObserver *)orientationObserver {
    @weakify(self)
    ZFOrientationObserver *orientationObserver = objc_getAssociatedObject(self, _cmd);
    if (!orientationObserver) {
        orientationObserver = [[ZFOrientationObserver alloc] init];
        orientationObserver.orientationWillChange = ^(ZFOrientationObserver * _Nonnull observer, BOOL isFullScreen) {
            @strongify(self)
            if (self.orientationWillChange) self.orientationWillChange(self, isFullScreen);
            if ([self.controlView respondsToSelector:@selector(videoPlayer:orientationWillChange:)]) {
                [self.controlView videoPlayer:self orientationWillChange:observer];
            }
            [self.controlView setNeedsLayout];
            [self.controlView layoutIfNeeded];
        };
        orientationObserver.orientationDidChanged = ^(ZFOrientationObserver * _Nonnull observer, BOOL isFullScreen) {
            @strongify(self)
            if (self.orientationDidChanged) self.orientationDidChanged(self, isFullScreen);
            if ([self.controlView respondsToSelector:@selector(videoPlayer:orientationDidChanged:)]) {
                [self.controlView videoPlayer:self orientationDidChanged:observer];
            }
        };
        objc_setAssociatedObject(self, _cmd, orientationObserver, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return orientationObserver;
}

- (void (^)(ZFPlayerController * _Nonnull, BOOL))orientationWillChange {
    return objc_getAssociatedObject(self, _cmd);
}

- (void (^)(ZFPlayerController * _Nonnull, BOOL))orientationDidChanged {
    return objc_getAssociatedObject(self, _cmd);
}

- (BOOL)isFullScreen {
    return self.orientationObserver.isFullScreen;
}

- (BOOL)exitFullScreenWhenStop {
    NSNumber *number = objc_getAssociatedObject(self, _cmd);
    if (number) return number.boolValue;
    self.exitFullScreenWhenStop = YES;
    return YES;
}

- (UIInterfaceOrientation)currentOrientation {
    return self.orientationObserver.currentOrientation;
}

- (BOOL)isStatusBarHidden {
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

- (BOOL)isLockedScreen {
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

- (BOOL)shouldAutorotate {
    return [self shouldForceDeviceOrientation];
}

- (BOOL)allowOrentitaionRotation {
    NSNumber *number = objc_getAssociatedObject(self, _cmd);
    if (number) return number.boolValue;
    self.allowOrentitaionRotation = YES;
    return YES;
}

- (BOOL)forceDeviceOrientation {
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

#pragma mark - setter

- (void)setOrientationWillChange:(void (^)(ZFPlayerController * _Nonnull, BOOL))orientationWillChange {
    objc_setAssociatedObject(self, @selector(orientationWillChange), orientationWillChange, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void)setOrientationDidChanged:(void (^)(ZFPlayerController * _Nonnull, BOOL))orientationDidChanged {
    objc_setAssociatedObject(self, @selector(orientationDidChanged), orientationDidChanged, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void)setStatusBarHidden:(BOOL)statusBarHidden {
    objc_setAssociatedObject(self, @selector(isStatusBarHidden), @(statusBarHidden), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    self.orientationObserver.statusBarHidden = statusBarHidden;
}

- (void)setLockedScreen:(BOOL)lockedScreen {
    objc_setAssociatedObject(self, @selector(isLockedScreen), @(lockedScreen), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    self.orientationObserver.lockedScreen = lockedScreen;
    if ([self.controlView respondsToSelector:@selector(lockedVideoPlayer:lockedScreen:)]) {
        [self.controlView lockedVideoPlayer:self lockedScreen:lockedScreen];
    }
}

- (void)setAllowOrentitaionRotation:(BOOL)allowOrentitaionRotation {
    objc_setAssociatedObject(self, @selector(allowOrentitaionRotation), @(allowOrentitaionRotation), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    self.orientationObserver.allowOrentitaionRotation = allowOrentitaionRotation;
}

- (void)setForceDeviceOrientation:(BOOL)forceDeviceOrientation {
    objc_setAssociatedObject(self, @selector(forceDeviceOrientation), @(forceDeviceOrientation), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    self.orientationObserver.forceDeviceOrientation = forceDeviceOrientation;
}

- (void)setExitFullScreenWhenStop:(BOOL)exitFullScreenWhenStop {
    objc_setAssociatedObject(self, @selector(exitFullScreenWhenStop), @(exitFullScreenWhenStop), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end


@implementation ZFPlayerController (ZFPlayerViewGesture)

#pragma mark - getter

- (ZFPlayerGestureControl *)gestureControl {
    ZFPlayerGestureControl *gestureControl = objc_getAssociatedObject(self, _cmd);
    if (!gestureControl) {
        gestureControl = [[ZFPlayerGestureControl alloc] init];
        @weakify(self)
        // 这里, 手势应该进行什么处理, 都是交给了 controlView 了
        gestureControl.triggerCondition = ^BOOL(ZFPlayerGestureControl * _Nonnull control, ZFPlayerGestureType type, UIGestureRecognizer * _Nonnull gesture, UITouch *touch) {
            @strongify(self)
            if ([self.controlView respondsToSelector:@selector(gestureTriggerCondition:gestureType:gestureRecognizer:touch:)]) {
                return [self.controlView gestureTriggerCondition:control gestureType:type gestureRecognizer:gesture touch:touch];
            }
            return YES;
        };
        
        gestureControl.singleTapped = ^(ZFPlayerGestureControl * _Nonnull control) {
            @strongify(self)
            if ([self.controlView respondsToSelector:@selector(gestureSingleTapped:)]) {
                [self.controlView gestureSingleTapped:control];
            }
        };
        
        gestureControl.doubleTapped = ^(ZFPlayerGestureControl * _Nonnull control) {
            @strongify(self)
            if ([self.controlView respondsToSelector:@selector(gestureDoubleTapped:)]) {
                [self.controlView gestureDoubleTapped:control];
            }
        };
        
        gestureControl.beganPan = ^(ZFPlayerGestureControl * _Nonnull control, ZFPanDirection direction, ZFPanLocation location) {
            @strongify(self)
            if ([self.controlView respondsToSelector:@selector(gestureBeganPan:panDirection:panLocation:)]) {
                [self.controlView gestureBeganPan:control panDirection:direction panLocation:location];
            }
        };
        
        gestureControl.changedPan = ^(ZFPlayerGestureControl * _Nonnull control, ZFPanDirection direction, ZFPanLocation location, CGPoint velocity) {
            @strongify(self)
            if ([self.controlView respondsToSelector:@selector(gestureChangedPan:panDirection:panLocation:withVelocity:)]) {
                [self.controlView gestureChangedPan:control panDirection:direction panLocation:location withVelocity:velocity];
            }
        };
        
        gestureControl.endedPan = ^(ZFPlayerGestureControl * _Nonnull control, ZFPanDirection direction, ZFPanLocation location) {
            @strongify(self)
            if ([self.controlView respondsToSelector:@selector(gestureEndedPan:panDirection:panLocation:)]) {
                [self.controlView gestureEndedPan:control panDirection:direction panLocation:location];
            }
        };
        
        gestureControl.pinched = ^(ZFPlayerGestureControl * _Nonnull control, float scale) {
            @strongify(self)
            if ([self.controlView respondsToSelector:@selector(gesturePinched:scale:)]) {
                [self.controlView gesturePinched:control scale:scale];
            }
        };
        objc_setAssociatedObject(self, _cmd, gestureControl, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return gestureControl;
}

- (ZFPlayerDisableGestureTypes)disableGestureTypes {
    return [objc_getAssociatedObject(self, _cmd) integerValue];
}

- (ZFPlayerDisablePanMovingDirection)disablePanMovingDirection {
    return [objc_getAssociatedObject(self, _cmd) integerValue];
}

#pragma mark - setter

- (void)setDisableGestureTypes:(ZFPlayerDisableGestureTypes)disableGestureTypes {
    objc_setAssociatedObject(self, @selector(disableGestureTypes), @(disableGestureTypes), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    self.gestureControl.disableTypes = disableGestureTypes;
}

- (void)setDisablePanMovingDirection:(ZFPlayerDisablePanMovingDirection)disablePanMovingDirection {
    objc_setAssociatedObject(self, @selector(disablePanMovingDirection), @(disablePanMovingDirection), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    self.gestureControl.disablePanMovingDirection = disablePanMovingDirection;
}

@end

@implementation ZFPlayerController (ZFPlayerScrollView)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        SEL selectors[] = {
            NSSelectorFromString(@"dealloc")
        };
        
        for (NSInteger index = 0; index < sizeof(selectors) / sizeof(SEL); ++index) {
            SEL originalSelector = selectors[index];
            SEL swizzledSelector = NSSelectorFromString([@"zf_" stringByAppendingString:NSStringFromSelector(originalSelector)]);
            Method originalMethod = class_getInstanceMethod(self, originalSelector);
            Method swizzledMethod = class_getInstanceMethod(self, swizzledSelector);
            if (class_addMethod(self, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod))) {
                class_replaceMethod(self, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
            } else {
                method_exchangeImplementations(originalMethod, swizzledMethod);
            }
        }
    });
}

- (void)zf_dealloc {
    [self.smallFloatView removeFromSuperview];
    self.smallFloatView = nil;
    [self zf_dealloc];
}

#pragma mark - setter

- (void)setScrollView:(UIScrollView *)scrollView {
    objc_setAssociatedObject(self, @selector(scrollView), scrollView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    self.scrollView.zf_WWANAutoPlay = self.isWWANAutoPlay;
    @weakify(self)
    scrollView.zf_playerWillAppearInScrollView = ^(NSIndexPath * _Nonnull indexPath) {
        @strongify(self)
        if (self.isFullScreen) return;
        if (self.zf_playerWillAppearInScrollView) self.zf_playerWillAppearInScrollView(indexPath);
        if ([self.controlView respondsToSelector:@selector(playerDidAppearInScrollView:)]) {
            [self.controlView playerDidAppearInScrollView:self];
        }
    };
    
    scrollView.zf_playerDidAppearInScrollView = ^(NSIndexPath * _Nonnull indexPath) {
        @strongify(self)
        if (self.isFullScreen) return;
        if (self.zf_playerDidAppearInScrollView) self.zf_playerDidAppearInScrollView(indexPath);
        if ([self.controlView respondsToSelector:@selector(playerDidAppearInScrollView:)]) {
            [self.controlView playerDidAppearInScrollView:self];
        }
    };
    
    scrollView.zf_playerWillDisappearInScrollView = ^(NSIndexPath * _Nonnull indexPath) {
        @strongify(self)
        if (self.isFullScreen) return;
        if (self.zf_playerWillDisappearInScrollView) self.zf_playerWillDisappearInScrollView(indexPath);
        if ([self.controlView respondsToSelector:@selector(playerWillDisappearInScrollView:)]) {
            [self.controlView playerWillDisappearInScrollView:self];
        }
    };
    
    scrollView.zf_playerDidDisappearInScrollView = ^(NSIndexPath * _Nonnull indexPath) {
        @strongify(self)
        if (self.isFullScreen) return;
        if (self.zf_playerDidDisappearInScrollView) self.zf_playerDidDisappearInScrollView(indexPath);
        if ([self.controlView respondsToSelector:@selector(playerDidDisappearInScrollView:)]) {
            [self.controlView playerDidDisappearInScrollView:self];
        }
    };
    
    scrollView.zf_playerAppearingInScrollView = ^(NSIndexPath * _Nonnull indexPath, CGFloat playerApperaPercent) {
        @strongify(self)
        if (self.isFullScreen) return;
        if (self.zf_playerAppearingInScrollView) self.zf_playerAppearingInScrollView(indexPath, playerApperaPercent);
        if ([self.controlView respondsToSelector:@selector(playerAppearingInScrollView:playerApperaPercent:)]) {
            [self.controlView playerAppearingInScrollView:self playerApperaPercent:playerApperaPercent];
        }
        if (!self.stopWhileNotVisible && playerApperaPercent >= self.playerApperaPercent) {
            if (self.containerType == ZFPlayerContainerTypeView) {
                [self addPlayerViewToContainerView:self.containerView];
            } else if (self.containerType == ZFPlayerContainerTypeCell) {
                [self addPlayerViewToCell];
            }
        }
    };
    
    scrollView.zf_playerDisappearingInScrollView = ^(NSIndexPath * _Nonnull indexPath, CGFloat playerDisapperaPercent) {
        @strongify(self)
        if (self.isFullScreen) return;
        if (self.zf_playerDisappearingInScrollView) self.zf_playerDisappearingInScrollView(indexPath, playerDisapperaPercent);
        if ([self.controlView respondsToSelector:@selector(playerDisappearingInScrollView:playerDisapperaPercent:)]) {
            [self.controlView playerDisappearingInScrollView:self playerDisapperaPercent:playerDisapperaPercent];
        }
        /// stop playing
        if (self.stopWhileNotVisible && playerDisapperaPercent >= self.playerDisapperaPercent) {
            if (self.containerType == ZFPlayerContainerTypeView) {
                [self stopCurrentPlayingView];
            } else if (self.containerType == ZFPlayerContainerTypeCell) {
                [self stopCurrentPlayingCell];
            }
        }
        /// add to window
        if (!self.stopWhileNotVisible && playerDisapperaPercent >= self.playerDisapperaPercent) [self addPlayerViewToKeyWindow];
    };
    
    scrollView.zf_playerShouldPlayInScrollView = ^(NSIndexPath * _Nonnull indexPath) {
        @strongify(self)
        if (self.zf_playerShouldPlayInScrollView) self.zf_playerShouldPlayInScrollView(indexPath);
    };
    
    scrollView.zf_scrollViewDidEndScrollingCallback = ^(NSIndexPath * _Nonnull indexPath) {
        @strongify(self)
        if (self.zf_scrollViewDidEndScrollingCallback) self.zf_scrollViewDidEndScrollingCallback(indexPath);
    };
}

- (void)setWWANAutoPlay:(BOOL)WWANAutoPlay {
    objc_setAssociatedObject(self, @selector(isWWANAutoPlay), @(WWANAutoPlay), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (self.scrollView) self.scrollView.zf_WWANAutoPlay = self.isWWANAutoPlay;
}

- (void)setStopWhileNotVisible:(BOOL)stopWhileNotVisible {
    self.scrollView.zf_stopWhileNotVisible = stopWhileNotVisible;
    objc_setAssociatedObject(self, @selector(stopWhileNotVisible), @(stopWhileNotVisible), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)setContainerViewTag:(NSInteger)containerViewTag {
    objc_setAssociatedObject(self, @selector(containerViewTag), @(containerViewTag), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    self.scrollView.zf_containerViewTag = containerViewTag;
}

// 这里, 仅仅是将 playerView 加到了 cell 上, 没有进行真正的播放替换工作.
- (void)setPlayingIndexPath:(NSIndexPath *)playingIndexPath {
    objc_setAssociatedObject(self, @selector(playingIndexPath), playingIndexPath, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (!playingIndexPath) {
        self.scrollView.zf_playingIndexPath = nil;
        return;
    }
    [self stop];
    self.isSmallFloatViewShow = NO;
    if (self.smallFloatView) self.smallFloatView.hidden = YES;
    
    UIView *cell = [self.scrollView zf_getCellForIndexPath:playingIndexPath];
    // 首先, 更新 orientation.
    self.containerView = [cell viewWithTag:self.containerViewTag];
    [self.orientationObserver cellModelRotateView:self.playerManager.view rotateViewAtCell:cell playerViewTag:self.containerViewTag];
    [self addDeviceOrientationObserver];
    self.scrollView.zf_playingIndexPath = playingIndexPath;
    // 然后将 palyerView 填充到 cell 上面.
    [self layoutPlayerSubViews];
}

- (void)setShouldAutoPlay:(BOOL)shouldAutoPlay {
    objc_setAssociatedObject(self, @selector(shouldAutoPlay), @(shouldAutoPlay), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    self.scrollView.zf_shouldAutoPlay = shouldAutoPlay;
}

- (void)setSectionAssetURLs:(NSArray<NSArray<NSURL *> *> * _Nullable)sectionAssetURLs {
    objc_setAssociatedObject(self, @selector(sectionAssetURLs), sectionAssetURLs, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)setPlayerDisapperaPercent:(CGFloat)playerDisapperaPercent {
    playerDisapperaPercent = MIN(MAX(0.0, playerDisapperaPercent), 1.0);
    self.scrollView.zf_playerDisapperaPercent = playerDisapperaPercent;
    objc_setAssociatedObject(self, @selector(playerDisapperaPercent), @(playerDisapperaPercent), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)setPlayerApperaPercent:(CGFloat)playerApperaPercent {
    playerApperaPercent = MIN(MAX(0.0, playerApperaPercent), 1.0);
    self.scrollView.zf_playerApperaPercent = playerApperaPercent;
    objc_setAssociatedObject(self, @selector(playerApperaPercent), @(playerApperaPercent), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)setZf_playerAppearingInScrollView:(void (^)(NSIndexPath * _Nonnull, CGFloat))zf_playerAppearingInScrollView {
    objc_setAssociatedObject(self, @selector(zf_playerAppearingInScrollView), zf_playerAppearingInScrollView, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void)setZf_playerDisappearingInScrollView:(void (^)(NSIndexPath * _Nonnull, CGFloat))zf_playerDisappearingInScrollView {
    objc_setAssociatedObject(self, @selector(zf_playerDisappearingInScrollView), zf_playerDisappearingInScrollView, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void)setZf_playerDidAppearInScrollView:(void (^)(NSIndexPath * _Nonnull))zf_playerDidAppearInScrollView {
    objc_setAssociatedObject(self, @selector(zf_playerDidAppearInScrollView), zf_playerDidAppearInScrollView, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void)setZf_playerWillDisappearInScrollView:(void (^)(NSIndexPath * _Nonnull))zf_playerWillDisappearInScrollView {
    objc_setAssociatedObject(self, @selector(zf_playerWillDisappearInScrollView), zf_playerWillDisappearInScrollView, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void)setZf_playerWillAppearInScrollView:(void (^)(NSIndexPath * _Nonnull))zf_playerWillAppearInScrollView {
    objc_setAssociatedObject(self, @selector(zf_playerWillAppearInScrollView), zf_playerWillAppearInScrollView, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void)setZf_playerDidDisappearInScrollView:(void (^)(NSIndexPath * _Nonnull))zf_playerDidDisappearInScrollView {
    objc_setAssociatedObject(self, @selector(zf_playerDidDisappearInScrollView), zf_playerDidDisappearInScrollView, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void)setZf_playerShouldPlayInScrollView:(void (^)(NSIndexPath * _Nonnull))zf_playerShouldPlayInScrollView {
    objc_setAssociatedObject(self, @selector(zf_playerShouldPlayInScrollView), zf_playerShouldPlayInScrollView, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void)setZf_scrollViewDidEndScrollingCallback:(void (^)(NSIndexPath * _Nonnull))zf_scrollViewDidEndScrollingCallback {
    objc_setAssociatedObject(self, @selector(zf_scrollViewDidEndScrollingCallback), zf_scrollViewDidEndScrollingCallback, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

#pragma mark - getter

- (UIScrollView *)scrollView {
    UIScrollView *scrollView = objc_getAssociatedObject(self, _cmd);
    return scrollView;
}

- (BOOL)isWWANAutoPlay {
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

- (BOOL)stopWhileNotVisible {
    NSNumber *number = objc_getAssociatedObject(self, _cmd);
    if (number) return number.boolValue;
    self.stopWhileNotVisible = YES;
    return YES;
}

- (NSInteger)containerViewTag {
    return [objc_getAssociatedObject(self, _cmd) integerValue];
}

- (NSIndexPath *)playingIndexPath {
    return objc_getAssociatedObject(self, _cmd);
}

- (NSIndexPath *)shouldPlayIndexPath {
    return self.scrollView.zf_shouldPlayIndexPath;
}

- (NSArray<NSArray<NSURL *> *> *)sectionAssetURLs {
    return objc_getAssociatedObject(self, _cmd);
}

- (BOOL)shouldAutoPlay {
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

- (CGFloat)playerDisapperaPercent {
    NSNumber *number = objc_getAssociatedObject(self, _cmd);
    if (number) return number.floatValue;
    self.playerDisapperaPercent = 0.5;
    return 0.5;
}

- (CGFloat)playerApperaPercent {
    NSNumber *number = objc_getAssociatedObject(self, _cmd);
    if (number) return number.floatValue;
    self.playerApperaPercent = 0.0;
    return 0.0;
}

- (void (^)(NSIndexPath * _Nonnull, CGFloat))zf_playerAppearingInScrollView {
    return objc_getAssociatedObject(self, _cmd);
}

- (void (^)(NSIndexPath * _Nonnull, CGFloat))zf_playerDisappearingInScrollView {
    return objc_getAssociatedObject(self, _cmd);
}

- (void (^)(NSIndexPath * _Nonnull))zf_playerDidAppearInScrollView {
    return objc_getAssociatedObject(self, _cmd);
}

- (void (^)(NSIndexPath * _Nonnull))zf_playerWillDisappearInScrollView {
    return objc_getAssociatedObject(self, _cmd);
}

- (void (^)(NSIndexPath * _Nonnull))zf_playerWillAppearInScrollView {
    return objc_getAssociatedObject(self, _cmd);
}

- (void (^)(NSIndexPath * _Nonnull))zf_playerDidDisappearInScrollView {
    return objc_getAssociatedObject(self, _cmd);
}

- (void (^)(NSIndexPath * _Nonnull))zf_playerShouldPlayInScrollView {
    return objc_getAssociatedObject(self, _cmd);
}

- (void (^)(NSIndexPath * _Nonnull))zf_scrollViewDidEndScrollingCallback {
    return objc_getAssociatedObject(self, _cmd);
}

#pragma mark - Public method

- (void)zf_filterShouldPlayCellWhileScrolled:(void (^ __nullable)(NSIndexPath *indexPath))handler {
    [self.scrollView zf_filterShouldPlayCellWhileScrolled:handler];
}

- (void)zf_filterShouldPlayCellWhileScrolling:(void (^ __nullable)(NSIndexPath *indexPath))handler {
    [self.scrollView zf_filterShouldPlayCellWhileScrolling:handler];
}

// 在这里, 进行了播放的真正切换.
- (void)playTheIndexPath:(NSIndexPath *)indexPath {
    self.playingIndexPath = indexPath;
    NSURL *assetURL;
    if (self.sectionAssetURLs.count) {
        assetURL = self.sectionAssetURLs[indexPath.section][indexPath.row];
    } else if (self.assetURLs.count) {
        assetURL = self.assetURLs[indexPath.row];
        self.currentPlayIndex = indexPath.row;
    }
    self.currentAssetURL = assetURL;
}

// 切换播放 asset, 并且进行 scroll, 提供回调.
- (void)playTheIndexPath:(NSIndexPath *)indexPath scrollToTop:(BOOL)scrollToTop completionHandler:(void (^ _Nullable)(void))completionHandler {
    NSURL *assetURL;
    if (self.sectionAssetURLs.count) {
        assetURL = self.sectionAssetURLs[indexPath.section][indexPath.row];
    } else if (self.assetURLs.count) {
        assetURL = self.assetURLs[indexPath.row];
        self.currentPlayIndex = indexPath.row;
    }
    if (scrollToTop) {
        @weakify(self)
        [self.scrollView zf_scrollToRowAtIndexPath:indexPath completionHandler:^{
            @strongify(self)
            if (completionHandler) completionHandler();
            self.playingIndexPath = indexPath;
            self.currentAssetURL = assetURL;
        }];
    } else {
        if (completionHandler) completionHandler();
        self.playingIndexPath = indexPath;
        self.currentAssetURL = assetURL;
    }
}

- (void)playTheIndexPath:(NSIndexPath *)indexPath scrollToTop:(BOOL)scrollToTop {
    if ([indexPath compare:self.playingIndexPath] == NSOrderedSame) return;
    if (scrollToTop) {
        @weakify(self)
        [self.scrollView zf_scrollToRowAtIndexPath:indexPath completionHandler:^{
            @strongify(self)
            [self playTheIndexPath:indexPath];
        }];
    } else {
        [self playTheIndexPath:indexPath];
    }
}

- (void)playTheIndexPath:(NSIndexPath *)indexPath assetURL:(NSURL *)assetURL scrollToTop:(BOOL)scrollToTop {
    self.playingIndexPath = indexPath;
    self.currentAssetURL = assetURL;
    if (scrollToTop) {
        [self.scrollView zf_scrollToRowAtIndexPath:indexPath completionHandler:nil];
    }
}

@end

