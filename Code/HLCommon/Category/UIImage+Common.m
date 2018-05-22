//
//  UIImage+Common.m
//  HLMagic
//
//  Created by marujun on 13-12-8.
//  Copyright (c) 2013年 chen ying. All rights reserved.
//

#import "UIImage+Common.h"
#import <Accelerate/Accelerate.h>

#if __has_include("YYKitMacro.h")
#elif __has_include(<YYKit/YYKitMacro.h>)
#else
CGFloat DegreesToRadians(CGFloat degrees) {return degrees * M_PI / 180;};
CGFloat RadiansToDegrees(CGFloat radians) {return radians * 180/M_PI;};
#endif

const UICornerInset UICornerInsetZero = {0.0f, 0.0f, 0.0f, 0.0f};

@implementation UIImage (Common)

+ (UIImage *)defaultImage
{
    static UIImage *defaultLoadingImage;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        defaultLoadingImage = [UIImage imageWithColor:HexColor(0xf9f9f9)];
    });
    return defaultLoadingImage;
}

+ (UIImage *)defaultAvatar
{
    static UIImage *defaultAvatarImage;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        defaultAvatarImage = [UIImage imageNamed:@"pub_default_avatar.png"];
    });
    return defaultAvatarImage;
}

+ (UIImage *)screenshot
{
    CGSize imageSize = [[UIScreen mainScreen] bounds].size;
    
    UIGraphicsBeginImageContextWithOptions(imageSize, NO, [UIScreen mainScreen].scale);
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    for (UIWindow *window in [[UIApplication sharedApplication] windows]) {
        if (![window respondsToSelector:@selector(screen)] || [window screen] == [UIScreen mainScreen]) {
            CGContextSaveGState(context);
            
            CGContextTranslateCTM(context, [window center].x, [window center].y);
            
            CGContextConcatCTM(context, [window transform]);
            
            CGContextTranslateCTM(context,
                                  -[window bounds].size.width * [[window layer] anchorPoint].x,
                                  -[window bounds].size.height * [[window layer] anchorPoint].y);
            
            [[window layer] renderInContext:context];
            
            CGContextRestoreGState(context);
        }
    }
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    return image;
}

+ (UIImage *)imageWithColor:(UIColor *)color
{
    return [self imageWithColor:color size:CGSizeMake(4, 4)];
}

+ (UIImage *)imageWithColor:(UIColor *)color size:(CGSize)size
{
    return [self imageWithColor:color size:size cornerInset:UICornerInsetZero];
}

+ (UIImage *)imageWithColor:(UIColor *)color cornerRadius:(CGFloat)cornerRadius
{
    CGFloat minEdgeSize = cornerRadius * 2 + 1;
    
    return [self imageWithColor:color size:CGSizeMake(minEdgeSize, minEdgeSize) cornerInset:UICornerInsetMakeWithRadius(cornerRadius)];
}

+ (UIImage *)imageWithColor:(UIColor*)color size:(CGSize)size cornerInset:(UICornerInset)cornerInset
{
    if (!color)
        return nil;
    
    CGFloat scale = [[UIScreen mainScreen] scale];
    CGRect rect = CGRectMake(0.0f, 0.0f, scale*size.width, scale*size.height);
    
    cornerInset.topRight *= scale;
    cornerInset.topLeft *= scale;
    cornerInset.bottomLeft *= scale;
    cornerInset.bottomRight *= scale;
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, rect.size.width, rect.size.height, 8, 0, colorSpace, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    
    CGColorSpaceRelease(colorSpace);
    
    if (context == NULL)
        return nil;
    
    CGFloat minx = CGRectGetMinX(rect), midx = CGRectGetMidX(rect), maxx = CGRectGetMaxX(rect);
    CGFloat miny = CGRectGetMinY(rect), midy = CGRectGetMidY(rect), maxy = CGRectGetMaxY(rect);
    
    CGContextBeginPath(context);
    CGContextSetGrayFillColor(context, 1.0, 0.0); // <-- Alpha color in background
    CGContextAddRect(context, rect);
    CGContextClosePath(context);
    CGContextDrawPath(context, kCGPathFill);
    
    CGContextSetFillColorWithColor(context, [color CGColor]); // <-- Color to fill
    CGContextBeginPath(context);
    CGContextMoveToPoint(context, minx, midy);
    CGContextAddArcToPoint(context, minx, miny, midx, miny, cornerInset.bottomLeft);
    CGContextAddArcToPoint(context, maxx, miny, maxx, midy, cornerInset.bottomRight);
    CGContextAddArcToPoint(context, maxx, maxy, midx, maxy, cornerInset.topRight);
    CGContextAddArcToPoint(context, minx, maxy, minx, midy, cornerInset.topLeft);
    CGContextClosePath(context);
    CGContextDrawPath(context, kCGPathFill);
    
    CGImageRef bitmapContext = CGBitmapContextCreateImage(context);
    
    CGContextRelease(context);
    
    UIImage *theImage = [UIImage imageWithCGImage:bitmapContext scale:scale orientation:UIImageOrientationUp];
    
    CGImageRelease(bitmapContext);
    
    UIEdgeInsets capInsets = UIEdgeInsetsMake(MAX(cornerInset.topLeft/scale, cornerInset.topRight/scale),
                                              MAX(cornerInset.topLeft/scale, cornerInset.bottomLeft/scale),
                                              MAX(cornerInset.bottomLeft/scale, cornerInset.bottomRight/scale),
                                              MAX(cornerInset.topRight/scale, cornerInset.bottomRight/scale));
    if (UIEdgeInsetsEqualToEdgeInsets(capInsets, UIEdgeInsetsZero)) {
        return theImage;
    }
    
    return [theImage resizableImageWithCapInsets:capInsets];
}

