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
   
    NSArray *natureTrackAry = [[self.mcComposition.totalEditComposition tracksWithMediaType:AVMediaTypeVideo] copy];
    
    for (AVCompositionTrack *track in natureTrackAry) {
        [self.mcComposition.totalEditComposition removeTrack:track];
    }
    self.mcComposition.fileType = AVFileTypeAppleM4A;
    self.mcComposition.presetName = AVAssetExportPresetAppleM4A;
    
}
@end
