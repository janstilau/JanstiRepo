#import "PBJMediaWriter.h"
#import "PBJVisionUtilities.h"
#import "PBJVision.h"

#import <UIKit/UIDevice.h>
#import <MobileCoreServices/UTCoreTypes.h>

#define LOG_WRITER 0
#if !defined(NDEBUG) && LOG_WRITER
#   define DLog(fmt, ...) NSLog((@"writer: " fmt), ##__VA_ARGS__);
#else
#   define DLog(...)
#endif

@interface PBJMediaWriter ()
{
    // AVAssetWriter 是真正的输出类.
    /*
     asset读取器和写入器类不用于实时处理。实际上，asset读取器甚至不能用于从HTTP实时流等实时源读取。
     但是，如果你正在使用具有实时数据源的asset写入器（例如AVCaptureOutput对象），请将asset写入器输入的expectsMediaDataInRealTime属性设置为YES。
     对于非实时数据源，将此属性设置为YES将导致文件无法正确交错。

     AVAssetWriter类将来自多个源的媒体数据写入指定文件格式的单个文件。
     由于asset写入器可以从多个源写入媒体数据，因此必须为要写入输出文件的每个单独的轨道创建AVAssetWriterInput对象
     每个AVAssetWriterInput对象都希望以CMSampleBufferRef对象的形式接收数据
     */
    AVAssetWriter *_assetWriter;
    AVAssetWriterInput *_assetWriterAudioInput;
    AVAssetWriterInput *_assetWriterVideoInput;

    NSURL *_outputURL;

    CMTime _audioTimestamp;
    CMTime _videoTimestamp;
}

@end

@implementation PBJMediaWriter

@synthesize delegate = _delegate;
@synthesize outputURL = _outputURL;
@synthesize audioTimestamp = _audioTimestamp;
@synthesize videoTimestamp = _videoTimestamp;

#pragma mark - getters/setters

// 如果, 没有权限, 或者 Audio 没有初始化.
- (BOOL)isAudioReady
{
    AVAuthorizationStatus audioAuthorizationStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];

    BOOL isAudioNotAuthorized = (audioAuthorizationStatus == AVAuthorizationStatusNotDetermined || audioAuthorizationStatus == AVAuthorizationStatusDenied);
    BOOL isAudioSetup = (_assetWriterAudioInput != nil) || isAudioNotAuthorized;

    return isAudioSetup;
}

- (BOOL)isVideoReady
{
    AVAuthorizationStatus videoAuthorizationStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];

    BOOL isVideoNotAuthorized = (videoAuthorizationStatus == AVAuthorizationStatusNotDetermined || videoAuthorizationStatus == AVAuthorizationStatusDenied);
    BOOL isVideoSetup = (_assetWriterVideoInput != nil) || isVideoNotAuthorized;

    return isVideoSetup;
}

- (NSError *)error
{
    return _assetWriter.error;
}

#pragma mark - init

- (id)initWithOutputURL:(NSURL *)outputURL
{
    self = [super init];
    if (self) {
        NSError *error = nil;
        _assetWriter = [AVAssetWriter assetWriterWithURL:outputURL fileType:(NSString *)kUTTypeMPEG4 error:&error];
        if (error) {
            DLog(@"error setting up the asset writer (%@)", error);
            _assetWriter = nil;
            return nil;
        }

        _outputURL = outputURL;

        _assetWriter.shouldOptimizeForNetworkUse = YES;
        _assetWriter.metadata = [self _metadataArray]; // 关于视频的元信息的组装. 这里, iOS 是专门用了一个叫做AVMutableMetadataItem的类进行的表示.

        _audioTimestamp = kCMTimeInvalid;
        _videoTimestamp = kCMTimeInvalid;

        // ensure authorization is permitted, if not already prompted
        // it's possible to capture video without audio or audio without video
        if ([[AVCaptureDevice class] respondsToSelector:@selector(authorizationStatusForMediaType:)]) {
            AVAuthorizationStatus audioAuthorizationStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
            if (audioAuthorizationStatus == AVAuthorizationStatusNotDetermined ||
                audioAuthorizationStatus == AVAuthorizationStatusDenied) {
                if (audioAuthorizationStatus == AVAuthorizationStatusDenied &&
                    [_delegate respondsToSelector:@selector(mediaWriterDidObserveAudioAuthorizationStatusDenied:)]) {
                    [_delegate mediaWriterDidObserveAudioAuthorizationStatusDenied:self];
                }
            }
            AVAuthorizationStatus videoAuthorizationStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
            if (videoAuthorizationStatus == AVAuthorizationStatusNotDetermined || videoAuthorizationStatus == AVAuthorizationStatusDenied) {
                if (videoAuthorizationStatus == AVAuthorizationStatusDenied && [_delegate respondsToSelector:@selector(mediaWriterDidObserveVideoAuthorizationStatusDenied:)]) {
                    [_delegate mediaWriterDidObserveVideoAuthorizationStatusDenied:self];
                }
            }

        }
        DLog(@"prepared to write to (%@)", outputURL);
    }
    return self;
}

