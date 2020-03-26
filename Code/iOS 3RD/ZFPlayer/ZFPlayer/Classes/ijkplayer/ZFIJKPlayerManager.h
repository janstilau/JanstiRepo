#import <Foundation/Foundation.h>
#if __has_include(<ZFPlayer/ZFPlayerMediaPlayback.h>)
#import <ZFPlayer/ZFPlayerMediaPlayback.h>
#else
#import "ZFPlayerMediaPlayback.h"
#endif

#if __has_include(<IJKMediaFramework/IJKMediaFramework.h>)
#import <IJKMediaFramework/IJKMediaFramework.h>

@interface ZFIJKPlayerManager : NSObject <ZFPlayerMediaPlayback>

@property (nonatomic, strong, readonly) IJKFFMoviePlayerController *player;

@property (nonatomic, strong, readonly) IJKFFOptions *options;

@property (nonatomic, assign) NSTimeInterval timeRefreshInterval;

@end

#endif
