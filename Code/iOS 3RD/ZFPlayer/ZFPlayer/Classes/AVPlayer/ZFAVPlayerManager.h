#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#if __has_include(<ZFPlayer/ZFPlayerMediaPlayback.h>)
#import <ZFPlayer/ZFPlayerMediaPlayback.h>
#else
#import "ZFPlayerMediaPlayback.h"
#endif

@interface ZFAVPlayerManager : NSObject <ZFPlayerMediaPlayback>

// 这个类, 仅仅是管理一个播放.
// 在内部, 会生成一个 AVPlayer, 然后监听这个 palyer 的状态, 不断地触发对应的回调.
// 视频如何播放, 都是 Apple 自己的类库在进行管理.
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
