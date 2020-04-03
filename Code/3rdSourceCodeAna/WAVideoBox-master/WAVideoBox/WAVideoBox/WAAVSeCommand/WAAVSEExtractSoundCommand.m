//
//  WAAVSEExtractSoundCommand.m
//  YCH
//
//  Created by 黄锐灏 on 2019/1/11.
//  Copyright © 2019 黄锐灏. All rights reserved.
//

#import "WAAVSEExtractSoundCommand.h"

@implementation WAAVSEExtractSoundCommand
- (void)performWithAsset:(AVAsset *)asset{
    [super performWithAsset:asset];
   
    NSArray *natureTrackAry = [[self.editComposition.totalEditComposition tracksWithMediaType:AVMediaTypeVideo] copy];
    
    for (AVCompositionTrack *track in natureTrackAry) {
        [self.editComposition.totalEditComposition removeTrack:track];
    }
    self.editComposition.fileType = AVFileTypeAppleM4A;
    self.editComposition.presetName = AVAssetExportPresetAppleM4A;
    
}
@end
