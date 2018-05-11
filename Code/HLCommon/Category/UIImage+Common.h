//
//  UIImage+Common.h
//  HLMagic
//
//  Created by marujun on 13-12-8.
//  Copyright (c) 2013年 chen ying. All rights reserved.
//

#import <UIKit/UIKit.h>

CGFloat DegreesToRadians(CGFloat degrees);
CGFloat RadiansToDegrees(CGFloat radians);

typedef struct __UICornerInset
{
    CGFloat topLeft;
    CGFloat topRight;
    CGFloat bottomLeft;
    CGFloat bottomRight;
} UICornerInset;

UIKIT_EXTERN const UICornerInset UICornerInsetZero;

UIKIT_STATIC_INLINE UICornerInset UICornerInsetMake(CGFloat topLeft, CGFloat topRight, CGFloat bottomLeft, CGFloat bottomRight)
{
    UICornerInset cornerInset = {topLeft, topRight, bottomLeft, bottomRight};
    return cornerInset;
}

UIKIT_STATIC_INLINE UICornerInset UICornerInsetMakeWithRadius(CGFloat radius)
{
    UICornerInset cornerInset = {radius, radius, radius, radius};
    return cornerInset;
}

UIKIT_STATIC_INLINE BOOL UICornerInsetEqualToCornerInset(UICornerInset cornerInset1, UICornerInset cornerInset2)
{
    return
    cornerInset1.topLeft == cornerInset2.topLeft &&
    cornerInset1.topRight == cornerInset2.topRight &&
    cornerInset1.bottomLeft == cornerInset2.bottomLeft &&
    cornerInset1.bottomRight == cornerInset2.bottomRight;
}

/**
 * The image tinting styles.
 **/
typedef enum __USImageTintStyle
{
    /**
     * Keep transaprent pixels (alpha == 0) and tint all other pixels.
     **/
    UIImageTintStyleKeepingAlpha      = 1,
    
    /**
     * Keep non transparent pixels and tint only those that are translucid.
     **/
    UIImageTintStyleOverAlpha         = 2,
    
    /**
     * Remove (turn to transparent) non transparent pixels and tint only those that are translucid.
     **/
    UIImageTintStyleOverAlphaExtreme  = 3,
    
} UIImageTintStyle;

@interface UIImage (Common)

+ (UIImage *)defaultImage;
+ (UIImage *)defaultAvatar;

+ (UIImage *)screenshot;
+ (UIImage *)imageWithColor:(UIColor *)color;
+ (UIImage *)imageWithColor:(UIColor *)color size:(CGSize)size;
+ (UIImage *)imageWithColor:(UIColor *)color cornerRadius:(CGFloat)cornerRadius;
+ (UIImage *)imageWithColor:(UIColor *)color size:(CGSize)size cornerInset:(UICornerInset)cornerInset;

- (UIImage *)imageWithSize:(CGSize)newSize;
- (UIImage *)imageWithSize:(CGSize)newSize interpolationQuality:(CGInterpolationQuality)quality;

- (UIImage *)squareImage;

+ (UIImage *)imageWithView:(UIView *)view;

/** 裁剪图片中的一部分 */
- (UIImage *)imageCroppedInRect:(CGRect)visibleRect;

/** 模糊化图片 */
- (UIImage *)imageBluredByRadius:(CGFloat)radius;

/** 黑白图片 */
- (UIImage*)monochromeImage;

/** 灰度化图片 */
- (UIImage *)grayscaleImage;

/** 修正图片的方向信息 */
- (UIImage *)fixOrientation;

/** 通过弧度旋转图片 */
- (UIImage *)imageRotatedByRadians:(CGFloat)radians;

/** 通过角度旋转图片 */
- (UIImage *)imageRotatedByDegrees:(CGFloat)degrees;

/** 反转后的遮罩图片，效果：纯白色表示被遮罩区域将完全透明，纯黑色表示被遮罩区域将会原封不动保留下来，
 灰色部分(0x000000~0xFFFFFF)表示被遮罩区域将会处理成半透明的效果 */
- (UIImage *)inverseMaskImage;

/** 根据给定的颜色和模式替换图片中的色彩 */
- (UIImage *)tintedImageWithColor:(UIColor*)color style:(UIImageTintStyle)tintStyle;

/** 通过指定宽高的最大像素值来获取对应的缩略图 */
- (UIImage *)thumbnailImageWithMaxPixelSize:(CGFloat)maxPixelSize;

@end
