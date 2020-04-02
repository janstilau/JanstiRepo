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
    
    NSArray *natureTrackAry = [[self.mcComposition.totalComposition tracksWithMediaType:AVMediaTypeAudio] copy];
    
    for (AVCompositionTrack *track in natureTrackAry) {
        [self.mcComposition.totalComposition removeTrack:track];
    }
    
    duration = CMTimeMinimum([replaceAsset duration], self.mcComposition.duration);
    
    for (AVAssetTrack *audioTrack in [replaceAsset tracksWithMediaType:AVMediaTypeAudio]) {
        AVMutableCompositionTrack *compositionAudioTrack = [self.mcComposition.totalComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
        [compositionAudioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, duration) ofTrack:audioTrack atTime:insertionPoint error:&error];
    }
    
}
@end
