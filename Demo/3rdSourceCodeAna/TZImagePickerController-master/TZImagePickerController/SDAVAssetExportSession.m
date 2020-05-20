#import "SDAVAssetExportSession.h"

@interface SDAVAssetExportSession ()

@property (nonatomic, assign, readwrite) float progress;

@property (nonatomic, strong) AVAssetReader *reader;
@property (nonatomic, strong) AVAssetReaderVideoCompositionOutput *videoOutput;
@property (nonatomic, strong) AVAssetReaderTrackOutput *trackAudioOutput;

@property (nonatomic, strong) AVAssetWriter *writer;
@property (nonatomic, strong) AVAssetWriterInput *videoInput;
@property (nonatomic, strong) AVAssetWriterInput *audioInput;

@property (nonatomic, strong) dispatch_queue_t inputQueue;
@property (nonatomic, strong) void (^completionHandler)(void);

@end

@implementation SDAVAssetExportSession
{
    NSError *_error;
    NSTimeInterval _duration;
    CMTime _lastSamplePresentationTime;
}

+ (id)exportSessionWithAsset:(AVAsset *)asset
{
    return [SDAVAssetExportSession.alloc initWithAsset:asset];
}

- (id)initWithAsset:(AVAsset *)asset
{
    if ((self = [super init])) {
        _asset = asset;
        _timeRange = CMTimeRangeMake(kCMTimeZero, kCMTimePositiveInfinity);
        _shouldOptimizeForNetworkUse = YES;
    }
    
    return self;
}

- (NSError *)prepareEncoder {
    if (!self.outputURL){
        return
        [NSError errorWithDomain:AVFoundationErrorDomain code:AVErrorExportFailed userInfo:@{
            NSLocalizedDescriptionKey: @"Output URL not set"
        }];
    }
    
    NSError *readerError;
    self.reader = [AVAssetReader.alloc initWithAsset:self.asset error:&readerError];
    if (readerError) { return readerError; }
    self.reader.timeRange = self.timeRange;
    
    NSError *writerError;
    self.writer = [AVAssetWriter assetWriterWithURL:self.outputURL fileType:self.outputFileType error:&writerError];
    if (writerError) { return writerError; }
    self.writer.shouldOptimizeForNetworkUse = self.shouldOptimizeForNetworkUse;
    self.writer.metadata = self.metadata;
    
    return nil;
}

- (void)exportAsynchronouslyWithCompletionHandler:(void (^)(void))handler
{
    NSParameterAssert(handler != nil);
    [self cancelExport];
    
    NSError *error = [self prepareEncoder];
    if (error) {
        _error = error;
        handler();
        return;
    }
    
    self.completionHandler = handler;
    
    NSArray *videoTracks = [self.asset tracksWithMediaType:AVMediaTypeVideo];
    if (CMTIME_IS_VALID(self.timeRange.duration) && !CMTIME_IS_POSITIVE_INFINITY(self.timeRange.duration)){
        _duration = CMTimeGetSeconds(self.timeRange.duration);
    } else {
        _duration = CMTimeGetSeconds(self.asset.duration);
    }
    
    if (videoTracks.count > 0) {
        // Video output
        NSDictionary *outputVideoSetting = @{
                           (id)kCVPixelBufferPixelFormatTypeKey     : @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange),
                           (id)kCVPixelBufferIOSurfacePropertiesKey : [NSDictionary dictionary]
                      };
        self.videoOutput = [AVAssetReaderVideoCompositionOutput assetReaderVideoCompositionOutputWithVideoTracks:videoTracks videoSettings:outputVideoSetting];
        self.videoOutput.alwaysCopiesSampleData = NO;
        self.videoOutput.videoComposition = [self fixedCompositionWithAsset:_asset];
        if ([self.reader canAddOutput:self.videoOutput]) {
            [self.reader addOutput:self.videoOutput];
        }
        
        // Video input
        self.videoInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:self.videoSettings];
        AVAssetTrack *videoTrack = videoTracks.firstObject;
        self.videoInput.transform = videoTrack.preferredTransform;
        self.videoInput.expectsMediaDataInRealTime = NO;
        if ([self.writer canAddInput:self.videoInput])
        {
            [self.writer addInput:self.videoInput];
        }
    }
    
    NSArray *audioTracks = [self.asset tracksWithMediaType:AVMediaTypeAudio];
    if (audioTracks.count > 0) {
        // Audio Output
        NSDictionary *outputAudioSetting = @{
            AVFormatIDKey : @(kAudioFormatLinearPCM)
        };
        self.trackAudioOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:audioTracks.firstObject outputSettings:outputAudioSetting];
        self.trackAudioOutput.alwaysCopiesSampleData = NO;
        if ([self.reader canAddOutput:self.trackAudioOutput]) {
            [self.reader addOutput:self.trackAudioOutput];
        }
        
        // Audio input
        self.audioInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:self.audioSettings];
        self.audioInput.expectsMediaDataInRealTime = NO;
        if ([self.writer canAddInput:self.audioInput]) {
            [self.writer addInput:self.audioInput];
        }
    } else {
        self.trackAudioOutput = nil;
    }
    
    
    [self.writer startWriting];
    [self.reader startReading];
    [self.writer startSessionAtSourceTime:self.timeRange.start];
    
    __block BOOL videoCompleted = NO;
    __block BOOL audioCompleted = NO;
    __weak typeof(self) wself = self;
    self.inputQueue = dispatch_queue_create("VideoEncoderInputQueue", DISPATCH_QUEUE_SERIAL);
    if (videoTracks.count > 0) {
        [self.videoInput requestMediaDataWhenReadyOnQueue:self.inputQueue usingBlock:^ {
            if (![wself encodeReadySamplesFromOutput:wself.videoOutput toInput:wself.videoInput]) {
                @synchronized(wself) {
                    videoCompleted = YES;
                    if (audioCompleted) {
                        [wself finish];
                    }
                }
            }
        }];
    } else {
        videoCompleted = YES;
    }
    
    if (self.trackAudioOutput) {
        [self.audioInput requestMediaDataWhenReadyOnQueue:self.inputQueue usingBlock:^ {
            if (![wself encodeReadySamplesFromOutput:wself.trackAudioOutput toInput:wself.audioInput]) {
                @synchronized(wself) {
                    audioCompleted = YES;
                    if (videoCompleted) {
                        [wself finish];
                    }
                }
            }
        }];
    } else {
        audioCompleted = YES;
    }
}

