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
 轨道由一个实例AVAssetTrack表示。在典型的简单情况下，一个音轨表示音频分量，另一个表示视频分量; 在复杂的组合中，可能存在多个重叠的音频和视频轨道。
 
 CMTime 是一个表示时间为有理数字的C结构，分子（int64_t值）和分母（int32_t 时间刻度）。在概念上，时间刻度指定分子占据的每个单位的分数。
 因此，如果时间刻度是4，每个单位代表四分之一秒; 如果时间尺度为10，则每个单位表示十分之一秒，依此类推。
 经常使用600的时间刻度，因为这是几种常用的帧速率的倍数：24 fps的电影，30 fps的NTSC（用于北美和日本的电视）和25 fps的PAL（用于欧洲电视）。使用600的时间刻度，您可以准确地表示这些系统中的任何数量的帧。
 除了简单的时间值之外，CMTime结构可以表示非数值值：+无穷大，-infinity和无限期。
 
 AVMutableComposition
    - AVMutableCompositionTrack Video
        - insertTimeRange:(CMTimeRange)timeRange ofTrack:(AVAssetTrack *)track atTime:(CMTime)startTime error:(NSError **)outError
        - AVCompositionTrackSegment
        - AVCompositionTrackSegment
        - AVCompositionTrackSegment
    - AVMutableCompositionTrack Audio
        - AVCompositionTrackSegment
        - AVCompositionTrackSegment
        - AVCompositionTrackSegment
 
 AVMutableAudioMix 表示对于音频的操作, 包含对于所有的 Audio AVMutableCompositionTrack 的操作. 所以, 它不是 AVMutableComposition 的一部分.
    - AVMutableAudioMixInputParameters 表示了, 如何操作某个AVMutableCompositionTrack上面的音频
         - AVMutableCompositionTrack Audio
         - setVolume
         - audioTimePitchAlgorithm
         - setVolumeRamp timeRange.
    - AVMutableAudioMixInputParameters
    - AVMutableAudioMixInputParameters
 
 AVMutableVideoComposition
    - frameDuration
    - renderSize
    - renderScale
    - animationTool
    - instructions
        - AVMutableVideoCompositionInstruction
            - timeRange
            - backgroundColor
            - layerInstructions
                - AVMutableVideoCompositionLayerInstruction
                    - AVAssetTrack
                    - Opacity
                    - OpacityRamp
                    - Transform
                    - TransformRamp
                    - CropRectangle
                    - CropRectangleRamp
                - AVMutableVideoCompositionLayerInstruction
                - AVMutableVideoCompositionLayerInstruction
        - AVMutableVideoCompositionInstruction
        - AVMutableVideoCompositionInstruction
 */

@interface WAAVSECommand ()

@property (nonatomic , strong) AVAssetTrack *assetVideoTrack;
@property (nonatomic , strong) AVAssetTrack *assetAudioTrack;
@property (nonatomic , assign) NSInteger trackDegress;
@property (nonatomic, strong) AVAsset *backingAsset;

@end

@implementation WAAVSECommand

- (instancetype)init{
    // 也就是说 ,一定会有一个
    return [self initWithComposition:[WACommandComposition new]];
}

- (instancetype)initWithComposition:(WACommandComposition *)composition{
    self = [super init];
    if(self != nil) {
        self.mcComposition = composition;
    }
    return self;
}


- (void)performWithAsset:(AVAsset *)asset {
    _backingAsset = asset;
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
    if(!self.mcComposition.totalComposition) {
        CMTime insertionPoint = kCMTimeZero;
        NSError *error = nil;
        AVMutableComposition *totalComposition = [AVMutableComposition composition];
        self.mcComposition.totalComposition = totalComposition;
        //  2.1､把视频轨道加入到混合器做出新的轨道
        if (self.assetVideoTrack != nil) {
            // 向 Conpositon 里面, 添加了一个 Video 的 Track, 但是这个 Track 里面现在没有数据 , Adds an empty track to the receiver.
            AVMutableCompositionTrack *videoTrack = [totalComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
            [videoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, [asset duration]) ofTrack:self.assetVideoTrack atTime:insertionPoint error:&error];
            /*
             Inserts all the tracks within a given time range of a specified asset into the receiver.
             - (BOOL)insertTimeRange:(CMTimeRange)timeRange ofAsset:(AVAsset *)asset atTime:(CMTime)startTime error:(NSError * _Nullable *)outError;
             */
            totalComposition.naturalSize = videoTrack.naturalSize; // 如果是音频轨道返回 CGSizeZero.
            // 在插入了一条轨道之后, self.composition.mutableComposition.duration 里面就有值了.
            self.mcComposition.duration = totalComposition.duration;
            self.trackDegress = [self degressFromTransform:self.assetVideoTrack.preferredTransform];
            if (self.trackDegress % 360) { // 如果方向不是正的.
                [self performVideoCompopsition];
            }
        }
        //  2.2､把音频轨道加入到混合器做出新的轨道
        if (self.assetAudioTrack != nil) {
            AVMutableCompositionTrack *compositionAudioTrack = [totalComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
            [compositionAudioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, [asset duration]) ofTrack:self.assetAudioTrack atTime:insertionPoint error:&error];
        }
    }
}

