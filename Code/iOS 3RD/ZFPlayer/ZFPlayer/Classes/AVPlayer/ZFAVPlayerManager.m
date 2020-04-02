#import "ZFAVPlayerManager.h"
#import <UIKit/UIKit.h>
#if __has_include(<ZFPlayer/ZFPlayer.h>)
#import <ZFPlayer/ZFPlayer.h>
#import <ZFPlayer/ZFReachabilityManager.h>
#else
#import "ZFPlayer.h"
#import "ZFReachabilityManager.h"
#endif

#pragma clang diagnostic push
#pragma clang diagnostic ignored"-Wdeprecated-declarations"

// 这个 View, 就是实际的进行视频播放的视图. 里面的 layer, 是一个 playerLayer

@interface ZFPlayerPresentView : ZFPlayerView

@property (nonatomic, strong) AVPlayer *player;
/// default is AVLayerVideoGravityResizeAspect.
@property (nonatomic, strong) AVLayerVideoGravity videoGravity;

@end

@implementation ZFPlayerPresentView

+ (Class)layerClass {
    return [AVPlayerLayer class];
}

- (AVPlayerLayer *)avLayer {
    return (AVPlayerLayer *)self.layer;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor blackColor];
    }
    return self;
}

- (void)setPlayer:(AVPlayer *)player {
    if (player == _player) return;
    self.avLayer.player = player;
}

- (void)setVideoGravity:(AVLayerVideoGravity)videoGravity {
    if (videoGravity == self.videoGravity) return;
    [self avLayer].videoGravity = videoGravity;
}

- (AVLayerVideoGravity)videoGravity {
    return [self avLayer].videoGravity;
}

@end

/*!
 *  Refresh interval for timed observations of AVPlayer
 */
// 播放状态的回调.
static NSString *const kStatus                   = @"status";
// 缓冲了多少内容
static NSString *const kLoadedTimeRanges         = @"loadedTimeRanges";
static NSString *const kPlaybackBufferEmpty      = @"playbackBufferEmpty";
// 表示可以播放视频了, 和 playbackBufferEmpty 是相反的属性
static NSString *const kPlaybackLikelyToKeepUp   = @"playbackLikelyToKeepUp";
// PlayerItem 所表示的视频的尺寸, 这个信息在视频加载的时候是 Zero. 在加载之后, 获取到该信息, 然后触发回调.
static NSString *const kPresentationSize         = @"presentationSize";


@interface ZFAVPlayerManager () {
    id _timeObserver;
    id _itemEndObserver;
    ZFKVOController *_playerItemKVO;
}
@property (nonatomic, strong) AVPlayerLayer *playerLayer;
@property (nonatomic, assign) BOOL isBuffering; // 控制属性, 表示当前正在缓冲数据
@property (nonatomic, assign) BOOL isReadyToPlay;

@end

@implementation ZFAVPlayerManager

// 这就是, 一个类如果想要实现一个 protocol 中的 property 应该做的事情, 仅仅提供实体变量就行, 定义直接用 protocol 里面的 property.
// 相比 MC 现在的实现方式, 这种方式应该是更加的优雅.
/*
  除了 playerPrepareToPlay, playerReadyToPlay, playerDidToEnd 外, 其他的回调, 仅仅是传递到 ControlView 中, 做视图的更新操作.
 
 playerPrepareToPlay 是在 初始化 player, 监听完毕视频的状态变化后调用的, 在外界, 做了 通知监听, 设备旋转监听的操作.
 playerReadyToPlay 是在 assetItem 可以状态变为可以播放时调用的, 在外界, 做了 AudioSession 的一些设置.
 playerDidToEnd 是在 assetItem 播放完毕时调用的, 这个主要是不同的业务场景不同配置.
 */
 
@synthesize playerPlayTimeChanged          = _playerPlayTimeChanged;
@synthesize playerBufferTimeChanged        = _playerBufferTimeChanged;
@synthesize playerPlayStateChanged         = _playerPlayStateChanged;
@synthesize playerLoadStateChanged         = _playerLoadStateChanged;
@synthesize playerPlayFailed               = _playerPlayFailed;
@synthesize presentationSizeChanged        = _presentationSizeChanged;
@synthesize playerPrepareToPlay            = _playerPrepareToPlay;
@synthesize playerReadyToPlay              = _playerReadyToPlay;
@synthesize playerDidToEnd                 = _playerDidToEnd;

