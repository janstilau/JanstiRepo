//
//  WAAVSECommand.m
//  WA
//
//  Created by 黄锐灏 on 2017/8/14.
//  Copyright © 2017年 黄锐灏. All rights reserved.
//

#import "WAAVSECommand.h"

/*
 Asset包含旨在一起显示或处理的每个轨道的集合，每个轨道均包含（但不限于）音频，视频，文本，隐藏式字幕和字幕。
 Asset对象提供有关整个资源的信息，例如其持续时间或标题，以及呈现的提示，如自然大小
 轨道由一个实例AVAssetTrack表示，如图6-2所示。在典型的简单情况下，一个音轨表示音频分量，另一个表示视频分量; 在复杂的组合中，可能存在多个重叠的音频和视频轨道。
 
 是一个表示时间为有理数字的C结构，分子（int64_t值）和分母（int32_t 时间刻度）。在概念上，时间刻度指定分子占据的每个单位的分数。
 因此，如果时间刻度是4，每个单位代表四分之一秒; 如果时间尺度为10，则每个单位表示十分之一秒，依此类推。您经常使用600的时间刻度，因为这是几种常用的帧速率的倍数：24 fps的电影，30 fps的NTSC（用于北美和日本的电视）和25 fps的PAL（用于欧洲电视）。使用600的时间刻度，您可以准确地表示这些系统中的任何数量的帧。
 除了简单的时间值之外，CMTime结构可以表示非数值值：+无穷大，-infinity和无限期。
 */

@interface WAAVSECommand ()

@property (nonatomic , strong) AVAssetTrack *assetVideoTrack;

@property (nonatomic , strong) AVAssetTrack *assetAudioTrack;

@property (nonatomic , assign) NSInteger trackDegress;

@end

@implementation WAAVSECommand

- (instancetype)init{
    return [self initWithComposition:[WAAVSEComposition new]];
}

- (instancetype)initWithComposition:(WAAVSEComposition *)composition{
    self = [super init];
    if(self != nil) {
        self.composition = composition;
    }
    return self;
}


- (void)performWithAsset:(AVAsset *)asset
{
    
    // 1.1､视频资源的轨道
    if (!self.assetVideoTrack) {
        if ([asset tracksWithMediaType:AVMediaTypeVideo].count != 0) {
            self.assetVideoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] firstObject];
        }
    }
    
    // 1.2､音频资源的轨道
    if (!self.assetAudioTrack) {
        if ([asset tracksWithMediaType:AVMediaTypeAudio].count != 0) {
            self.assetAudioTrack = [[asset tracksWithMediaType:AVMediaTypeAudio] firstObject];
        }
    }
    
    // 2､创建混合器
  
    if(!self.composition.mutableComposition) {
        
        // 要混合的时间
        CMTime insertionPoint = kCMTimeZero;
        NSError *error = nil;
        
        
        
        self.composition.mutableComposition = [AVMutableComposition composition];
        //  2.1､把视频轨道加入到混合器做出新的轨道
        if (self.assetVideoTrack != nil) {
            
            // 向 Conpositon 里面, 添加了一个 Video 的 Track, 但是这个 Track 里面现在没有数据 , Adds an empty track to the receiver.
            AVMutableCompositionTrack *compostionVideoTrack = [self.composition.mutableComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
            // 向 Video Track 里面, 输入一个归到. 可以用音频处理软件 premiere 来理解.
            [compostionVideoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, [asset duration]) ofTrack:self.assetVideoTrack atTime:insertionPoint error:&error];

            self.composition.duration = self.composition.mutableComposition.duration;
            
            self.trackDegress = [self degressFromTransform:self.assetVideoTrack.preferredTransform];
            self.composition.mutableComposition.naturalSize = compostionVideoTrack.naturalSize;
            if (self.trackDegress % 360) {
                [self performVideoCompopsition];
            }
            
        }
        
        //  2.2､把音频轨道加入到混合器做出新的轨道
        if (self.assetAudioTrack != nil) {
            
            AVMutableCompositionTrack *compositionAudioTrack = [self.composition.mutableComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
        
            [compositionAudioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, [asset duration]) ofTrack:self.assetAudioTrack atTime:insertionPoint error:&error];
        }
        
    }
    
}

