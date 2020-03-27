#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MPMusicPlayerController.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, ZFPlayerBackgroundState) {
    ZFPlayerBackgroundStateForeground,  // Enter the foreground from the background.
    ZFPlayerBackgroundStateBackground,  // From the foreground to the background.
};

// 该类将所有的通知集中在一起, 用回调的方式, 暴露出应该执行的操作.

@interface ZFPlayerNotification : NSObject

@property (nonatomic, readonly) ZFPlayerBackgroundState backgroundState;

@property (nonatomic, copy, nullable) void(^willResignActive)(ZFPlayerNotification *registrar);

@property (nonatomic, copy, nullable) void(^didBecomeActive)(ZFPlayerNotification *registrar);

@property (nonatomic, copy, nullable) void(^newDeviceAvailable)(ZFPlayerNotification *registrar);

@property (nonatomic, copy, nullable) void(^oldDeviceUnavailable)(ZFPlayerNotification *registrar);

@property (nonatomic, copy, nullable) void(^categoryChange)(ZFPlayerNotification *registrar);

@property (nonatomic, copy, nullable) void(^volumeChanged)(float volume);

@property (nonatomic, copy, nullable) void(^audioInterruptionCallback)(AVAudioSessionInterruptionType interruptionType);

// 在视频 prepare 完成之后, 进行了 addNotification. 也就是在可以播放视频的时候, 开始监听各种事件

- (void)addNotification;

// 在视频 stop 之后, 进行 removeNotification, 也就是视频结束播放之后, 停止监听.

- (void)removeNotification;

@end

NS_ASSUME_NONNULL_END