- (UIImage *)imageWithSize:(CGSize)newSize
{
    return [self imageWithSize:newSize interpolationQuality:kCGInterpolationDefault];
}

- (UIImage *)imageWithSize:(CGSize)newSize interpolationQuality:(CGInterpolationQuality)quality
{
    BOOL drawTransposed;
    
    switch (self.imageOrientation)
    {
        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            drawTransposed = YES;
            break;
            
        default:
            drawTransposed = NO;
    }
    
    return [self resizedImage:newSize
                    transform:[self transformForOrientation:newSize]
               drawTransposed:drawTransposed
         interpolationQuality:quality];
}

- (UIImage *)resizedImage:(CGSize)newSize
                transform:(CGAffineTransform)transform
           drawTransposed:(BOOL)transpose
     interpolationQuality:(CGInterpolationQuality)quality
{
    CGRect newRect = CGRectIntegral(CGRectMake(0, 0, newSize.width, newSize.height));
    CGRect transposedRect = CGRectMake(0, 0, newRect.size.height, newRect.size.width);
    CGImageRef imageRef = self.CGImage;
    
    // Build a context that's the same dimensions as the new size
    CGContextRef bitmap = CGBitmapContextCreate(NULL,
                                                newRect.size.width,
                                                newRect.size.height,
                                                CGImageGetBitsPerComponent(imageRef),
                                                0,
                                                CGImageGetColorSpace(imageRef),
                                                CGImageGetBitmapInfo(imageRef));
    
    // Rotate and/or flip the image if required by its orientation
    CGContextConcatCTM(bitmap, transform);
    
    // Set the quality level to use when rescaling
    CGContextSetInterpolationQuality(bitmap, quality);
    
    // Draw into the context; this scales the image
    CGContextDrawImage(bitmap, transpose ? transposedRect : newRect, imageRef);
    
    // Get the resized image from the context and a UIImage
    CGImageRef newImageRef = CGBitmapContextCreateImage(bitmap);
    UIImage *newImage = [UIImage imageWithCGImage:newImageRef];
    
    // Clean up
    CGContextRelease(bitmap);
    CGImageRelease(newImageRef);
    
    return newImage;
}

