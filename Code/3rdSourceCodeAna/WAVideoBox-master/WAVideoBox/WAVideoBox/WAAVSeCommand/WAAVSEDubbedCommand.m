//
//  WAAVSEDubbedCommand.m
//  WA
//
//  Created by 黄锐灏 on 2017/11/27.
//  Copyright © 2017年 黄锐灏. All rights reserved.
//

#import "WAAVSEDubbedCommand.h"

@implementation WAAVSEDubbedCommand

- (instancetype)init
{
    if (self = [super init]) {
        self.audioVolume = 0.5;
        self.mixVolume = 0.5;
        self.insertTime = kCMTimeZero;
    }
    return self;
}

- (instancetype)initWithComposition:(WACommandComposition *)composition{
    if (self = [super initWithComposition:composition]) {
        self.audioVolume = 0.5;
        self.mixVolume = 0.5;
        self.insertTime = kCMTimeZero;
    }
    return self;
}

- (void)performWithAsset:(AVAsset *)asset mixAsset:(AVAsset *)mixAsset{
    
    [super performWithAsset:asset];
    
    [super performAudioCompopsition];
    
    if (CMTimeCompare(self.mcComposition.duration, _insertTime) != 1) {
        return;
    }
    
    for (AVMutableAudioMixInputParameters *parameters in self.mcComposition.audioInstructions) {
        [parameters setVolume:self.audioVolume atTime:kCMTimeZero];
    }
    
    AVAssetTrack *audioTrack = NULL;
    if ([mixAsset tracksWithMediaType:AVMediaTypeAudio].count != 0) {
        audioTrack = [[mixAsset tracksWithMediaType:AVMediaTypeAudio] firstObject];
    }
    
    AVMutableCompositionTrack *mixAudioTrack = [self.mcComposition.totalComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];

    
    CMTime endPoint = CMTimeAdd(_insertTime, mixAsset.duration);
    CMTime duration = CMTimeSubtract(CMTimeMinimum(endPoint, self.mcComposition.duration), _insertTime);
    
    [mixAudioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, duration) ofTrack:audioTrack atTime:_insertTime error:nil];
    
    AVMutableAudioMixInputParameters *mixParam = [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:mixAudioTrack];
    [mixParam setVolume:self.mixVolume atTime:_insertTime];
    [self.mcComposition.audioInstructions addObject:mixParam];
    
    self.mcComposition.audioEditComposition.inputParameters = self.mcComposition.audioInstructions;
    
}



@end
