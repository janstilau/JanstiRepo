//
//  WAAVSEVideoMixCommand.m
//  WA
//
//  Created by 黄锐灏 on 2017/9/15.
//  Copyright © 2017年 黄锐灏. All rights reserved.
//

#import "WAAVSEVideoMixCommand.h"
@interface WAAVSEVideoMixCommand ()

@end

@implementation WAAVSEVideoMixCommand

- (void)performWithAsset:(AVAsset *)asset mixAsset:(AVAsset *)mixAsset{
    
    [super performWithAsset:asset];

    [self mixWithAsset:mixAsset];
    
    
}

- (void)performWithAssets:(NSArray *)assets{
    
    AVAsset *asset = assets[0];
    [super performWithAsset:asset];
    
    for (int i = 1; i < assets.count; i ++) {
        [self mixWithAsset:assets[i]];
    }

}

- (void)mixWithAsset:(AVAsset *)mixAsset{
    
    NSError *error = nil;
    
    AVAssetTrack *mixAssetVideoTrack = nil;
    AVAssetTrack *mixAssetAudioTrack = nil;
    // Check if the asset contains video and audio tracks
    if ([[mixAsset tracksWithMediaType:AVMediaTypeVideo] count] != 0) {
        mixAssetVideoTrack = [mixAsset tracksWithMediaType:AVMediaTypeVideo][0];
    }
    
    if ([[mixAsset tracksWithMediaType:AVMediaTypeAudio] count] != 0) {
        mixAssetAudioTrack = [mixAsset tracksWithMediaType:AVMediaTypeAudio][0];
    }
    
    if (mixAssetVideoTrack) {
        
        CGSize natureSize = mixAssetVideoTrack.naturalSize;
        NSInteger degress = [self degressFromTransform:mixAssetVideoTrack.preferredTransform];
        
        AVMutableCompositionTrack *videoTrack =  [[self.mcComposition.totalComposition tracksWithMediaType:AVMediaTypeVideo] lastObject];
        BOOL needNewInstrunction = YES;
        
        if (!(degress % 360) && !self.mcComposition.videoInstructions.count && CGSizeEqualToSize(natureSize, self.mcComposition.totalComposition.naturalSize) && videoTrack) {
             [videoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, mixAsset.duration) ofTrack:mixAssetVideoTrack atTime:self.mcComposition.duration error:&error];
            needNewInstrunction = NO;
        }else if (!(degress % 360) && self.mcComposition.videoInstructions.count) {
            CGAffineTransform transform;
            AVMutableVideoCompositionInstruction *instruction = [self.mcComposition.videoInstructions lastObject];
            AVMutableVideoCompositionLayerInstruction *layerInstruction = (AVMutableVideoCompositionLayerInstruction *)instruction.layerInstructions[0];
            [layerInstruction getTransformRampForTime:self.mcComposition.duration startTransform:&transform endTransform:NULL timeRange:NULL];
            
            if (CGAffineTransformEqualToTransform (transform, mixAssetVideoTrack.preferredTransform) && CGSizeEqualToSize(self.mcComposition.lastInstructionSize, natureSize)) {
                
                [instruction setTimeRange:CMTimeRangeMake(instruction.timeRange.start, CMTimeAdd(instruction.timeRange.duration, mixAsset.duration))];
                [videoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, mixAsset.duration) ofTrack:mixAssetVideoTrack atTime:self.mcComposition.duration error:&error];
                needNewInstrunction = NO;
            }else{
                needNewInstrunction = YES;
            }
        }
      
        if (needNewInstrunction) {

            [super performVideoCompopsition];
        
            AVMutableCompositionTrack *newVideoTrack = [self.mcComposition.totalComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
        
            [newVideoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, mixAsset.duration) ofTrack:mixAssetVideoTrack atTime:self.mcComposition.duration error:&error];
        
            AVMutableVideoCompositionInstruction *instruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
            [instruction setTimeRange:CMTimeRangeMake(self.mcComposition.duration, mixAsset.duration)];

            AVMutableVideoCompositionLayerInstruction *layerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:newVideoTrack];
        
            CGSize renderSize = self.mcComposition.videoEditComposition.renderSize;
        
            if (degress == 90 || degress == 270) {
                natureSize = CGSizeMake(natureSize.height, natureSize.width);
            }
        
        
            CGFloat scale = MIN(renderSize.width / natureSize.width, renderSize.height / natureSize.height);
            
            self.mcComposition.lastInstructionSize = CGSizeMake(natureSize.width * scale, natureSize.height * scale);
        
            // 移至中心点
            CGPoint translate = CGPointMake((renderSize.width - natureSize.width * scale  ) * 0.5, (renderSize.height - natureSize.height * scale ) * 0.5);
        
            CGAffineTransform naturalTransform = mixAssetVideoTrack.preferredTransform;
            CGAffineTransform preferredTransform = CGAffineTransformMake(naturalTransform.a * scale, naturalTransform.b * scale, naturalTransform.c * scale, naturalTransform.d * scale, naturalTransform.tx * scale + translate.x, naturalTransform.ty * scale + translate.y);
        
            [layerInstruction setTransform:preferredTransform atTime:kCMTimeZero];
        
            instruction.layerInstructions = @[layerInstruction];
        
            [self.mcComposition.videoInstructions addObject:instruction];
            self.mcComposition.videoEditComposition.instructions = self.mcComposition.videoInstructions;
        }
        
    }
    
    if (mixAssetAudioTrack) {
        if (self.mcComposition.audioEditComposition) {
            AVMutableCompositionTrack *audioTrack = [self.mcComposition.totalComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
            [audioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, mixAsset.duration) ofTrack:mixAssetAudioTrack atTime:self.mcComposition.duration error:&error];
            
            AVMutableAudioMixInputParameters *audioParam = [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:mixAssetAudioTrack];
            [audioParam setVolume:1.0 atTime:kCMTimeZero];
            [self.mcComposition.audioInstructions addObject:audioParam];
            
            self.mcComposition.audioEditComposition.inputParameters = self.mcComposition.audioInstructions;
        }else{
            
            AVMutableCompositionTrack *audioTrack =  [[self.mcComposition.totalComposition tracksWithMediaType:AVMediaTypeAudio] lastObject];
            
            if (!audioTrack) {
                audioTrack = [self.mcComposition.totalComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
            }
            [audioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, mixAsset.duration) ofTrack:mixAssetAudioTrack atTime:self.mcComposition.duration error:&error];
        }

    }
    
    self.mcComposition.duration = CMTimeAdd(self.mcComposition.duration, mixAsset.duration);
    
}

@end
