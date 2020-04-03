//
//  WAAVSEReplaceSoundCommand.m
//  WA
//
//  Created by 黄锐灏 on 2017/11/23.
//  Copyright © 2017年 黄锐灏. All rights reserved.
//

#import "WAAVSEReplaceSoundCommand.h"

@implementation WAAVSEReplaceSoundCommand

- (void)performWithAsset:(AVAsset *)asset replaceAsset:(AVAsset *)replaceAsset{
    [super performWithAsset:asset];
    
    CMTime insertionPoint = kCMTimeZero;
    CMTime duration;
    NSError *error = nil;
    
    NSArray *natureTrackAry = [[self.editComposition.totalEditComposition tracksWithMediaType:AVMediaTypeAudio] copy];
    
    // 这里, 直接把原始的音频轨道移除了.
    for (AVCompositionTrack *track in natureTrackAry) {
        [self.editComposition.totalEditComposition removeTrack:track];
    }
    
    duration = CMTimeMinimum([replaceAsset duration], self.editComposition.duration);
    // 然后把换音的音乐轨道, 加上去
    for (AVAssetTrack *audioTrack in [replaceAsset tracksWithMediaType:AVMediaTypeAudio]) {
        AVMutableCompositionTrack *compositionAudioTrack = [self.editComposition.totalEditComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
        [compositionAudioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, duration) ofTrack:audioTrack atTime:insertionPoint error:&error];
    }
    
}
@end
