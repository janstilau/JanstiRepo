//
//  WAAVSEExportCommand.m
//  WA
//
//  Created by 黄锐灏 on 2017/8/14.
//  Copyright © 2017年 黄锐灏. All rights reserved.
//

#import "WAAVSEExportCommand.h"
@interface WAAVSEExportCommand ()

@property (nonatomic , assign) CGFloat ratioParam;

@end

@implementation WAAVSEExportCommand

- (instancetype)initWithComposition:(WACommandComposition *)composition{
    if (self = [super initWithComposition:composition]) {
        self.videoQuality = 0;
    }
    return self;
}

- (void)dealloc{
    
}

/*
 AVAssetExportSession 这个类到底是什么实现, 完完全全是封装到在自己的内部的. 仅仅是暴露了一些可以操作的属性和指令, 达到了简单输出的效果.
 An object that transcodes the contents of an asset source object to create an output of the form described by a specified export preset.
 */

- (void)performSaveAsset:(AVAsset *)asset byPath:(NSString *)path{
    
    NSFileManager *manager = [NSFileManager defaultManager];
    [manager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    // AVAssetExportSession 如果输出的位置有文件, 直接导出失败.
    [manager removeItemAtPath:path error:nil];
    
    // Setup output parameters
    if (self.mcComposition.presetName.length == 0) {
        self.mcComposition.presetName = AVAssetExportPresetHighestQuality;
    }
    if (!self.mcComposition.fileType) {
        self.mcComposition.fileType = AVFileTypeMPEG4;
    }
    
    self.exportSession = [[AVAssetExportSession alloc] initWithAsset:asset presetName:self.mcComposition.presetName];
   
    self.exportSession.shouldOptimizeForNetworkUse = YES;
    self.exportSession.timeRange = CMTimeRangeMake(kCMTimeZero, [self.mcComposition duration]);
    self.exportSession.outputURL = [NSURL fileURLWithPath:path];
    self.exportSession.outputFileType = self.mcComposition.fileType;
    
    // 所以, 视频如何编辑, 音频如何编辑, 是在导出的时候, 才起作用的. 之前做的, 都是指令的编辑工作.
    // The instructions for video composition, and indicates whether video composition is enabled for export.
    self.exportSession.videoComposition = self.mcComposition.videoEditComposition;
    // The parameters for audio mixing and an indication whether to enable nondefault audio mixing for export.
    self.exportSession.audioMix = self.mcComposition.audioEditComposition;
    
    if (self.videoQuality) {
        if ([self.mcComposition.presetName isEqualToString:AVAssetExportPreset640x480]) {
            self.ratioParam = 0.02 ;
        }
        if ([self.mcComposition.presetName isEqualToString:AVAssetExportPreset960x540]) {
            self.ratioParam = 0.04 ;
        }
        if ([self.mcComposition.presetName isEqualToString:AVAssetExportPreset1280x720]) {
            self.ratioParam = 0.08 ;
        }
        // fileLengthLimit 如何计算得出, 没有太明白作者的意图. 不过, 这里仅仅通过fileLengthLimit来控制输出的视频质量, 效果很差.
        if (self.ratioParam) {
            self.exportSession.fileLengthLimit = CMTimeGetSeconds(self.mcComposition.duration) * self.ratioParam * self.mcComposition.videoQuality * 1024 * 1024;
        }
    }
    
    /* 然后就是常规的输出操作.
     Because the export is performed asynchronously, this method returns immediately
     You can use progress to check on the progress.
    */
    [self.exportSession exportAsynchronouslyWithCompletionHandler:^(void){
        switch (self.exportSession.status) {
            case AVAssetExportSessionStatusCompleted:
                 [[NSNotificationCenter defaultCenter] postNotificationName:WAAVSEExportCommandCompletionNotification object:self];
                break;
            case AVAssetExportSessionStatusFailed:
                NSLog(@"%@",self.exportSession.error);
                [[NSNotificationCenter defaultCenter]
                 postNotificationName:WAAVSEExportCommandCompletionNotification
                 object:self userInfo:@{WAAVSEExportCommandError:self.exportSession.error}];
                break;
            case AVAssetExportSessionStatusCancelled:
                [[NSNotificationCenter defaultCenter]
                 postNotificationName:WAAVSEExportCommandCompletionNotification
                 object:self userInfo:@{WAAVSEExportCommandError:[NSError errorWithDomain:AVFoundationErrorDomain code:-10000 userInfo:@{NSLocalizedFailureReasonErrorKey:@"User cancel process!"}]}];
                break;
            default:
                break;
        }
    }];
}

- (void)performSaveByPath:(NSString *)path{
    [self performSaveAsset:self.mcComposition.totalComposition byPath:path];
}

@end