- (void)performVideoCompopsition{
   
    if(!self.composition.mutableVideoComposition) {
        
        self.composition.mutableVideoComposition = [AVMutableVideoComposition videoComposition];
        self.composition.mutableVideoComposition.frameDuration = CMTimeMake(1, 30); // 30 fps
        self.composition.mutableVideoComposition.renderSize = self.assetVideoTrack.naturalSize;
    
        
        AVMutableVideoCompositionInstruction *passThroughInstruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
        passThroughInstruction.timeRange = CMTimeRangeMake(kCMTimeZero, [self.composition.mutableComposition duration]);

        AVAssetTrack *videoTrack = [self.composition.mutableComposition tracksWithMediaType:AVMediaTypeVideo][0];

        AVMutableVideoCompositionLayerInstruction *passThroughLayer = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:videoTrack];
        [passThroughLayer setTransform:[self transformFromDegress:self.trackDegress natureSize:self.assetVideoTrack.naturalSize] atTime:kCMTimeZero];
        passThroughInstruction.layerInstructions = @[passThroughLayer];
        
        [self.composition.instructions addObject:passThroughInstruction];
        self.composition.mutableVideoComposition.instructions = self.composition.instructions;
        
        if (self.trackDegress == 90 || self.trackDegress == 270) {
              self.composition.mutableVideoComposition.renderSize = CGSizeMake(self.assetVideoTrack.naturalSize.height, self.assetVideoTrack.naturalSize.width);
        }
        
        self.composition.lastInstructionSize = self.composition.mutableComposition.naturalSize  = self.composition.mutableVideoComposition.renderSize;
        
    }

}

- (void)performAudioCompopsition{
    if (!self.composition.mutableAudioMix) {
        
        self.composition.mutableAudioMix = [AVMutableAudioMix audioMix];
        
        for (AVMutableCompositionTrack *compostionVideoTrack in [self.composition.mutableComposition tracksWithMediaType:AVMediaTypeAudio]) {
      
            AVMutableAudioMixInputParameters *audioParam = [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:compostionVideoTrack];
            [audioParam setVolume:1.0 atTime:kCMTimeZero];
            [self.composition.audioMixParams addObject:audioParam];
        }
        self.composition.mutableAudioMix.inputParameters = self.composition.audioMixParams;
    }
}


- (NSUInteger)degressFromTransform:(CGAffineTransform)transForm
{
    NSUInteger degress = 0;
    
    if(transForm.a == 0 && transForm.b == 1.0 && transForm.c == -1.0 && transForm.d == 0){
        // Portrait
        degress = 90;
    }else if(transForm.a == 0 && transForm.b == -1.0 && transForm.c == 1.0 && transForm.d == 0){
        // PortraitUpsideDown
        degress = 270;
    }else if(transForm.a == 1.0 && transForm.b == 0 && transForm.c == 0 && transForm.d == 1.0){
        // LandscapeRight
        degress = 0;
    }else if(transForm.a == -1.0 && transForm.b == 0 && transForm.c == 0 && transForm.d == -1.0){
        // LandscapeLeft
        degress = 180;
    }
    
    return degress;
}

- (CGAffineTransform)transformFromDegress:(float)degress natureSize:(CGSize)natureSize{
    /** 矩阵校正 */
    // x = ax1 + cy1 + tx,y = bx1 + dy2 + ty
    if (degress == 90) {
        return CGAffineTransformMake(0, 1, -1, 0, natureSize.height, 0);
    }else if (degress == 180){
        return CGAffineTransformMake(-1, 0, 0, -1, natureSize.width , natureSize .height);
    }else if (degress == 270){
        return CGAffineTransformMake(0, -1, 1, 0, -natureSize.height, 2 * natureSize.width);
    }else{
        return CGAffineTransformIdentity;
    }
}



NSString *const WAAVSEExportCommandCompletionNotification = @"WAAVSEExportCommandCompletionNotification";
NSString* const WAAVSEExportCommandError = @"WAAVSEExportCommandError";

@end