- (void)performVideoCompopsition{
    // 创建视频编辑的自定义处理器.
    if(!self.mcComposition.videoEditComposition) {
        AVMutableVideoComposition *videoEditComposition = [AVMutableVideoComposition videoComposition];
        self.mcComposition.videoEditComposition = videoEditComposition;
        // A time interval for which the video composition should render composed video frames.
        // 这个值控制, 编辑器以多高的频率来渲染原来的视频. 如果这个值调大, 会发生卡顿. 例如, 调成 30, 30 也就变成了一秒钟渲染一次.
        videoEditComposition.frameDuration = CMTimeMake(1, 30); // 30 fps
        // 编辑器渲染的大小, 如果宽高, 都变为一半, 那就是渲染左上角. 这个值不会进行拉伸操作, 如果只渲染左半部分, 那么最后的视频, 左半部分显示在中间, 其他黑框.
        videoEditComposition.renderSize = self.assetVideoTrack.naturalSize;
        
        // AVMutableVideoCompositionInstruction
        AVMutableVideoCompositionInstruction *passThroughInstruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
        passThroughInstruction.timeRange = CMTimeRangeMake(kCMTimeZero, [self.mcComposition.totalComposition duration]);
//        passThroughInstruction.backgroundColor = [[UIColor redColor] CGColor];
        AVAssetTrack *videoTrack = [self.mcComposition.totalComposition tracksWithMediaType:AVMediaTypeVideo][0];
        // An object used to modify the transform, cropping, and opacity ramps applied to a given track in a composition.
        //  增加渐变, 裁剪, 变形.
        AVMutableVideoCompositionLayerInstruction *passThroughLayer = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:videoTrack];
        [passThroughLayer setTransform:[self transformFromDegress:self.trackDegress natureSize:self.assetVideoTrack.naturalSize] atTime:kCMTimeZero];
// 增加裁剪, 只会输出裁剪位置的视频
//        [passThroughLayer setCropRectangle:CGRectMake(200, 300, 200, 300) atTime:kCMTimeZero];
//        渐变移动裁剪位置.
//        [passThroughLayer setCropRectangleRampFromStartCropRectangle:CGRectMake(0, 0, 200, 300) toEndCropRectangle:CGRectMake(500, 500, 200, 300) timeRange:CMTimeRangeMake(kCMTimeZero, self.backingAsset.duration)];
// 从亮到最后完全变暗.
//        [passThroughLayer setOpacityRampFromStartOpacity:1 toEndOpacity:0 timeRange:CMTimeRangeMake(kCMTimeZero, self.backingAsset.duration)];
        passThroughInstruction.layerInstructions = @[passThroughLayer];
        [self.mcComposition.videoInstructions addObject:passThroughInstruction];
        self.mcComposition.videoEditComposition.instructions = self.mcComposition.videoInstructions;
        
        if (self.trackDegress == 90 || self.trackDegress == 270) { // 如果是竖屏, 还要改变 renderSize
              self.mcComposition.videoEditComposition.renderSize = CGSizeMake(self.assetVideoTrack.naturalSize.height, self.assetVideoTrack.naturalSize.width);
        }
        self.mcComposition.lastInstructionSize = self.mcComposition.totalComposition.naturalSize  = self.mcComposition.videoEditComposition.renderSize;
    }
}

- (void)performAudioCompopsition{
    if (!self.mcComposition.audioEditComposition) {
        self.mcComposition.audioEditComposition = [AVMutableAudioMix audioMix];
        for (AVMutableCompositionTrack *audioTrack in [self.mcComposition.totalComposition tracksWithMediaType:AVMediaTypeAudio]) {
            AVMutableAudioMixInputParameters *audioParam =
            [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:audioTrack]; // 这里, 已经获取到音轨了.
            [audioParam setVolume:1.0 atTime:kCMTimeZero]; // 所以这里的变化, 只会影响到这个音轨.
            // 增加渐变效果.
//            [audioParam setVolumeRampFromStartVolume:1 toEndVolume:0 timeRange:CMTimeRangeMake(kCMTimeZero, self.backingAsset.duration)];
            [self.mcComposition.audioInstructions addObject:audioParam];
        }
        self.mcComposition.audioEditComposition.inputParameters = self.mcComposition.audioInstructions;
    }
}

// 这里, 应该和照片方向是一个概念.
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

// 根据 videoTrack 的preferredTransform, 修正, 具体原理不知道.
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