// Returns an affine transform that takes into account the image orientation when drawing a scaled image
- (CGAffineTransform)transformForOrientation:(CGSize)newSize
{
    CGAffineTransform transform = CGAffineTransformIdentity;
    
    switch (self.imageOrientation)
    {
        case UIImageOrientationDown:           // EXIF = 3
        case UIImageOrientationDownMirrored:   // EXIF = 4
            transform = CGAffineTransformTranslate(transform, newSize.width, newSize.height);
            transform = CGAffineTransformRotate(transform, M_PI);
            break;
            
        case UIImageOrientationLeft:           // EXIF = 6
        case UIImageOrientationLeftMirrored:   // EXIF = 5
            transform = CGAffineTransformTranslate(transform, newSize.width, 0);
            transform = CGAffineTransformRotate(transform, M_PI_2);
            break;
            
        case UIImageOrientationRight:          // EXIF = 8
        case UIImageOrientationRightMirrored:  // EXIF = 7
            transform = CGAffineTransformTranslate(transform, 0, newSize.height);
            transform = CGAffineTransformRotate(transform, -M_PI_2);
            break;
        default:
            break;
    }
    
    switch (self.imageOrientation) {
        case UIImageOrientationUpMirrored:     // EXIF = 2
        case UIImageOrientationDownMirrored:   // EXIF = 4
            transform = CGAffineTransformTranslate(transform, newSize.width, 0);
            transform = CGAffineTransformScale(transform, -1, 1);
            break;
            
        case UIImageOrientationLeftMirrored:   // EXIF = 5
        case UIImageOrientationRightMirrored:  // EXIF = 7
            transform = CGAffineTransformTranslate(transform, newSize.height, 0);
            transform = CGAffineTransformScale(transform, -1, 1);
            break;
        default:
            break;
    }
    
    return transform;
}

- (UIImage *)squareImage
{
    CGSize imgSize = self.size;
    if (imgSize.width !=  imgSize.height) {
        CGFloat image_x =0.0;
        CGFloat image_y =0.0;
        UIImage *image = nil;
        if (imgSize.width >  imgSize.height) {
            image_x = (imgSize.width -imgSize.height)/2;
            image = [self imageCroppedInRect:CGRectMake(image_x, 0, imgSize.height, imgSize.height)];
        }else{
            image_y = (imgSize.height -imgSize.width)/2;
            image = [self imageCroppedInRect:CGRectMake(0,image_y, imgSize.width, imgSize.width)];
        }
        return image;
    }
    return self;
}

//UIView转换为UIImage
+ (UIImage *)imageWithView:(UIView *)view
{
    //支持retina高分的关键
    UIGraphicsBeginImageContextWithOptions(view.bounds.size, NO, [UIScreen mainScreen].scale);
    [view.layer renderInContext:UIGraphicsGetCurrentContext()];
    
    UIImage *resImage = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    return resImage;
}

- (CGAffineTransform)orientationTransform
{
    CGAffineTransform rectTransform;
    switch (self.imageOrientation)
    {
        case UIImageOrientationLeft:
            rectTransform = CGAffineTransformTranslate(CGAffineTransformMakeRotation(DegreesToRadians(90)), 0, -self.size.height);
            break;
        case UIImageOrientationRight:
            rectTransform = CGAffineTransformTranslate(CGAffineTransformMakeRotation(DegreesToRadians(-90)), -self.size.width, 0);
            break;
        case UIImageOrientationDown:
            rectTransform = CGAffineTransformTranslate(CGAffineTransformMakeRotation(DegreesToRadians(-180)), -self.size.width, -self.size.height);
            break;
        default:
            rectTransform = CGAffineTransformIdentity;
    };
    
    return CGAffineTransformScale(rectTransform, self.scale, self.scale);
}

- (UIImage *)imageCroppedInRect:(CGRect)visibleRect
{
    //transform visible rect to image orientation
    CGAffineTransform rectTransform = [self orientationTransform];
    visibleRect = CGRectApplyAffineTransform(visibleRect, rectTransform);
    
    //crop image
    CGImageRef imageRef = CGImageCreateWithImageInRect([self CGImage], visibleRect);
    UIImage *result = [UIImage imageWithCGImage:imageRef scale:self.scale orientation:self.imageOrientation];
    CGImageRelease(imageRef);
    return result;
}

- (UIImage *)imageRotatedByRadians:(CGFloat)radians
{
    return [self imageRotatedByDegrees:RadiansToDegrees(radians)];
}

