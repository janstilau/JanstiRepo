#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@protocol SDAVAssetExportSessionDelegate;

@interface SDAVAssetExportSession : NSObject

@property (nonatomic, weak) id<SDAVAssetExportSessionDelegate> delegate;

/**
 * The asset with which the export session was initialized.
 */
@property (nonatomic, strong, readonly) AVAsset *asset;

/**
 * The type of file to be written by the session.
 *
 * The value is a UTI string corresponding to the file type to use when writing the asset.
 * For a list of constants specifying UTIs for standard file types, see `AV Foundation Constants Reference`.
 *
 * You can observe this property using key-value observing.
 */
@property (nonatomic, copy) NSString *outputFileType;

/**
 * The URL of the export session’s output.
 *
 * You can observe this property using key-value observing.
 */
@property (nonatomic, copy) NSURL *outputURL;

/**
 * The settings used for encoding the video track.
 *
 * A value of nil specifies that appended output should not be re-encoded.
 * The dictionary’s keys are from <AVFoundation/AVVideoSettings.h>.
 */
@property (nonatomic, copy) NSDictionary *videoSettings;

/**
 * The settings used for encoding the audio track.
 *
 * A value of nil specifies that appended output should not be re-encoded.
 * The dictionary’s keys are from <CoreVideo/CVPixelBuffer.h>.
 */
@property (nonatomic, copy) NSDictionary *audioSettings;

/**
 * The time range to be exported from the source.
 *
 * The default time range of an export session is `kCMTimeZero` to `kCMTimePositiveInfinity`,
 * meaning that (modulo a possible limit on file length) the full duration of the asset will be exported.
 *
 * You can observe this property using key-value observing.
 *
 */
@property (nonatomic, assign) CMTimeRange timeRange;

/**
 * Indicates whether the movie should be optimized for network use.
 *
 * You can observe this property using key-value observing.
 *
 * When the value of this property is YES, the writer writes the output file in such a way that playback can start after only a small amount of the file is downloaded.
 *
 */
@property (nonatomic, assign) BOOL shouldOptimizeForNetworkUse;

/**
 * The metadata to be written to the output file by the export session.
 */
@property (nonatomic, copy) NSArray *metadata;

/**
 * Describes the error that occurred if the export status is `AVAssetExportSessionStatusFailed`
 * or `AVAssetExportSessionStatusCancelled`.
 *
 * If there is no error to report, the value of this property is nil.
 */
@property (nonatomic, strong, readonly) NSError *error;

/**
 * The progress of the export on a scale from 0 to 1.
 *
 *
 * A value of 0 means the export has not yet begun, 1 means the export is complete.
 *
 * Unlike Apple provided `AVAssetExportSession`, this property can be observed using key-value observing.
 */
@property (nonatomic, assign, readonly) float progress;

/**
 * The status of the export session.
 *
 * For possible values, see “AVAssetExportSessionStatus.”
 *
 * You can observe this property using key-value observing. (TODO)
 */
@property (nonatomic, assign, readonly) AVAssetExportSessionStatus status;

@property (nonatomic, strong) void (^progressHandler)(float progress);

+ (id)exportSessionWithAsset:(AVAsset *)asset;
- (id)initWithAsset:(AVAsset *)asset;
- (void)exportAsynchronouslyWithCompletionHandler:(void (^)(void))handler;
- (void)cancelExport;

@end

