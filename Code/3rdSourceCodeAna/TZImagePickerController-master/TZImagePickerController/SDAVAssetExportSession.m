#import "SDAVAssetExportSession.h"

@interface SDAVAssetExportSession ()

@property (nonatomic, assign, readwrite) float progress;

@property (nonatomic, strong) AVAssetReader *reader;
@property (nonatomic, strong) AVAssetReaderVideoCompositionOutput *videoOutput;
@property (nonatomic, strong) AVAssetReaderAudioMixOutput *audioOutput;
@property (nonatomic, strong) AVAssetWriter *writer;
@property (nonatomic, strong) AVAssetWriterInput *videoInput;
@property (nonatomic, strong) AVAssetWriterInputPixelBufferAdaptor *videoPixelBufferAdaptor;
@property (nonatomic, strong) AVAssetWriterInput *audioInput;
@property (nonatomic, strong) dispatch_queue_t inputQueue;
@property (nonatomic, strong) void (^completionHandler)(void);

@end

@implementation SDAVAssetExportSession
{
    NSError *_error;
    NSTimeInterval duration;
    CMTime lastSamplePresentationTime;
}

+ (id)exportSessionWithAsset:(AVAsset *)asset
{
    return [SDAVAssetExportSession.alloc initWithAsset:asset];
}

- (id)initWithAsset:(AVAsset *)asset
{
    if ((self = [super init]))
    {
        _asset = asset;
        _timeRange = CMTimeRangeMake(kCMTimeZero, kCMTimePositiveInfinity);
    }
    
    return self;
}

- (NSError *)isPrepareSuccess {
    if (!self.outputURL){
        return
        [NSError errorWithDomain:AVFoundationErrorDomain code:AVErrorExportFailed userInfo:@{
            NSLocalizedDescriptionKey: @"Output URL not set"
        }];
    }
    
    NSError *readerError;
    self.reader = [AVAssetReader.alloc initWithAsset:self.asset error:&readerError];
    if (readerError) { return readerError; }
    
    NSError *writerError;
    self.writer = [AVAssetWriter assetWriterWithURL:self.outputURL fileType:self.outputFileType error:&writerError];
    if (writerError) { return writerError; }
    
    return nil;
}