- (UIImage *)imageRotatedByDegrees:(CGFloat)degrees
{
    // calculate the size of the rotated view's containing box for our drawing space
    UIView *rotatedViewBox = [[UIView alloc] initWithFrame:CGRectMake(0,0,self.size.width, self.size.height)];
    CGAffineTransform t = CGAffineTransformMakeRotation(DegreesToRadians(degrees));
    rotatedViewBox.transform = t;
    CGSize rotatedSize = rotatedViewBox.frame.size;
    
    // Create the bitmap context
    UIGraphicsBeginImageContext(rotatedSize);
    CGContextRef bitmap = UIGraphicsGetCurrentContext();
    
    // Move the origin to the middle of the image so we will rotate and scale around the center.
    CGContextTranslateCTM(bitmap, rotatedSize.width/2, rotatedSize.height/2);
    
    //   // Rotate the image context
    CGContextRotateCTM(bitmap, DegreesToRadians(degrees));
    
    // Now, draw the rotated/scaled image into the context
    CGContextScaleCTM(bitmap, 1.0, -1.0);
    CGContextDrawImage(bitmap, CGRectMake(-self.size.width / 2, -self.size.height / 2, self.size.width, self.size.height), [self CGImage]);
    
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return newImage;
}

//模糊化图片
- (UIImage *)imageBluredByRadius:(CGFloat)radius
{
    //create our blurred image
    CIContext *context = [CIContext contextWithOptions:nil];
    CIImage *inputImage = [CIImage imageWithCGImage:self.CGImage];
    
    //setting up Gaussian Blur (we could use one of many filters offered by Core Image)
    CIFilter *filter = [CIFilter filterWithName:@"CIGaussianBlur"];
    [filter setValue:inputImage forKey:kCIInputImageKey];
    [filter setValue:[NSNumber numberWithFloat:radius] forKey:@"inputRadius"];
    CIImage *result = [filter valueForKey:kCIOutputImageKey];
    //CIGaussianBlur has a tendency to shrink the image a little, this ensures it matches up exactly to the bounds of our original image
    CGImageRef cgImage = [context createCGImage:result fromRect:[inputImage extent]];
    UIImage *image = [UIImage imageWithCGImage:cgImage scale:self.scale orientation:self.imageOrientation];
    CGImageRelease(cgImage);
    
    return image;
}

//黑白图片
- (UIImage*)monochromeImage
{
    CIImage *beginImage = [CIImage imageWithCGImage:[self CGImage]];
    
    CIColor *ciColor = [CIColor colorWithCGColor:[UIColor lightGrayColor].CGColor];
    CIFilter *filter = nil;
    CIImage *outputImage;
    
    filter = [CIFilter filterWithName:@"CIColorMonochrome" keysAndValues:kCIInputImageKey, beginImage, kCIInputColorKey, ciColor, nil];
    outputImage = [filter outputImage];
    
    [EAGLContext setCurrentContext:nil];
    
    return [UIImage imageWithCIImage:outputImage scale:self.scale orientation:self.imageOrientation];
}

//灰度化图片
- (UIImage *)grayscaleImage
{
    CGRect imageRect = CGRectMake(0, 0, self.size.width, self.size.height);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
    CGContextRef context = CGBitmapContextCreate(nil, self.size.width, self.size.height, 8, 0, colorSpace, kCGImageAlphaNone);
    CGContextDrawImage(context, imageRect, [self CGImage]);
    CGImageRef imageRef = CGBitmapContextCreateImage(context);
    
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    UIImage *newImage = [UIImage imageWithCGImage:imageRef scale:self.scale orientation:self.imageOrientation];
    CGImageRelease(imageRef);
    
    return newImage;
}

//修正图片方向
- (UIImage *)fixOrientation
{
    if (self.imageOrientation == UIImageOrientationUp) return self;
    
    // The UIImage methods size and drawInRect take into account
    //  the value of its imageOrientation property
    //  so the rendered image is rotated as necessary.
    UIGraphicsBeginImageContextWithOptions(self.size, NO, self.scale);
    
    [self drawInRect:CGRectMake(0, 0, self.size.width, self.size.height)];
    
    UIImage *orientedImage = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    return orientedImage;
}

