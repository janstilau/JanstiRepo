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

// 里面代码过于复杂, 这里不看了
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
        
        AVMutableCompositionTrack *videoTrack =  [[self.editComposition.totalEditComposition tracksWithMediaType:AVMediaTypeVideo] lastObject];
        BOOL needNewInstrunction = YES;
        
        if (!(degress % 360) &&
            !self.editComposition.videoInstructions.count &&
            CGSizeEqualToSize(natureSize, self.editComposition.totalEditComposition.naturalSize) &&
            videoTrack) {
            // 如果方向正确, 没有编辑动作, 尺寸一样, 就直接插入.
            [videoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, mixAsset.duration) ofTrack:mixAssetVideoTrack atTime:self.editComposition.duration error:&error];
            needNewInstrunction = NO;
        }else if (!(degress % 360)
                  && self.editComposition.videoInstructions.count) {
            // 如果方向不正, 并且有视频编辑动作.
            CGAffineTransform transform;
            AVMutableVideoCompositionInstruction *instruction = [self.editComposition.videoInstructions lastObject];
            AVMutableVideoCompositionLayerInstruction *layerInstruction = (AVMutableVideoCompositionLayerInstruction *)instruction.layerInstructions[0];
            [layerInstruction getTransformRampForTime:self.editComposition.duration startTransform:&transform endTransform:NULL timeRange:NULL];
            
            if (CGAffineTransformEqualToTransform (transform, mixAssetVideoTrack.preferredTransform) && CGSizeEqualToSize(self.editComposition.lastInstructionSize, natureSize)) {
                [instruction setTimeRange:CMTimeRangeMake(instruction.timeRange.start, CMTimeAdd(instruction.timeRange.duration, mixAsset.duration))];
                [videoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, mixAsset.duration) ofTrack:mixAssetVideoTrack atTime:self.editComposition.duration error:&error];
                needNewInstrunction = NO;
            }else{
                needNewInstrunction = YES;
            }
        }
        
        if (needNewInstrunction) {
            [super performVideoCompopsition];
            AVMutableCompositionTrack *newVideoTrack = [self.editComposition.totalEditComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
            [newVideoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, mixAsset.duration) ofTrack:mixAssetVideoTrack atTime:self.editComposition.duration error:&error];
            AVMutableVideoCompositionInstruction *instruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
            [instruction setTimeRange:CMTimeRangeMake(self.editComposition.duration, mixAsset.duration)];
            AVMutableVideoCompositionLayerInstruction *layerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:newVideoTrack];
            CGSize renderSize = self.editComposition.videoEditComposition.renderSize;
            if (degress == 90 || degress == 270) {
                natureSize = CGSizeMake(natureSize.height, natureSize.width);
            }
            CGFloat scale = MIN(renderSize.width / natureSize.width, renderSize.height / natureSize.height);
            self.editComposition.lastInstructionSize = CGSizeMake(natureSize.width * scale, natureSize.height * scale);
            // 移至中心点
            CGPoint translate = CGPointMake((renderSize.width - natureSize.width * scale  ) * 0.5, (renderSize.height - natureSize.height * scale ) * 0.5);
            
            CGAffineTransform naturalTransform = mixAssetVideoTrack.preferredTransform;
            CGAffineTransform preferredTransform = CGAffineTransformMake(naturalTransform.a * scale, naturalTransform.b * scale, naturalTransform.c * scale, naturalTransform.d * scale, naturalTransform.tx * scale + translate.x, naturalTransform.ty * scale + translate.y);
            
            [layerInstruction setTransform:preferredTransform atTime:kCMTimeZero];
            
            instruction.layerInstructions = @[layerInstruction];
            
            [self.editComposition.videoInstructions addObject:instruction];
            self.editComposition.videoEditComposition.instructions = self.editComposition.videoInstructions;
        }
        
    }
    
    if (mixAssetAudioTrack) {
        if (self.editComposition.audioEditComposition) {
            AVMutableCompositionTrack *audioTrack = [self.editComposition.totalEditComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
            [audioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, mixAsset.duration) ofTrack:mixAssetAudioTrack atTime:self.editComposition.duration error:&error];
            
            AVMutableAudioMixInputParameters *audioParam = [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:mixAssetAudioTrack];
            [audioParam setVolume:1.0 atTime:kCMTimeZero];
            [self.editComposition.audioInstructions addObject:audioParam];
            
            self.editComposition.audioEditComposition.inputParameters = self.editComposition.audioInstructions;
        }else{
            AVMutableCompositionTrack *audioTrack =  [[self.editComposition.totalEditComposition tracksWithMediaType:AVMediaTypeAudio] lastObject];
            if (!audioTrack) {
                audioTrack = [self.editComposition.totalEditComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
            }
            [audioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, mixAsset.duration) ofTrack:mixAssetAudioTrack atTime:self.editComposition.duration error:&error];
        }
        
    }
    self.editComposition.duration = CMTimeAdd(self.editComposition.duration, mixAsset.duration);
    
}

@end