- (void)exportAsynchronouslyWithCompletionHandler:(void (^)(void))handler
{
    NSParameterAssert(handler != nil);
    [self cancelExport];
    // 如果, 没有输出路径, 直接报错.
    NSError *error = [self isPrepareSuccess];
    if (error) {
        _error = error;
        handler();
        return;
    }
    
    self.completionHandler = handler;
    self.reader.timeRange = self.timeRange;
    self.writer.shouldOptimizeForNetworkUse = self.shouldOptimizeForNetworkUse;
    self.writer.metadata = self.metadata; // 一般是默认值.
    
    NSArray *videoTracks = [self.asset tracksWithMediaType:AVMediaTypeVideo];
    
    if (CMTIME_IS_VALID(self.timeRange.duration) && !CMTIME_IS_POSITIVE_INFINITY(self.timeRange.duration)){
        duration = CMTimeGetSeconds(self.timeRange.duration);
    } else {
        duration = CMTimeGetSeconds(self.asset.duration);
    }
    //
    // Video output
    //
    // AVAssetReaderTrackOutput  是读取一个 track 的数据
    // AVAssetReaderVideoCompositionOutput 是读取多个 tracks 的数据.
    // 创建Asset读取器后，设置至少一个输出以接收正在读取的媒体数据
    if (videoTracks.count > 0) {
        self.videoOutput = [AVAssetReaderVideoCompositionOutput assetReaderVideoCompositionOutputWithVideoTracks:videoTracks videoSettings:self.videoInputSettings];
        // 这个控制, 是不是获取的数据会被 copy 一次, 为了性能, 这里设置为 NO.
        self.videoOutput.alwaysCopiesSampleData = NO;
        if (self.videoComposition) {
            self.videoOutput.videoComposition = self.videoComposition;
        } else {
            self.videoOutput.videoComposition = [self buildDefaultVideoComposition];
        }
        if ([self.reader canAddOutput:self.videoOutput]) {
            [self.reader addOutput:self.videoOutput];
        }
        
        //
        // Video input
        //
        self.videoInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:self.videoSettings];
        self.videoInput.expectsMediaDataInRealTime = NO;
        if ([self.writer canAddInput:self.videoInput])
        {
            [self.writer addInput:self.videoInput];
        }
        NSDictionary *pixelBufferAttributes = @
        {
            (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA),
            (id)kCVPixelBufferWidthKey: @(self.videoOutput.videoComposition.renderSize.width),
            (id)kCVPixelBufferHeightKey: @(self.videoOutput.videoComposition.renderSize.height),
            @"IOSurfaceOpenGLESTextureCompatibility": @YES,
            @"IOSurfaceOpenGLESFBOCompatibility": @YES,
        };
        self.videoPixelBufferAdaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:self.videoInput sourcePixelBufferAttributes:pixelBufferAttributes];
    }
    
    //
    //Audio output
    //
    NSArray *audioTracks = [self.asset tracksWithMediaType:AVMediaTypeAudio];
    if (audioTracks.count > 0) {
        self.audioOutput = [AVAssetReaderAudioMixOutput assetReaderAudioMixOutputWithAudioTracks:audioTracks audioSettings:nil];
        self.audioOutput.alwaysCopiesSampleData = NO;
        self.audioOutput.audioMix = self.audioMix;
        if ([self.reader canAddOutput:self.audioOutput])
        {
            [self.reader addOutput:self.audioOutput];
        }
    } else {
        // Just in case this gets reused
        self.audioOutput = nil;
    }
    
    //
    // Audio input
    //
    if (self.audioOutput) {
        self.audioInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:self.audioSettings];
        self.audioInput.expectsMediaDataInRealTime = NO;
        if ([self.writer canAddInput:self.audioInput])
        {
            [self.writer addInput:self.audioInput];
        }
    }
    
    [self.writer startWriting];
    [self.reader startReading];
    [self.writer startSessionAtSourceTime:self.timeRange.start];
    
    __block BOOL videoCompleted = NO;
    __block BOOL audioCompleted = NO;
    __weak typeof(self) wself = self;
    self.inputQueue = dispatch_queue_create("VideoEncoderInputQueue", DISPATCH_QUEUE_SERIAL);
    if (videoTracks.count > 0) {
        // Instructs the receiver to invoke a block repeatedly, at its convenience, to gather media data for writing to the output. 也就是, 里面的 block 会一直调用.
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
    
    if (!self.audioOutput) {
        audioCompleted = YES;
    } else {
        [self.audioInput requestMediaDataWhenReadyOnQueue:self.inputQueue usingBlock:^ {
            if (![wself encodeReadySamplesFromOutput:wself.audioOutput toInput:wself.audioInput]) {
                @synchronized(wself) {
                    audioCompleted = YES;
                    if (videoCompleted) {
                        [wself finish];
                    }
                }
            }
        }];
    }
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
                lastSamplePresentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
                lastSamplePresentationTime = CMTimeSubtract(lastSamplePresentationTime, self.timeRange.start);
                self.progress = duration == 0 ? 1 : CMTimeGetSeconds(lastSamplePresentationTime) / duration;
                
                if ([self.delegate respondsToSelector:@selector(exportSession:renderFrame:withPresentationTime:toBuffer:)]) {
                    CVPixelBufferRef pixelBuffer = (CVPixelBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
                    CVPixelBufferRef renderBuffer = NULL;
                    CVPixelBufferPoolCreatePixelBuffer(NULL, self.videoPixelBufferAdaptor.pixelBufferPool, &renderBuffer);
                    [self.delegate exportSession:self renderFrame:pixelBuffer withPresentationTime:lastSamplePresentationTime toBuffer:renderBuffer];
                    if (![self.videoPixelBufferAdaptor appendPixelBuffer:renderBuffer withPresentationTime:lastSamplePresentationTime]) {
                        error = YES;
                    }
                    CVPixelBufferRelease(renderBuffer);
                    handled = YES;
                }
            }
            if (!handled && ![input appendSampleBuffer:sampleBuffer]) {
                error = YES;
            }
            CFRelease(sampleBuffer);
            
            if (error) {
                return NO;
            }
        }
        else {
            [input markAsFinished];
            return NO;
        }
    }
    
    return YES;
}