@synthesize view                           = _view;
@synthesize currentTime                    = _currentTime;
@synthesize totalTime                      = _totalTime;

@synthesize bufferTime                     = _bufferTime;
@synthesize playState                      = _playState;
@synthesize loadState                      = _loadState;
@synthesize assetURL                       = _assetURL;
@synthesize seekTime                       = _seekTime;
@synthesize muted                          = _muted;
@synthesize volume                         = _volume;
@synthesize presentationSize               = _presentationSize;
@synthesize isPlaying                      = _isPlaying;
@synthesize rate                           = _rate;
@synthesize isPreparedToPlay               = _isPreparedToPlay;
@synthesize shouldAutoPlay                 = _shouldAutoPlay;
@synthesize scalingMode                    = _scalingMode;

- (instancetype)init {
    self = [super init];
    if (self) {
        _scalingMode = ZFPlayerScalingModeAspectFit;
        _shouldAutoPlay = YES;
    }
    return self;
}

// 各种状态的初始化工作.
// 如果设置了自动播放, 那么自动调用 play
// 然后触发回调, playerPrepareToPlay, 通知外界已经初始化完成了.
- (void)prepareToPlay {
    if (!_assetURL) return;
    _isPreparedToPlay = YES;
    [self initializePlayer];
    [self initPlayerView];
    [self initItemObserver];
    if (self.shouldAutoPlay) { // 如果, 自动播放, 那么在prepare准备好之后, 直接播放.
        [self play];
    }
    self.loadState = ZFPlayerLoadStatePrepare;
    if (_playerPrepareToPlay) _playerPrepareToPlay(self, self.assetURL);
}

- (void)initializePlayer {
    // 初始化, iOS 里面和视频播放相关的数据.
    _asset = [AVURLAsset URLAssetWithURL:self.assetURL options:self.requestHeader];
    _playerItem = [AVPlayerItem playerItemWithAsset:_asset];
    _player = [AVPlayer playerWithPlayerItem:_playerItem];
    [self enableAudioTracks:YES inPlayerItem:_playerItem];
    if (@available(iOS 9.0, *)) {
        _playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = NO; // 流媒体, 在暂停的时候, 要不要一直进行网络请求,
    }
    if (@available(iOS 10.0, *)) {
        _playerItem.preferredForwardBufferDuration = 5;
        _player.automaticallyWaitsToMinimizeStalling = NO;
    }
}

- (void)initPlayerView {
    ZFPlayerPresentView *presentView = (ZFPlayerPresentView *)self.view;
    presentView.player = _player;
    self.scalingMode = _scalingMode;
}

- (void)initItemObserver {
    // 这里, 对于 AVPlayerItem 的各种状态改变进行了监听.
    [_playerItemKVO safelyRemoveAllObservers];
    _playerItemKVO = [[ZFKVOController alloc] initWithTarget:_playerItem];
    [_playerItemKVO safelyAddObserver:self
                           forKeyPath:kStatus
                              options:NSKeyValueObservingOptionNew
                              context:nil];
    [_playerItemKVO safelyAddObserver:self
                           forKeyPath:kPlaybackBufferEmpty
                              options:NSKeyValueObservingOptionNew
                              context:nil];
    [_playerItemKVO safelyAddObserver:self
                           forKeyPath:kPlaybackLikelyToKeepUp
                              options:NSKeyValueObservingOptionNew
                              context:nil];
    [_playerItemKVO safelyAddObserver:self
                           forKeyPath:kLoadedTimeRanges
                              options:NSKeyValueObservingOptionNew
                              context:nil];
    [_playerItemKVO safelyAddObserver:self
                           forKeyPath:kPresentationSize
                              options:NSKeyValueObservingOptionNew
                              context:nil];
    
    CMTime interval = CMTimeMakeWithSeconds(self.timeRefreshInterval > 0 ? self.timeRefreshInterval : 0.1, NSEC_PER_SEC);
    
    // 这里, 对于播放的进度进行了监听, 传递出来的就是当前的播放时刻.
    @weakify(self)
    _timeObserver = [_player addPeriodicTimeObserverForInterval:interval queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {
        @strongify(self)
        if (!self) return;
        /*
         An array of time ranges within which it is possible to seek.
         这个值, 其实在这里就是当做了一个标记, 就是已经获取到了关于资源的信息了.
         很快这个值, 就变成了 0 到 asset 的 duration 的值了.
         这里, 当这个值有值的时候, 就认为, 视频已经处于可用的状态, 可以调用播放进度更改的回调了.
         */
        NSArray *loadedRanges = self.playerItem.seekableTimeRanges;
        if (_isPlaying && self.loadState == ZFPlayerLoadStateStalled) self.player.rate = self.rate;
        if (loadedRanges.count > 0) {
            if (self.playerPlayTimeChanged) self.playerPlayTimeChanged(self, self.currentTime, self.totalTime);
        }
    }];
    
    // 这里, 对播放完毕进行了监听.
    _itemEndObserver = [[NSNotificationCenter defaultCenter] addObserverForName:AVPlayerItemDidPlayToEndTimeNotification object:_playerItem queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
        @strongify(self)
        if (!self) return;
        self.playState = ZFPlayerPlayStatePlayStopped;
        if (self.playerDidToEnd) self.playerDidToEnd(self);
    }];
}

