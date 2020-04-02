//
//  MCVideoExporter.m
//  TZImagePickerController
//
//  Created by JustinLau on 2020/4/1.
//  Copyright © 2020 谭真. All rights reserved.
//

#import "MCVideoExporter.h"
#import "SDAVAssetExportSession.h"


/*
 
 https://www.jianshu.com/p/4f69c22c6dce
 
 码率（bit rate）是指数据传输时单位时间传送的数据位数，单位是bit per second(bps)。简单的说码率=视频文件大小/视频时长。
 帧率（frame rate）指每秒钟有多少个画面，单位Frame Per Second简称FPS。
 视频实际是由一组连续的图片组成的，由于人眼有视觉暂留现象，画面帧率高于16的时候大脑就会把图片连贯成动画，高于24大脑就认为是非常流畅了。
 所以24FPS是视频行业的标准。 游戏行业为了更逼真的效果获取更好的用户体验将标准定为30FPS。
 分辨率：习惯上我们说的分辨率是指图像的高/宽像素值
 
 H264视频编码。所谓视频编码方式就是指通过特定的压缩技术，将某个视频格式的文件转换成另一种视频格式文件的方式。
 Profile 越高，压缩比就越高，但是编码、解码时要求的设备性能也就越高，编码、解码的效率也就越低。
 也就是说, 如果我们想要压缩文件的大小, 加高 Profile 就好, 但是对于硬件的影响就越大.
 
 iPhone 3GS 和更早的设备支持 Baseline Profile level 3.0 及更低的级别
 iPhone 4S 支持 High Profile level 4.1 及更低的级别
 iPhone 5C 支持 High Profile level 4.1 及更低的级别
 iPhone 5S 支持 High Profile level 4.1 及更低的级别
 iPad 1 支持 Main Profile level 3.1 及更低的级别
 iPad 2 支持 Main Profile level 3.1 及更低的级别
 iPad with Retina display 支持 High Profile level 4.1 及更低的级别
 iPad mini 支持 High Profile level 4.1 及更低的级别
 
 要想获得最大的视频压缩率采取的最好办法就是：
 （1）指定highprofile
 （2）降低帧率
 （3）适当降低分辨率
而 AVAssetExportSession 是不能制定修改这些值的.
思路很简单，先通过assetReader取出每一帧sampleBuffer（音频或视频），然后指定压缩参数后将每一帧传给assetWriter最终实现自定义压缩的目的。
 */


@interface MCVideoExporter()

@property (nonatomic, strong) SDAVAssetExportSession *encoder;

@end

@implementation MCVideoExporter

- (NSString *)outputVideoPath {
    return [NSString stringWithFormat:@"%@/%@.mp4", NSHomeDirectory(), [NSDate date]];
}

- (void)startExport {
    if (!_asset) { return; }
    SDAVAssetExportSession *encoder = [SDAVAssetExportSession.alloc initWithAsset:_asset];
    encoder.outputFileType = AVFileTypeMPEG4;
    encoder.outputURL = [NSURL fileURLWithPath:[self outputVideoPath]];
    CMTimeRange duration = CMTimeRangeMake(kCMTimeZero, [_asset duration]);
    duration.duration.value /= 2;
    encoder.timeRange = duration;
    NSLog(@"%@", [self outputVideoPath]);
    encoder.videoSettings = @
    {
        AVVideoCodecKey: AVVideoCodecH264,
        AVVideoWidthKey: @720,
        AVVideoHeightKey: @1280,
        AVVideoCompressionPropertiesKey: @
        {
            AVVideoAverageBitRateKey: @2500000,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
        },
    };
    encoder.audioSettings = @
    {
        AVFormatIDKey: @(kAudioFormatMPEG4AAC),
        AVNumberOfChannelsKey: @2,
        AVSampleRateKey: @44100,
        AVEncoderBitRateKey: @128000,
    };
    [encoder exportAsynchronouslyWithCompletionHandler:^
    {
        if (encoder.status == AVAssetExportSessionStatusCompleted)
        {
            NSLog(@"Video export succeeded");
        }
        else if (encoder.status == AVAssetExportSessionStatusCancelled)
        {
            NSLog(@"Video export cancelled");
        }
        else
        {
            NSLog(@"Video export failed with error: %@ (%d)", encoder.error.localizedDescription, encoder.error.code);
        }
    }];
}


- (UIImage *)generateCoverImage {
    AVAssetImageGenerator *imageGenerator = [[AVAssetImageGenerator alloc] initWithAsset:_asset];
    Float64 durationSeconds = CMTimeGetSeconds([_asset duration]);
    CMTime midpoint = CMTimeMakeWithSeconds(durationSeconds/2.0, 600);
    NSError *error;
    CMTime actualTime;
    CGImageRef halfWayImage = [imageGenerator copyCGImageAtTime:midpoint actualTime:&actualTime error:&error];
    if (!halfWayImage) { return  nil; }
    UIImage *result = [UIImage imageWithCGImage:halfWayImage];
    CGImageRelease(halfWayImage);
    return result;
}

- (void)generateImages {
    AVAssetImageGenerator *imageGenerator = [[AVAssetImageGenerator alloc] initWithAsset:_asset];
    Float64 durationSeconds = CMTimeGetSeconds([_asset duration]);
    CMTime beginPoint = CMTimeMakeWithSeconds(0, 600);
    CMTime midpoint = CMTimeMakeWithSeconds(durationSeconds/2.0, 600);
    CMTime endPoint = CMTimeMakeWithSeconds(durationSeconds, 600);
    NSArray *times = @[
        [NSValue valueWithCMTime:beginPoint],
        [NSValue valueWithCMTime:midpoint],
        [NSValue valueWithCMTime:endPoint]
    ];
    NSMutableArray *resultM = [NSMutableArray arrayWithCapacity:3];
    [imageGenerator generateCGImagesAsynchronouslyForTimes:times completionHandler:^(CMTime requestedTime, CGImageRef image, CMTime actualTime, AVAssetImageGeneratorResult result, NSError *error) {
        if (!image) { return; }
        UIImage *resultImg = [UIImage imageWithCGImage:image];
        [resultM addObject:resultImg];
        if (resultM.count == times.count) {
            self.imgGeneratedCallBack? self.imgGeneratedCallBack(resultM): nil;
        }
    }];
}


@end
