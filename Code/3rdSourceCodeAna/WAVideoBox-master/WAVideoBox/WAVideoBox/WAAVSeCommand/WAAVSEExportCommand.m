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

- (void)performSaveAsset:(AVAsset *)asset byPath:(NSString *)path{
    
    NSFileManager *manager = [NSFileManager defaultManager];
    [manager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    // Remove Existing File
    [manager removeItemAtPath:path error:nil];
    
    // Step 2
    if (self.mcComposition.presetName.length == 0) {
        self.mcComposition.presetName = AVAssetExportPresetHighestQuality;
    }
    
    if (!self.mcComposition.fileType) {
        self.mcComposition.fileType = AVFileTypeMPEG4;
    }
    
    self.exportSession = [[AVAssetExportSession alloc] initWithAsset:asset presetName:self.mcComposition.presetName];
   
    self.exportSession.shouldOptimizeForNetworkUse = YES;
    self.exportSession.videoComposition = self.mcComposition.videoComposition;
    self.exportSession.audioMix = self.mcComposition.audioComposition;
    
    self.exportSession.timeRange = CMTimeRangeMake(kCMTimeZero, [self.mcComposition duration]);
    
    self.exportSession.outputURL = [NSURL fileURLWithPath:path];
    self.exportSession.outputFileType = self.mcComposition.fileType;
    
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
        
        if (self.ratioParam) {
            self.exportSession.fileLengthLimit = CMTimeGetSeconds(self.mcComposition.duration) * self.ratioParam * self.mcComposition.videoQuality * 1024 * 1024;
        }
        
    }
    
  
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