#pragma mark - PlayControl

- (void)reloadPlayer {
    self.seekTime = self.currentTime;
    [self prepareToPlay];
}

- (void)play {
    if (!_isPreparedToPlay) {
        [self prepareToPlay];
    } else {
        // 直接就是调用 player 进行 play 的操作. 并且更改自己的状态.
        _isPlaying = YES;
        [_player play];
        _player.rate = self.rate;
        self.playState = ZFPlayerPlayStatePlaying;
    }
}

// Player 停止播放,
- (void)pause {
    // 直接就是调用 player 进行 pause 的操作. 并且更改自己的状态.
    [_player pause];
    _isPlaying = NO;
    self.playState = ZFPlayerPlayStatePaused;
    [_playerItem cancelPendingSeeks];
    [_asset cancelLoading];
}

// 一次 reset 操作.
- (void)stop {
    // 监视器清空
    // 监听了 status, loadedTimeRanges, playbackBufferEmpty, playbackLikelyToKeepUp, presentationSize, 这些都是 PlayerItem 的状态.
    // 监视了 AVPlayerItemDidPlayToEndTimeNotification, 这个是播放完毕
    // 监视了 PeriodicTime, 这个是播放进度.
    [_playerItemKVO safelyRemoveAllObservers];
    [_player removeTimeObserver:_timeObserver];
    _timeObserver = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:_itemEndObserver name:AVPlayerItemDidPlayToEndTimeNotification object:_playerItem];
    _itemEndObserver = nil;
    
    // 播放器暂停
    if (_player.rate != 0) [_player pause];
    [_player replaceCurrentItemWithPlayerItem:nil];
    
    // 内部状态管理.
    self.loadState = ZFPlayerLoadStateUnknown;
    self.playState = ZFPlayerPlayStatePlayStopped;
    _isPlaying = NO;
    _player = nil;
    _assetURL = nil;
    _playerItem = nil;
    _isPreparedToPlay = NO;
    _currentTime = 0;
    _totalTime = 0;
    _bufferTime = 0;
    _isReadyToPlay = NO;
}

- (void)replay {
    @weakify(self)
    [self seekToTime:0 completionHandler:^(BOOL finished) {
        @strongify(self)
        [self play];
    }];
}

// 直接调用的 player 的 seekToTime
- (void)seekToTime:(NSTimeInterval)time completionHandler:(void (^ __nullable)(BOOL finished))completionHandler {
    if (self.totalTime > 0) {
        CMTime seekTime = CMTimeMake(time, 1);
        [_player seekToTime:seekTime toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero completionHandler:completionHandler];
    } else {
        self.seekTime = time;
    }
}


#pragma mark - private method

/// Calculate buffer progress
- (NSTimeInterval)availableDuration {
    /*
     An array of time ranges indicating media data that is readily available.
     这里, 作者是将 loadedTimeRanges 的第一个, 当做是已经缓存了的数据的范围.
     */
    NSArray *timeRangeArray = _playerItem.loadedTimeRanges;
    CMTime currentTime = [_player currentTime];
    BOOL foundRange = NO;
    CMTimeRange aTimeRange = {0};
    if (timeRangeArray.count) {
        aTimeRange = [[timeRangeArray objectAtIndex:0] CMTimeRangeValue];
        if (CMTimeRangeContainsTime(aTimeRange, currentTime)) {
            foundRange = YES;
        }
    }
    
    if (foundRange) {
        CMTime maxTime = CMTimeRangeGetEnd(aTimeRange);
        NSTimeInterval playableDuration = CMTimeGetSeconds(maxTime);
        if (playableDuration > 0) {
            return playableDuration;
        }
    }
    return 0;
}