#pragma mark - private

- (NSArray *)_metadataArray
{
    UIDevice *currentDevice = [UIDevice currentDevice];

    // device model
    AVMutableMetadataItem *modelItem = [[AVMutableMetadataItem alloc] init];
    [modelItem setKeySpace:AVMetadataKeySpaceCommon];
    [modelItem setKey:AVMetadataCommonKeyModel];
    [modelItem setValue:[currentDevice localizedModel]];

    // software
    AVMutableMetadataItem *softwareItem = [[AVMutableMetadataItem alloc] init];
    [softwareItem setKeySpace:AVMetadataKeySpaceCommon];
    [softwareItem setKey:AVMetadataCommonKeySoftware];
    [softwareItem setValue:@"PBJVision"];

    // creation date
    AVMutableMetadataItem *creationDateItem = [[AVMutableMetadataItem alloc] init];
    [creationDateItem setKeySpace:AVMetadataKeySpaceCommon];
    [creationDateItem setKey:AVMetadataCommonKeyCreationDate];
    [creationDateItem setValue:[NSString PBJformattedTimestampStringFromDate:[NSDate date]]];

    return @[modelItem, softwareItem, creationDateItem];
}

#pragma mark - setup

// 音频的配置, 专门的一个函数.
// 其实, 这个函数最大的作用, 是为 Write 添加一个 Input
- (BOOL)setupAudioWithSettings:(NSDictionary *)audioSettings
{
    // 如果还没有初始化 AudioInput
    if (!_assetWriterAudioInput && [_assetWriter canApplyOutputSettings:audioSettings forMediaType:AVMediaTypeAudio]) {

        _assetWriterAudioInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:audioSettings];
        _assetWriterAudioInput.expectsMediaDataInRealTime = YES;

        if (_assetWriterAudioInput && [_assetWriter canAddInput:_assetWriterAudioInput]) {
            [_assetWriter addInput:_assetWriterAudioInput];

            DLog(@"setup audio input with settings sampleRate (%f) channels (%lu) bitRate (%ld)",
                [[audioSettings objectForKey:AVSampleRateKey] floatValue],
                (unsigned long)[[audioSettings objectForKey:AVNumberOfChannelsKey] unsignedIntegerValue],
                (long)[[audioSettings objectForKey:AVEncoderBitRateKey] integerValue]);

        } else {
            DLog(@"couldn't add asset writer audio input");
        }
    } else {
        _assetWriterAudioInput = nil;
        DLog(@"couldn't apply audio output settings");

    }
    return self.isAudioReady;
}

- (BOOL)setupVideoWithSettings:(NSDictionary *)videoSettings withAdditional:(NSDictionary *)additional {
    if (!_assetWriterVideoInput && [_assetWriter canApplyOutputSettings:videoSettings forMediaType:AVMediaTypeVideo]) {
        _assetWriterVideoInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
        _assetWriterVideoInput.expectsMediaDataInRealTime = YES;
        _assetWriterVideoInput.transform = CGAffineTransformIdentity;
        if (additional != nil) {
            NSNumber *angle = additional[PBJVisionVideoRotation];
            if (angle) {
                _assetWriterVideoInput.transform = CGAffineTransformMakeRotation([angle floatValue]);
            }
        }
        if (_assetWriterVideoInput && [_assetWriter canAddInput:_assetWriterVideoInput]) {
            [_assetWriter addInput:_assetWriterVideoInput];
#if !defined(NDEBUG) && LOG_WRITER
            NSDictionary *videoCompressionProperties = videoSettings[AVVideoCompressionPropertiesKey];
            if (videoCompressionProperties) {
                DLog(@"setup video with compression settings bps (%f) frameInterval (%ld)",
                        [videoCompressionProperties[AVVideoAverageBitRateKey] floatValue],
                        (long)[videoCompressionProperties[AVVideoMaxKeyFrameIntervalKey] integerValue]);
            } else {
                DLog(@"setup video");
            }
#endif
        } else {
            DLog(@"couldn't add asset writer video input");
        }
    } else {
        _assetWriterVideoInput = nil;
        DLog(@"couldn't apply video output settings");
    }
    return self.isVideoReady;
}

#pragma mark - sample buffer writing