//反转后的遮罩图片
- (UIImage *)inverseMaskImage
{
    UIImage *image = [UIImage imageWithColor:[UIColor blackColor] size:self.size];
    
    CGImageRef maskRef = self.CGImage;
    CGImageRef mask = CGImageMaskCreate(CGImageGetWidth(maskRef),
                                        CGImageGetHeight(maskRef),
                                        CGImageGetBitsPerComponent(maskRef),
                                        CGImageGetBitsPerPixel(maskRef),
                                        CGImageGetBytesPerRow(maskRef),
                                        CGImageGetDataProvider(maskRef), NULL, false);
    
    CGImageRef sourceImage = [image CGImage];
    CGImageRef imageWithAlpha = sourceImage;
    //add alpha channel for images that don't have one (ie GIF, JPEG, etc...)
    //this however has a computational cost
    if (CGImageGetAlphaInfo(sourceImage) == kCGImageAlphaNone) {
        //copyImageAndAddAlphaChannel
        CGImageRef retVal = NULL;
        
        size_t width = CGImageGetWidth(sourceImage);
        size_t height = CGImageGetHeight(sourceImage);
        
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGContextRef offscreenContext = CGBitmapContextCreate(NULL, width, height, 8, 0, colorSpace,
                                                              kCGImageAlphaPremultipliedFirst);
        if (offscreenContext != NULL) {
            CGContextDrawImage(offscreenContext, CGRectMake(0, 0, width, height), sourceImage);
            retVal = CGBitmapContextCreateImage(offscreenContext);
            CGContextRelease(offscreenContext);
        }
        CGColorSpaceRelease(colorSpace);
        imageWithAlpha = retVal;
    }
    
    CGImageRef masked = CGImageCreateWithMask(imageWithAlpha, mask);
    CGImageRelease(mask);
    
    //release imageWithAlpha if it was created by CopyImageAndAddAlphaChannel
    if (sourceImage != imageWithAlpha) {
        CGImageRelease(imageWithAlpha);
    }
    
    UIImage *retImage = [UIImage imageWithCGImage:masked scale:self.scale orientation:self.imageOrientation];
    
    CGImageRelease(masked);
    
    return retImage;
}



//根据给定的颜色和模式替换图片中的色彩
- (UIImage *)tintedImageWithColor:(UIColor*)color style:(UIImageTintStyle)tintStyle
{
    if (!color)
        return self;
    
    CGFloat scale = self.scale;
    CGSize size = CGSizeMake(scale * self.size.width, scale * self.size.height);
    
    UIGraphicsBeginImageContext(size);
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextTranslateCTM(context, 0, size.height);
    CGContextScaleCTM(context, 1.0, -1.0);
    
    CGRect rect = CGRectMake(0, 0, size.width, size.height);
    
    // ---
    
    if (tintStyle == UIImageTintStyleKeepingAlpha)
    {
        CGContextSetBlendMode(context, kCGBlendModeNormal);
        CGContextDrawImage(context, rect, self.CGImage);
        CGContextSetBlendMode(context, kCGBlendModeSourceIn);
        [color setFill];
        CGContextFillRect(context, rect);
    }
    else if (tintStyle == UIImageTintStyleOverAlpha)
    {
        [color setFill];
        CGContextFillRect(context, rect);
        CGContextSetBlendMode(context, kCGBlendModeNormal);
        CGContextDrawImage(context, rect, self.CGImage);
    }
    else if (tintStyle == UIImageTintStyleOverAlphaExtreme)
    {
        [color setFill];
        CGContextFillRect(context, rect);
        CGContextSetBlendMode(context, kCGBlendModeDestinationOut);
        CGContextDrawImage(context, rect, self.CGImage);
    }
    
    // ---
    CGImageRef bitmapContext = CGBitmapContextCreateImage(context);
    
    UIImage *coloredImage = [UIImage imageWithCGImage:bitmapContext scale:scale orientation:self.imageOrientation];
    
    CGImageRelease(bitmapContext);
    
    UIGraphicsEndImageContext();
    
    return coloredImage;
}

//通过指定宽高的最大像素值来获取对应的缩略图
- (UIImage *)thumbnailImageWithMaxPixelSize:(CGFloat)maxPixelSize
{
    CGSize dimensions = self.size;
    CGSize thumbSize = dimensions;
    
    if (dimensions.height > dimensions.width && dimensions.height > maxPixelSize) {
        thumbSize.width = floorf(dimensions.width / dimensions.height * maxPixelSize);
        thumbSize.height = floorf(dimensions.height / dimensions.width * thumbSize.width);
    }
    else if (dimensions.height <= dimensions.width && dimensions.width > maxPixelSize) {
        thumbSize.height = floorf(dimensions.height / dimensions.width * maxPixelSize);
        thumbSize.width = floorf(dimensions.width / dimensions.height * thumbSize.height);
    }
    
    if (!CGSizeEqualToSize(thumbSize, dimensions)) {
        return [self imageWithSize:thumbSize];
    }
    return  self;
}

@end
