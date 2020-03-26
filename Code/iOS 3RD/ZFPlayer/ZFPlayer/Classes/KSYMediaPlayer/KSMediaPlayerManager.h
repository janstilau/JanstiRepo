#import <Foundation/Foundation.h>
#if __has_include(<ZFPlayer/ZFPlayerMediaPlayback.h>)
#import <ZFPlayer/ZFPlayerMediaPlayback.h>
#else
#import "ZFPlayerMediaPlayback.h"
#endif
#if __has_include(<KSYMediaPlayer/KSYMediaPlayer.h>)
#import <KSYMediaPlayer/KSYMediaPlayer.h>

@interface KSMediaPlayerManager : NSObject <ZFPlayerMediaPlayback>

@property (nonatomic, strong, readonly) KSYMoviePlayerController *player;

@property (nonatomic, assign) NSTimeInterval timeRefreshInterval;

@end

#endif
