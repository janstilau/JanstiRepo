//
//  WAAVSEGearboxCommand.m
//  WA
//
//  Created by 黄锐灏 on 2018/1/5.
//  Copyright © 2018年 黄锐灏. All rights reserved.
//

#import "WAAVSEGearboxCommand.h"
#import "WAAVSEGearboxCommandModel.h"

@interface WAAVSEGearboxCommand ()

@end

@implementation WAAVSEGearboxCommand

- (void)performWithAsset:(AVAsset *)asset scale:(CGFloat)scale{
    [super performWithAsset:asset];
    
    CMTime insertPoint = kCMTimeZero;
    for (AVMutableVideoCompositionInstruction *instruction in self.mcComposition.videoInstructions) {
        CMTime duration = instruction.timeRange.duration;
        [instruction setTimeRange:CMTimeRangeMake(insertPoint, CMTimeMake(duration.value / scale, duration.timescale))];
        insertPoint = CMTimeAdd(instruction.timeRange.start, instruction.timeRange.duration);
    }
    
    
    [[self.mcComposition.totalEditComposition tracksWithMediaType:AVMediaTypeVideo] enumerateObjectsUsingBlock:^(AVMutableCompositionTrack  *videoTrack, NSUInteger idx, BOOL * _Nonnull stop) {
        //        AVMutableVideoCompositionInstruction *instruction = self.composition.instructions[1];
        [videoTrack scaleTimeRange:videoTrack.timeRange toDuration: CMTimeMake(videoTrack.timeRange.duration.value / scale, videoTrack.timeRange.duration.timescale)];
    }];

    [[self.mcComposition.totalEditComposition tracksWithMediaType:AVMediaTypeAudio] enumerateObjectsUsingBlock:^(AVMutableCompositionTrack  *audioTrack, NSUInteger idx, BOOL * _Nonnull stop) {
        [audioTrack scaleTimeRange:audioTrack.timeRange toDuration: CMTimeMake(audioTrack.timeRange.duration.value / scale, audioTrack.timeRange.duration.timescale)];
    }];
    
    self.mcComposition.duration = CMTimeMultiplyByFloat64(self.mcComposition.duration, 1 / scale);
    
    // 保证最后一条能到视频最后
    AVMutableVideoCompositionInstruction *instruction = [self.mcComposition.videoInstructions lastObject];
    [instruction setTimeRange:CMTimeRangeMake(instruction.timeRange.start, CMTimeSubtract(self.mcComposition.duration, instruction.timeRange.start))];
}


- (void)performWithAsset:(AVAsset *)asset models:(NSArray<WAAVSEGearboxCommandModel *> *)gearboxModels{
    [super performWithAsset:asset];
    
    if (self.mcComposition.videoInstructions.count > 1) {
        NSAssert(NO, @"This method does not support multi-video processing for the time being.");
    }
    
    CMTime scaleDuration = kCMTimeZero;
    CMTime duration = kCMTimeZero;
    
    for (WAAVSEGearboxCommandModel *model in gearboxModels) {
        
        scaleDuration = CMTimeMultiplyByFloat64(model.duration, 1 / model.scale);
        // 视图变速
        for (AVMutableCompositionTrack  *videoTrack in [self.mcComposition.totalEditComposition tracksWithMediaType:AVMediaTypeVideo]) {
            [videoTrack scaleTimeRange:CMTimeRangeMake(model.beganDuration, model.duration) toDuration:scaleDuration];
        }
        
        // 音频变速
        for (AVMutableCompositionTrack  *audioTrack in [self.mcComposition.totalEditComposition tracksWithMediaType:AVMediaTypeAudio]) {
            
            [audioTrack scaleTimeRange:CMTimeRangeMake(model.beganDuration, model.duration) toDuration: scaleDuration];
        }
        
        // instruction变速
        duration = CMTimeAdd(duration, model.duration);
        
    }
    
    
    for (AVMutableVideoCompositionInstruction *instruction in self.mcComposition.videoInstructions) {
        [instruction setTimeRange:CMTimeRangeMake(kCMTimeZero,self.mcComposition.duration)];
    }
    
}

@end


