#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface PBJVisionUtilities : NSObject

// devices and connections

+ (AVCaptureDevice *)primaryVideoDeviceForPosition:(AVCaptureDevicePosition)position;
+ (AVCaptureDevice *)videoDevice;
+ (AVCaptureDevice *)audioDevice;
+ (AVCaptureConnection *)connectionWithMediaType:(NSString *)mediaType fromConnections:(NSArray *)connections;

// sample buffers

+ (CMSampleBufferRef)createOffsetSampleBufferWithSampleBuffer:(CMSampleBufferRef)sampleBuffer withTimeOffset:(CMTime)timeOffset;

+ (UIImage *)uiimageFromJPEGData:(NSData *)jpegData;

// orientation

+ (UIImageOrientation)uiimageOrientationFromExifOrientation:(NSInteger)exifOrientation;
+ (CGFloat)angleOffsetFromPortraitOrientationToOrientation:(AVCaptureVideoOrientation)orientation;

// storage

+ (uint64_t)availableStorageSpaceInBytes;

@end

@interface NSString (PBJExtras)

+ (NSString *)PBJformattedTimestampStringFromDate:(NSDate *)date;

@end