- (AVMutableVideoComposition *)buildDefaultVideoComposition
{
    AVMutableVideoComposition *videoComposition = [AVMutableVideoComposition videoComposition];
    AVAssetTrack *videoTrack = [[self.asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
    
    float trackFrameRate = 0;
    if (self.videoSettings) {
        NSDictionary *videoCompressionProperties = [self.videoSettings objectForKey:AVVideoCompressionPropertiesKey];
        if (videoCompressionProperties) {
            NSNumber *frameRate = [videoCompressionProperties objectForKey:AVVideoAverageNonDroppableFrameRateKey];
            if (frameRate) {
                trackFrameRate = frameRate.floatValue;
            }
        }
    } else {
        trackFrameRate = [videoTrack nominalFrameRate];
    }
    
    if (trackFrameRate == 0) {
        trackFrameRate = 30;
    }
    
    videoComposition.frameDuration = CMTimeMake(1, trackFrameRate);
    CGSize targetSize = CGSizeMake([self.videoSettings[AVVideoWidthKey] floatValue], [self.videoSettings[AVVideoHeightKey] floatValue]);
    CGSize naturalSize = [videoTrack naturalSize];
    CGAffineTransform transform = videoTrack.preferredTransform;
    // Workaround radar 31928389, see https://github.com/rs/SDAVAssetExportSession/pull/70 for more info
    if (transform.ty == -560) {
        transform.ty = 0;
    }
    
    if (transform.tx == -560) {
        transform.tx = 0;
    }
    
    CGFloat videoAngleInDegree  = atan2(transform.b, transform.a) * 180 / M_PI;
    if (videoAngleInDegree == 90 || videoAngleInDegree == -90) {
        CGFloat width = naturalSize.width;
        naturalSize.width = naturalSize.height;
        naturalSize.height = width;
    }
    videoComposition.renderSize = naturalSize;
    // center inside
    {
        float ratio;
        float xratio = targetSize.width / naturalSize.width;
        float yratio = targetSize.height / naturalSize.height;
        ratio = MIN(xratio, yratio);
        
        float postWidth = naturalSize.width * ratio;
        float postHeight = naturalSize.height * ratio;
        float transx = (targetSize.width - postWidth) / 2;
        float transy = (targetSize.height - postHeight) / 2;
        
        CGAffineTransform matrix = CGAffineTransformMakeTranslation(transx / xratio, transy / yratio);
        matrix = CGAffineTransformScale(matrix, ratio / xratio, ratio / yratio);
        transform = CGAffineTransformConcat(transform, matrix);
    }
    
    // Make a "pass through video track" video composition.
    AVMutableVideoCompositionInstruction *passThroughInstruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    passThroughInstruction.timeRange = CMTimeRangeMake(kCMTimeZero, self.asset.duration);
    
    AVMutableVideoCompositionLayerInstruction *passThroughLayer = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:videoTrack];
    
    [passThroughLayer setTransform:transform atTime:kCMTimeZero];
    
    passThroughInstruction.layerInstructions = @[passThroughLayer];
    videoComposition.instructions = @[passThroughInstruction];
    
    return videoComposition;
}

- (void)finish
{
    // Synchronized block to ensure we never cancel the writer before calling finishWritingWithCompletionHandler
    if (self.reader.status == AVAssetReaderStatusCancelled || self.writer.status == AVAssetWriterStatusCancelled)
    {
        return;
    }
    
    if (self.writer.status == AVAssetWriterStatusFailed)
    {
        [self complete];
    }
    else if (self.reader.status == AVAssetReaderStatusFailed) {
        [self.writer cancelWriting];
        [self complete];
    }
    else
    {
        [self.writer finishWritingWithCompletionHandler:^
         {
            [self complete];
        }];
    }
}

- (void)complete
{
    if (self.writer.status == AVAssetWriterStatusFailed || self.writer.status == AVAssetWriterStatusCancelled)
    {
        [NSFileManager.defaultManager removeItemAtURL:self.outputURL error:nil];
    }
    
    if (self.completionHandler)
    {
        self.completionHandler();
        // 这里必须显示的进行, 不然会有内存泄露的.
        self.completionHandler = nil;
    }
}

- (NSError *)error
{
    if (_error)
    {
        return _error;
    }
    else
    {
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

- (void)cancelExport
{
    if (self.inputQueue)
    {
        dispatch_async(self.inputQueue, ^{
            [self.writer cancelWriting];
            [self.reader cancelReading];
            [self complete];
            [self reset];
        });
    }
}

- (void)reset
{
    _error = nil;
    self.progress = 0;
    self.reader = nil;
    self.videoOutput = nil;
    self.audioOutput = nil;
    self.writer = nil;
    self.videoInput = nil;
    self.videoPixelBufferAdaptor = nil;
    self.audioInput = nil;
    self.inputQueue = nil;
    self.completionHandler = nil;
}

@end