/// Playback speed switching method
/// 没太明白这个的作用.
- (void)enableAudioTracks:(BOOL)enable inPlayerItem:(AVPlayerItem*)playerItem {
    for (AVPlayerItemTrack *track in playerItem.tracks){
        if ([track.assetTrack.mediaType isEqual:AVMediaTypeVideo]) {
            track.enabled = enable;
        }
    }
}

#pragma mark - ObserverHandler

/**
 *  缓冲较差时候回调这里
 *  这里并没有调用什么加载的方法, 仅仅是做了一个定时器,  不断的进行重新播放的尝试 .
 */
- (void)bufferingSomeSecond {
    // playbackBufferEmpty会反复进入，因此在bufferingOneSecond延时播放执行完之前再调用bufferingSomeSecond都忽略
    if (self.isBuffering || self.playState == ZFPlayerPlayStatePlayStopped) return;
    /// 没有网络
    if ([ZFReachabilityManager sharedManager].networkReachabilityStatus == ZFReachabilityStatusNotReachable) return;
    self.isBuffering = YES;
    
    // 需要先暂停一小会之后再播放，否则网络状况不好的时候时间在走，声音播放不出来
    [_player pause];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // 如果此时用户已经暂停了，则不再需要开启播放了
        if (!_isPlaying && self.loadState == ZFPlayerLoadStateStalled) {
            self.isBuffering = NO;
            return;
        }
        [self play];
        // 如果执行了play还是没有播放则说明还没有缓存好，则再次缓存一段时间
        self.isBuffering = NO;
        if (!_playerItem.isPlaybackLikelyToKeepUp) [self bufferingSomeSecond];
    });
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([keyPath isEqualToString:kStatus]) {
            [self assetPlayStatusUpdated];
        } else if ([keyPath isEqualToString:kPlaybackBufferEmpty]) {
            [self assetBufferEmptyed];
        } else if ([keyPath isEqualToString:kPlaybackLikelyToKeepUp]) {
            [self assetLikelyToBePalyable];
        } else if ([keyPath isEqualToString:kLoadedTimeRanges]) {
            [self assetBufferUpdated];
        } else if ([keyPath isEqualToString:kPresentationSize]) {
            [self assetPresentationUpdated];
        } else {
            [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        }
    });
}

/*
 When a player item is created, its status is AVPlayerItemStatusUnknown, meaning its media hasn’t been loaded and has not yet been enqueued for playback. Associating a player item with an AVPlayer immediately begins enqueuing the item’s media and preparing it for playback. When the player item’s media has been loaded and is ready for use, its status will change to AVPlayerItemStatusReadyToPlay. You can observe this change using key-value observing.
 从上面的描述可以知道, 获取视频元信息这件事会在挂钩之后立马进行.
 */
- (void)assetPlayStatusUpdated {
    if (_player.currentItem.status == AVPlayerItemStatusReadyToPlay) {
        if (!_isReadyToPlay) {
            _isReadyToPlay = YES;
            self.loadState = ZFPlayerLoadStatePlaythroughOK;
            if (_playerReadyToPlay) _playerReadyToPlay(self, self.assetURL);
        }
        if (self.seekTime) {
            [self seekToTime:self.seekTime completionHandler:nil];
            self.seekTime = 0;
        }
        if (_isPlaying) [self play]; // _isPlaying 是在调动的时候变化的, 而 Item 的状态变化是网络的回调. 所以, 如果 Item 变为可播放的时候, 可能已经是 isPlayering.
        _player.muted = self.muted;
        NSArray *loadedRanges = _playerItem.seekableTimeRanges; // timeRange is composed with duration and start.
        if (loadedRanges.count > 0) {
            /// Fix https://github.com/renzifeng/ZFPlayer/issues/475
            if (_playerPlayTimeChanged) _playerPlayTimeChanged(self, self.currentTime, self.totalTime);
        }
    } else if (_player.currentItem.status == AVPlayerItemStatusFailed) {
        self.playState = ZFPlayerPlayStatePlayFailed;
        NSError *error = _player.currentItem.error;
        if (_playerPlayFailed) _playerPlayFailed(self, error);
    }
}

- (void)assetBufferEmptyed {
    // When the buffer is empty
    if (_playerItem.playbackBufferEmpty) {
        self.loadState = ZFPlayerLoadStateStalled;
        [self bufferingSomeSecond];
    }
}

