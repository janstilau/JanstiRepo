//
//  PBJVisionUtilities.h
//  PBJVision
//
//  Created by Patrick Piemonte on 5/20/13.
//  Copyright (c) 2013-present, Patrick Piemonte, http://patrickpiemonte.com
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of
//  this software and associated documentation files (the "Software"), to deal in
//  the Software without restriction, including without limitation the rights to
//  use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
//  the Software, and to permit persons to whom the Software is furnished to do so,
//  subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
//  FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
//  COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
//  IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

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
