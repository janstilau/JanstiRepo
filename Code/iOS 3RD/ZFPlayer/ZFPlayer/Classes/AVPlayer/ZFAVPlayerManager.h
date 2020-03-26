#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#if __has_include(<ZFPlayer/ZFPlayerMediaPlayback.h>)
#import <ZFPlayer/ZFPlayerMediaPlayback.h>
#else
#import "ZFPlayerMediaPlayback.h"
#endif

@interface ZFAVPlayerManager : NSObject <ZFPlayerMediaPlayback>

// 这个类, 仅仅是管理一个播放.
@property (nonatomic, strong, readonly) AVURLAsset *asset;
@property (nonatomic, strong, readonly) AVPlayerItem *playerItem;
@property (nonatomic, strong, readonly) AVPlayer *player;
@property (nonatomic, assign) NSTimeInterval timeRefreshInterval;
/*
 视频请求头
 给了外界一个自定义的机会.
 */
@property (nonatomic, strong) NSDictionary *requestHeader;

@end