- (void)assetLikelyToBePalyable {
    // When the buffer is good
    if (_playerItem.playbackLikelyToKeepUp) {
       self.loadState = ZFPlayerLoadStatePlayable;
       if (_isPlaying) [_player play];
    }
}

- (void)assetBufferUpdated {
    NSTimeInterval bufferTime = [self availableDuration];
    self->_bufferTime = bufferTime;
    if (_playerBufferTimeChanged) _playerBufferTimeChanged(self, bufferTime);
}

- (void)assetPresentationUpdated {
    self->_presentationSize = _playerItem.presentationSize;
    if (self.presentationSizeChanged) {
        self.presentationSizeChanged(self, self->_presentationSize);
    }
}

#pragma mark - getter

// 懒加载, 产生一个PlayerView, 这个 PlayView 中集成了 AVPlayerLayer, 以及一个 AVPlayer
- (UIView *)view {
    if (!_view) {
        _view = [[ZFPlayerPresentView alloc] init];
    }
    return _view;
}

- (float)rate {
    return _rate == 0 ?1:_rate;
}

- (NSTimeInterval)totalTime {
    NSTimeInterval sec = CMTimeGetSeconds(_player.currentItem.duration);
    if (isnan(sec)) {
        return 0;
    }
    return sec;
}

- (NSTimeInterval)currentTime {
    NSTimeInterval sec = CMTimeGetSeconds(_playerItem.currentTime);
    if (isnan(sec) || sec < 0) {
        return 0;
    }
    return sec;
}

- (UIImage *)thumbnailImageAtCurrentTime {
    AVAssetImageGenerator *imageGenerator = [AVAssetImageGenerator assetImageGeneratorWithAsset:_asset];
    CMTime expectedTime = _playerItem.currentTime;
    CGImageRef cgImage = NULL;
    
    imageGenerator.requestedTimeToleranceBefore = kCMTimeZero;
    imageGenerator.requestedTimeToleranceAfter = kCMTimeZero;
    cgImage = [imageGenerator copyCGImageAtTime:expectedTime actualTime:NULL error:NULL];
    
    if (!cgImage) {
        imageGenerator.requestedTimeToleranceBefore = kCMTimePositiveInfinity;
        imageGenerator.requestedTimeToleranceAfter = kCMTimePositiveInfinity;
        cgImage = [imageGenerator copyCGImageAtTime:expectedTime actualTime:NULL error:NULL];
    }
    
    UIImage *image = [UIImage imageWithCGImage:cgImage];
    return image;
}

#pragma mark - setter

// 专门的使用set方法, 主要是为了使用各种回调Block可以使用.
// 这个类, 是内部管理的player的状态的代理.
- (void)setPlayState:(ZFPlayerPlaybackState)playState {
    _playState = playState;
    if (_playerPlayStateChanged) _playerPlayStateChanged(self, playState);
}

- (void)setLoadState:(ZFPlayerLoadState)loadState {
    _loadState = loadState;
    if (_playerLoadStateChanged) _playerLoadStateChanged(self, loadState);
}

- (void)setAssetURL:(NSURL *)assetURL {
    if (_player) [self stop];
    _assetURL = assetURL;
    [self prepareToPlay];
}

- (void)setRate:(float)rate {
    _rate = rate;
    if (_player && fabsf(_player.rate) > 0.00001f) {
        _player.rate = rate;
    }
}

- (void)setMuted:(BOOL)muted {
    _muted = muted;
    _player.muted = muted;
}

// 这里, 仅仅是一个简单的替换的工作, 就是使用的layer的videoGravity属性.
- (void)setScalingMode:(ZFPlayerScalingMode)scalingMode {
    _scalingMode = scalingMode;
    ZFPlayerPresentView *presentView = (ZFPlayerPresentView *)self.view;
    switch (scalingMode) {
        case ZFPlayerScalingModeNone:
            presentView.videoGravity = AVLayerVideoGravityResizeAspect;
            break;
        case ZFPlayerScalingModeAspectFit:
            presentView.videoGravity = AVLayerVideoGravityResizeAspect;
            break;
        case ZFPlayerScalingModeAspectFill:
            presentView.videoGravity = AVLayerVideoGravityResizeAspectFill;
            break;
        case ZFPlayerScalingModeFill:
            presentView.videoGravity = AVLayerVideoGravityResize;
            break;
        default:
            break;
    }
}

- (void)setVolume:(float)volume {
    _volume = MIN(MAX(0, volume), 1);
    _player.volume = volume;
}

@end

#pragma clang diagnostic pop
