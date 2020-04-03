//
//  WAAVSEComposition.m
//  YCH
//
//  Created by 黄锐灏 on 2017/9/26.
//  Copyright © 2017 黄锐灏. All rights reserved.
//

#import "WACommandComposition.h"

@implementation WACommandComposition

- (NSMutableArray<AVMutableAudioMixInputParameters *> *)audioMixParams{
    if (!_audioInstructions) {
        _audioInstructions = [NSMutableArray array];
    }
    return _audioInstructions;
}

- (NSMutableArray<AVMutableVideoCompositionInstruction *> *)videoInstructions{
    if (!_videoInstructions) {
        _videoInstructions = [NSMutableArray array];
    }
    return _videoInstructions;
}

@end
