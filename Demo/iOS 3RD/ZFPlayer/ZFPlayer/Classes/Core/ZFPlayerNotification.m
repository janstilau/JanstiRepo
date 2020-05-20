#import "ZFPlayerNotification.h"

@interface ZFPlayerNotification ()

@property (nonatomic, assign) ZFPlayerBackgroundState backgroundState; // 这个值目前完全没有被用到.

@end

@implementation ZFPlayerNotification

- (void)addNotification {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(audioSessionRouteChangeNotification:)
                                                 name:AVAudioSessionRouteChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillResignActiveNotification)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidBecomeActiveNotification)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(volumeDidChangeNotification:)
                                                 name:@"AVSystemController_SystemVolumeDidChangeNotification"
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(audioSessionInterruptionNotification:)
                                                 name:AVAudioSessionInterruptionNotification
                                               object:nil];
    
}

- (void)removeNotification {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVAudioSessionRouteChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"AVSystemController_SystemVolumeDidChangeNotification" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVAudioSessionInterruptionNotification object:nil];
}

- (void)dealloc {
    [self removeNotification];
}

// 这个通知是在子线程中发出的, 所以这里要进行一次切换操作. 通过询问 Reason 的 key 值, 来进行不同的回调调用.
- (void)audioSessionRouteChangeNotification:(NSNotification*)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSDictionary *interuptionDict = notification.userInfo;
        NSInteger routeChangeReason = [[interuptionDict valueForKey:AVAudioSessionRouteChangeReasonKey] integerValue];
        switch (routeChangeReason) {
            case AVAudioSessionRouteChangeReasonNewDeviceAvailable: {
                if (self.newDeviceAvailable) self.newDeviceAvailable(self);
            }
                break;
            case AVAudioSessionRouteChangeReasonOldDeviceUnavailable: {
                if (self.oldDeviceUnavailable) self.oldDeviceUnavailable(self);
            }
                break;
            case AVAudioSessionRouteChangeReasonCategoryChange: {
                if (self.categoryChange) self.categoryChange(self);
            }
                break;
        }
    });
}

// 这里是 声音变化 的回调
- (void)volumeDidChangeNotification:(NSNotification *)notification {
    float volume = [[[notification userInfo] objectForKey:@"AVSystemController_AudioVolumeNotificationParameter"] floatValue];
    if (self.volumeChanged) self.volumeChanged(volume);
}

// 这里是 失去焦点 的回调.
- (void)applicationWillResignActiveNotification {
    self.backgroundState = ZFPlayerBackgroundStateBackground;
    if (_willResignActive) _willResignActive(self);
}

// 这里是 恢复焦点 的回调.
- (void)applicationDidBecomeActiveNotification {
    self.backgroundState = ZFPlayerBackgroundStateForeground;
    if (_didBecomeActive) _didBecomeActive(self);
}

// 这里是被打断的回调.
- (void)audioSessionInterruptionNotification:(NSNotification *)notification {
    NSDictionary *interuptionDict = notification.userInfo;
    AVAudioSessionInterruptionType interruptionType = [[interuptionDict valueForKey:AVAudioSessionInterruptionTypeKey] integerValue];
    if (self.audioInterruptionCallback) self.audioInterruptionCallback(interruptionType);
}

@end
