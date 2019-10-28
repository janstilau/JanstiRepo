//
//  YYImage.h
//  YYKit <https://github.com/ibireme/YYKit>
//
//  Created by ibireme on 14/10/20.
//  Copyright (c) 2015 ibireme.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import <UIKit/UIKit.h>

#if __has_include(<YYKit/YYKit.h>)
#import <YYKit/YYAnimatedImageView.h>
#import <YYKit/YYImageCoder.h>
#else
#import "YYAnimatedImageView.h"
#import "YYImageCoder.h"
#endif

NS_ASSUME_NONNULL_BEGIN

/*
 UIImage objects are immutable, so you always create them from existing image data.
 UIImage 是对于 ImageData 的一层包装.
 imageNamed 这个方法, 是为了从 bundle 里面读取数据, 所以, 而 bundle 里面的数据是打包在程序里面的. 所以, 系统认为这是一个常用的数据, 会进行缓存的处理.
 imageWithContentsOfFile 是从文件系统里面读取数据. 这些文件, 可能是从网络下载下来的. 所以不会进行缓存, 每次加载, 都是文件读取
 
 不可变对象, 可以多线程无危险的访问.
 Because image objects are immutable, you cannot change their properties after creation.
 Most image properties are set automatically using metadata in the accompanying image file or image data.
 The immutable nature of image objects also means that they are safe to create and use from any thread.
 
 */
 

/**
 A YYImage object is a high-level way to display animated image data.
 
 @discussion It is a fully compatible `UIImage` subclass. It extends the UIImage
 to support animated WebP, APNG and GIF format image data decoding. It also 
 support NSCoding protocol to archive and unarchive multi-frame image data.
 
 If the image is created from multi-frame image data, and you want to play the 
 animation, try replace UIImageView with `YYAnimatedImageView`.
 
 Sample Code:
 
     // animation@3x.webp
     YYImage *image = [YYImage imageNamed:@"animation.webp"];
     YYAnimatedImageView *imageView = [YYAnimatedImageView alloc] initWithImage:image];
     [view addSubView:imageView];
    
 */
@interface YYImage : UIImage <YYAnimatedImage>

+ (nullable YYImage *)imageNamed:(NSString *)name; // no cache!
+ (nullable YYImage *)imageWithContentsOfFile:(NSString *)path;
+ (nullable YYImage *)imageWithData:(NSData *)data;
+ (nullable YYImage *)imageWithData:(NSData *)data scale:(CGFloat)scale;

/**
 If the image is created from data or file, then the value indicates the data type.
 */
@property (nonatomic, readonly) YYImageType animatedImageType;

/**
 If the image is created from animated image data (multi-frame GIF/APNG/WebP),
 this property stores the original image data.
 */
@property (nullable, nonatomic, readonly) NSData *animatedImageData;

/**
 The total memory usage (in bytes) if all frame images was loaded into memory.
 The value is 0 if the image is not created from a multi-frame image data.
 */
@property (nonatomic, readonly) NSUInteger animatedImageMemorySize;

/**
 Preload all frame image to memory.
 
 @discussion Set this property to `YES` will block the calling thread to decode 
 all animation frame image to memory, set to `NO` will release the preloaded frames.
 If the image is shared by lots of image views (such as emoticon), preload all
 frames will reduce the CPU cost.
 
 See `animatedImageMemorySize` for memory cost.
 */
@property (nonatomic) BOOL preloadAllAnimatedImageFrames;

@end

NS_ASSUME_NONNULL_END