- (AVMutableVideoComposition *)fixedCompositionWithAsset:(AVAsset *)videoAsset {
    NSArray *tracks = [videoAsset tracksWithMediaType:AVMediaTypeVideo];
    AVAssetTrack *videoTrack = [tracks objectAtIndex:0];
    
    AVMutableVideoComposition *videoComposition = [AVMutableVideoComposition videoComposition];
    CGFloat frameRate = [videoTrack nominalFrameRate];
    if (frameRate <= 0) {
        frameRate = 30;
    }
    videoComposition.frameDuration = CMTimeMake(1, frameRate);
    videoComposition.renderSize = videoTrack.naturalSize;
    AVMutableVideoCompositionInstruction *roateInstruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    roateInstruction.timeRange = CMTimeRangeMake(kCMTimeZero, [videoAsset duration]);
    AVMutableVideoCompositionLayerInstruction *roateLayerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:videoTrack];
    [roateLayerInstruction setTransform:CGAffineTransformIdentity atTime:kCMTimeZero];
    
    CGAffineTransform resultTransform = CGAffineTransformIdentity;
    int degrees = [self degressFromVideoFileWithAsset:videoAsset];
    if (degrees != 0) {
        if (degrees == 90) {
            CGAffineTransform translateToCenter = CGAffineTransformMakeTranslation(videoTrack.naturalSize.height, 0.0);
            resultTransform = CGAffineTransformRotate(translateToCenter,M_PI_2);
            videoComposition.renderSize = CGSizeMake(videoTrack.naturalSize.height,videoTrack.naturalSize.width);
        } else if(degrees == 180){
            CGAffineTransform translateToCenter = CGAffineTransformMakeTranslation(videoTrack.naturalSize.width, videoTrack.naturalSize.height);
            resultTransform = CGAffineTransformRotate(translateToCenter,M_PI);
            videoComposition.renderSize = CGSizeMake(videoTrack.naturalSize.width,videoTrack.naturalSize.height);
        } else if(degrees == 270){
            CGAffineTransform translateToCenter = CGAffineTransformMakeTranslation(0.0, videoTrack.naturalSize.width);
            resultTransform = CGAffineTransformRotate(translateToCenter,M_PI_2*3.0);
            videoComposition.renderSize = CGSizeMake(videoTrack.naturalSize.height,videoTrack.naturalSize.width);
        }
    }
    [roateLayerInstruction setTransform:resultTransform atTime:kCMTimeZero];
    roateInstruction.layerInstructions = @[roateLayerInstruction];
    videoComposition.instructions = @[roateInstruction];
    return videoComposition;
}

