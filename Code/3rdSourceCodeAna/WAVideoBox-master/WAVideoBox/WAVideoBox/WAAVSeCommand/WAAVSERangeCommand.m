//
//  WAAVSERangeCommand.m
//  WA
//
//  Created by 黄锐灏 on 2018/1/29.
//  Copyright © 2018年 黄锐灏. All rights reserved.
//

#import "WAAVSERangeCommand.h"

@implementation WAAVSERangeCommand

/*
 When comparing CMTimes, it is recommended to use CMTIME_COMPARE_INLINE macro since it makes comparison expressions much more readable by putting the comparison operation between the operands.
 If the two CMTimes are numeric (i.e.. not invalid, infinite, or indefinite), and have different epochs, it is considered that times in numerically larger epochs are always greater than times in numerically smaller epochs. Since this routine will be used to sort lists by time, it needs to give all values (even invalid and indefinite ones) a strict ordering to guarantee that sort algorithms terminate safely. The order chosen is somewhat arbitrary: -infinity < all finite values < indefinite < +infinity < invalid
 Invalid CMTimes are considered to be equal to other invalid CMTimes, and greater than any other CMTime. Positive infinity is considered to be less than any invalid CMTime, equal to itself, and greater than any other CMTime. An indefinite CMTime is considered to be less than any invalid CMTime, less than positive infinity, equal to itself, and greater than any other CMTime. Negative infinity is considered to be equal to itself, and less than any other CMTime.
 */

- (void)performWithAsset:(AVAsset *)asset timeRange:(CMTimeRange)range{
    [super performWithAsset:asset];
    
    if (CMTimeCompare(self.editComposition.duration, CMTimeAdd(range.start, range.duration)) != 1) {
        NSAssert(NO, @"Range out of video duration");
    }
    // 轨道裁剪
    for (AVMutableCompositionTrack *compositionTrack in [self.editComposition.totalEditComposition tracksWithMediaType:AVMediaTypeAudio]) {
        [self subTimeRaneWithTrack:compositionTrack range:range];
    }
    
    for (AVMutableCompositionTrack *compositionTrack in [self.editComposition.totalEditComposition tracksWithMediaType:AVMediaTypeVideo]) {
        [self subTimeRaneWithTrack:compositionTrack range:range];
    }
    
    self.editComposition.duration = range.duration;
}

/*
 裁剪操作, 是在 Track 进行裁剪的.
 Removing a time range does not cause the track to be removed from the composition. Instead it removes or truncates track segments that intersect with the time range.
 */
- (void)subTimeRaneWithTrack:(AVMutableCompositionTrack *)compositionTrack range:(CMTimeRange)range{
    CMTime endPoint = CMTimeAdd(range.start, range.duration);
    if (CMTimeCompare(self.editComposition.duration,endPoint) != -1) {
        [compositionTrack removeTimeRange:CMTimeRangeMake(endPoint,CMTimeSubtract(self.editComposition.duration, endPoint))];
    }
    if (CMTimeGetSeconds(range.start)) {
        [compositionTrack removeTimeRange:CMTimeRangeMake(kCMTimeZero, range.start)];
    }
}

@end
