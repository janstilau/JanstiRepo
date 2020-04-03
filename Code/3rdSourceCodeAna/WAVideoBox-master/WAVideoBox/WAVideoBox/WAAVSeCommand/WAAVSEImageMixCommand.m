//
//  WAAVSEImageMixCommand.m
//  WA
//
//  Created by 黄锐灏 on 2017/9/25.
//  Copyright © 2017年 黄锐灏. All rights reserved.
//

#import "WAAVSEImageMixCommand.h"


@interface WAAVSEImageMixCommand ()


@property (nonatomic , copy) CGRect (^imageLayerRect)(CGSize);

@end

@implementation WAAVSEImageMixCommand

- (void)performWithAsset:(AVAsset *)asset{
    [super performWithAsset:asset];
    if (![[self.mcComposition.totalEditComposition tracksWithMediaType:AVMediaTypeVideo] count]) { return; }
    // 3､通过videoCompostion合成
    // 3.2､创建视频画面合成器
    [super performVideoCompopsition];
    CGSize videoSize = self.mcComposition.videoEditComposition.renderSize;
    CALayer *imageLayer;
    if (self.imageLayerRect) {
        imageLayer = [self buildImageLayerWithRect:self.imageLayerRect(videoSize)];
        if (self.fileUrl) {
            [imageLayer addAnimation:[self buildAnimationForGif] forKey:@"gif"];
        }
    }
    if (!self.mcComposition.videoLayer || !self.mcComposition.parentLayer) {
        CALayer *parentLayer = [CALayer layer];
        CALayer *videoLayer = [CALayer layer];
        parentLayer.frame = CGRectMake(0, 0, videoSize.width, videoSize.height);
        videoLayer.frame = CGRectMake(0, 0, videoSize.width, videoSize.height);
        self.mcComposition.videoLayer = videoLayer;
        self.mcComposition.parentLayer = parentLayer;
    }
    
    if (self.imageBg) {
        self.mcComposition.videoLayer.opaque = YES;
         self.mcComposition.videoLayer.opacity = 0.8;
        [self.mcComposition.parentLayer addSublayer:imageLayer];
        [self.mcComposition.parentLayer addSublayer:self.mcComposition.videoLayer];
    }else{
        [self.mcComposition.parentLayer addSublayer:self.mcComposition.videoLayer];
        [self.mcComposition.parentLayer addSublayer:imageLayer];
    }
    /*
     AVVideoCompositionCoreAnimationTool
     An object used to incorporate Core Animation into a video composition.
     */
    // 这里我不太明白, 几个 Layer 是如何合成到视频上的. 和视频的 Size 的关系.
    self.mcComposition.videoEditComposition.animationTool = [AVVideoCompositionCoreAnimationTool videoCompositionCoreAnimationToolWithPostProcessingAsVideoLayer: self.mcComposition.videoLayer inLayer: self.mcComposition.parentLayer];
}

- (void)imageLayerRectWithVideoSize:(CGRect (^)(CGSize))imageLayerRect{
    if (imageLayerRect) {
        self.imageLayerRect = imageLayerRect;
    }
}

- (CALayer *)buildImageLayerWithRect:(CGRect)rect{
    CALayer *imageLayer = [CALayer layer];
    if (self.image) {
        imageLayer.contents = (__bridge id) (self.image.CGImage);
    }
    imageLayer.frame = rect;
    return imageLayer;
}

- (CAKeyframeAnimation *)buildAnimationForGif{
    // KeyFrame 的 path 是 contents.
    CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:@"contents"];
    animation.beginTime = AVCoreAnimationBeginTimeAtZero;
    animation.removedOnCompletion = YES;
    
    NSMutableArray * frames = [NSMutableArray new];
    NSMutableArray *delayTimes = [NSMutableArray new];
    CGFloat totalTime = 0.0;
    CGFloat gifWidth;
    CGFloat gifHeight;
    CGImageSourceRef gifSource = CGImageSourceCreateWithURL((CFURLRef)self.fileUrl, NULL);
   
    // 下面的这个方法, 是通用给的处理 Gif 的方法.
    // The number of images. If the image source is a multilayered PSD file, the function returns 1.
    size_t frameCount = CGImageSourceGetCount(gifSource);
    for (size_t i = 0; i < frameCount; ++i) {
        CGImageRef frame = CGImageSourceCreateImageAtIndex(gifSource, i, NULL);
        [frames addObject:(__bridge id)frame];
        CGImageRelease(frame);
        
        NSDictionary *dict = (NSDictionary*)CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(gifSource, i, NULL));
        gifWidth = [[dict valueForKey:(NSString*)kCGImagePropertyPixelWidth] floatValue];
        gifHeight = [[dict valueForKey:(NSString*)kCGImagePropertyPixelHeight] floatValue];
        
        NSDictionary *gifDict = [dict valueForKey:(NSString*)kCGImagePropertyGIFDictionary];
        [delayTimes addObject:[gifDict valueForKey:(NSString*)kCGImagePropertyGIFUnclampedDelayTime]];
        totalTime = totalTime + [[gifDict valueForKey:(NSString*)kCGImagePropertyGIFUnclampedDelayTime] floatValue];
    }
    
    if (gifSource) CFRelease(gifSource);
    
    NSMutableArray *times = [NSMutableArray arrayWithCapacity:3];
    CGFloat currentTime = 0;
    NSInteger count = delayTimes.count;
    for (int i = 0; i < count; ++i) {
        [times addObject:[NSNumber numberWithFloat:(currentTime / totalTime)]];
        currentTime += [[delayTimes objectAtIndex:i] floatValue];
    }
    NSMutableArray *images = [NSMutableArray arrayWithCapacity:3];
    for (int i = 0; i < count; ++i) {
        [images addObject:[frames objectAtIndex:i]];
    }
    animation.keyTimes = times;
    animation.values = images;
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    animation.duration = totalTime;
    animation.repeatCount = HUGE_VALF;
    return animation;
}
@end