/// 获取视频角度
- (int)degressFromVideoFileWithAsset:(AVAsset *)asset {
    int degress = 0;
    NSArray *tracks = [asset tracksWithMediaType:AVMediaTypeVideo];
    if([tracks count] > 0) {
        AVAssetTrack *videoTrack = [tracks objectAtIndex:0];
        CGAffineTransform t = videoTrack.preferredTransform;
        if(t.a == 0 && t.b == 1.0 && t.c == -1.0 && t.d == 0){
            // Portrait
            degress = 90;
        } else if(t.a == 0 && t.b == -1.0 && t.c == 1.0 && t.d == 0){
            // PortraitUpsideDown
            degress = 270;
        } else if(t.a == 1.0 && t.b == 0 && t.c == 0 && t.d == 1.0){
            // LandscapeRight
            degress = 0;
        } else if(t.a == -1.0 && t.b == 0 && t.c == 0 && t.d == -1.0){
            // LandscapeLeft
            degress = 180;
        }
    }
    return degress;
}

- (BOOL)encodeReadySamplesFromOutput:(AVAssetReaderOutput *)output toInput:(AVAssetWriterInput *)input {
    while (input.isReadyForMoreMediaData) {
        CMSampleBufferRef sampleBuffer = [output copyNextSampleBuffer];
        if (sampleBuffer) {
            BOOL handled = NO;
            BOOL error = NO;
            
            if (self.reader.status != AVAssetReaderStatusReading || self.writer.status != AVAssetWriterStatusWriting) {
                handled = YES;
                error = YES;
            }
            
            if (!handled && self.videoOutput == output) {
                // update the video progress
                _lastSamplePresentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
                _lastSamplePresentationTime = CMTimeSubtract(_lastSamplePresentationTime, self.timeRange.start);
                self.progress = _duration == 0 ? 1 : CMTimeGetSeconds(_lastSamplePresentationTime) / _duration;
                if (self.progressHandler) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        self.progressHandler(self.progress);
                    });
                }
            }
            if (!handled && ![input appendSampleBuffer:sampleBuffer]) {
                error = YES;
            }
            CFRelease(sampleBuffer);
            if (error) {
                return NO;
            }
        } else {
            [input markAsFinished];
            return NO;
        }
    }
    
    return YES;
}

- (void)finish
{
    // Synchronized block to ensure we never cancel the writer before calling finishWritingWithCompletionHandler
    if (self.reader.status == AVAssetReaderStatusCancelled || self.writer.status == AVAssetWriterStatusCancelled) {
        return;
    }
    
    if (self.writer.status == AVAssetWriterStatusFailed) {
        [self complete];
    } else if (self.reader.status == AVAssetReaderStatusFailed) {
        [self.writer cancelWriting];
        [self complete];
    } else {
        [self.writer finishWritingWithCompletionHandler:^ {
            [self complete];
        }];
    }
}

- (void)complete
{
    if (self.writer.status == AVAssetWriterStatusFailed || self.writer.status == AVAssetWriterStatusCancelled) {
        [NSFileManager.defaultManager removeItemAtURL:self.outputURL error:nil];
    }
    
    if (self.completionHandler) {
        self.completionHandler();
        self.completionHandler = nil;
    }
}

- (NSError *)error
{
    if (_error) {
        return _error;
    } else {
        return self.writer.error ? : self.reader.error;
    }
}

- (AVAssetExportSessionStatus)status
{
    switch (self.writer.status)
    {
        default:
        case AVAssetWriterStatusUnknown:
            return AVAssetExportSessionStatusUnknown;
        case AVAssetWriterStatusWriting:
            return AVAssetExportSessionStatusExporting;
        case AVAssetWriterStatusFailed:
            return AVAssetExportSessionStatusFailed;
        case AVAssetWriterStatusCompleted:
            return AVAssetExportSessionStatusCompleted;
        case AVAssetWriterStatusCancelled:
            return AVAssetExportSessionStatusCancelled;
    }
}

- (void)cancelExport {
    if (self.inputQueue) {
        dispatch_async(self.inputQueue, ^{
            [self.writer cancelWriting];
            [self.reader cancelReading];
            [self complete];
            [self reset];
        });
    }
}

- (void)reset {
    _error = nil;
    self.progress = 0;
    self.reader = nil;
    self.videoOutput = nil;
    self.trackAudioOutput = nil;
    self.writer = nil;
    self.videoInput = nil;
    self.audioInput = nil;
    self.inputQueue = nil;
    self.completionHandler = nil;
}


@end