//CMSampleBufferRef CMSampleBuffer 的数据结构没有公开出来.
- (void)writeSampleBuffer:(CMSampleBufferRef)sampleBuffer withMediaTypeVideo:(BOOL)video
{
    if (!CMSampleBufferDataIsReady(sampleBuffer)) {
        return;
    }

    // setup the writer
    // 如果没有开始写入, 主动调用写入函数.
    if ( _assetWriter.status == AVAssetWriterStatusUnknown ) {
        if ([_assetWriter startWriting]) {
            CMTime timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
            /*
             配置asset写入器所需的所有输入后，即可开始写入媒体数据。正如您对asset读取器所做的那样，通过调用startWriting方法启动写入过程。
             然后，你需要通过调用startSessionAtSourceTime:方法来启动sample-writing会话。
             asset写入器完成的所有写入都必须在其中一个会话中进行，每个会话的时间范围定义了源中包含的媒体数据的时间范围。
             例如，如果你的源是提供从AVAsset对象读取的媒体数据的asset读取器，并且你不希望包含来自asset的前半部分的媒体数据，那么你将执行以下操作：
             
             Sequences of sample data appended to the asset writer inputs are considered to fall within “sample-writing sessions.” You must call this method to begin one of these sessions.
             Each writing session has a start time which, where allowed by the file format being written, defines the mapping from the timeline of source samples onto the file's timeline.
             In the case of the QuickTime movie file format, the first session begins at movie time 0, so a sample appended with timestamp T will be played at movie time (T-startTime). Samples with timestamps before startTime will still be added to the output media but will be edited out of the movie.
             If the earliest buffer for an input is later than startTime, an empty edit will be inserted to preserve synchronization between tracks of the output asset.
             
             sampleBuffer 中, 会带有时间信息, startSessionAtSourceTime 会协调每个 Buffer 的状态, 根据这些时间信息, 把 Buffer 按序组合成为最后的文件.
             */
            [_assetWriter startSessionAtSourceTime:timestamp];
            DLog(@"started writing with status (%ld)", (long)_assetWriter.status);
        } else {
            DLog(@"error when starting to write (%@)", [_assetWriter error]);
            return;
        }
    }

    // check for completion state
    if ( _assetWriter.status == AVAssetWriterStatusFailed ) {
        DLog(@"writer failure, (%@)", _assetWriter.error.localizedDescription);
        return;
    }

    if (_assetWriter.status == AVAssetWriterStatusCancelled) {
        DLog(@"writer cancelled");
        return;
    }

    if ( _assetWriter.status == AVAssetWriterStatusCompleted) {
        DLog(@"writer finished and completed");
        return;
    }

    // 如果, 现在正在写入,
    if ( _assetWriter.status == AVAssetWriterStatusWriting ) {
        CMTime timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        CMTime duration = CMSampleBufferGetDuration(sampleBuffer);
        if (duration.value > 0) {
            timestamp = CMTimeAdd(timestamp, duration);
        }
        // 就把 sampleBuffer 的信息, 填充到 Input 中去.
        if (video) {
            if (_assetWriterVideoInput.readyForMoreMediaData) {
                if ([_assetWriterVideoInput appendSampleBuffer:sampleBuffer]) {
                    _videoTimestamp = timestamp;
                } else {
                    DLog(@"writer error appending video (%@)", _assetWriter.error);
                }
            }
        } else {
            if (_assetWriterAudioInput.readyForMoreMediaData) {
                if ([_assetWriterAudioInput appendSampleBuffer:sampleBuffer]) {
                    _audioTimestamp = timestamp;
                } else {
                    DLog(@"writer error appending audio (%@)", _assetWriter.error);
                }
            }
        }

    }
}

- (void)finishWritingWithCompletionHandler:(void (^)(void))handler
{
    if (_assetWriter.status == AVAssetWriterStatusUnknown ||
        _assetWriter.status == AVAssetWriterStatusCompleted) {
        DLog(@"asset writer was in an unexpected state (%@)", @(_assetWriter.status));
        return;
    }
    // markAsFinished : Tells the writer it can't append more buffers to this input.
    // 并不会立马停止 _assetWriter 的输出, 只是告诉 Input 不要添加新的 Sample 到 Buffer 里面了
    [_assetWriterVideoInput markAsFinished];
    [_assetWriterAudioInput markAsFinished];
    // Marks all unfinished inputs as finished and completes the writing of the output file.
    // This method returns immediately and causes its work to be performed asynchronously. To determine whether the operation succeeded, you can check the value of the status property within the handler parameter.
    [_assetWriter finishWritingWithCompletionHandler:handler];
}


@end
