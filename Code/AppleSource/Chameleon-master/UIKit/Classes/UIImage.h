#import "UIGeometry.h"

typedef NS_ENUM(NSInteger, UIImageOrientation) {
    UIImageOrientationUp,
    UIImageOrientationDown,   // 180 deg rotation
    UIImageOrientationLeft,   // 90 deg CCW
    UIImageOrientationRight,   // 90 deg CW
    UIImageOrientationUpMirrored,    // as above but image mirrored along
    // other axis. horizontal flip
    UIImageOrientationDownMirrored,  // horizontal flip
    UIImageOrientationLeftMirrored,  // vertical flip
    UIImageOrientationRightMirrored, // vertical flip
};

@interface UIImage : NSObject {
@private
    NSArray *_representations;
}

+ (UIImage *)imageNamed:(NSString *)name;			// Note, this caches the images somewhat like iPhone OS 2ish in that it never releases them. :)
+ (UIImage *)imageWithData:(NSData *)data;
+ (UIImage *)imageWithContentsOfFile:(NSString *)path;
+ (UIImage *)imageWithCGImage:(CGImageRef)imageRef;
+ (UIImage *)imageWithCGImage:(CGImageRef)imageRef scale:(CGFloat)scale orientation:(UIImageOrientation)orientation;

- (id)initWithData:(NSData *)data;
- (id)initWithContentsOfFile:(NSString *)path;
- (id)initWithCGImage:(CGImageRef)imageRef;
- (id)initWithCGImage:(CGImageRef)imageRef scale:(CGFloat)scale orientation:(UIImageOrientation)orientation;

- (UIImage *)stretchableImageWithLeftCapWidth:(NSInteger)leftCapWidth topCapHeight:(NSInteger)topCapHeight;
- (UIImage *)resizableImageWithCapInsets:(UIEdgeInsets)capInsets;   // not correctly implemented

// the draw methods will all check the scale of the current context and attempt to use the best representation it can
- (void)drawAtPoint:(CGPoint)point blendMode:(CGBlendMode)blendMode alpha:(CGFloat)alpha;
- (void)drawInRect:(CGRect)rect blendMode:(CGBlendMode)blendMode alpha:(CGFloat)alpha;
- (void)drawAtPoint:(CGPoint)point;
- (void)drawInRect:(CGRect)rect;

@property (nonatomic, readonly) CGSize size;
@property (nonatomic, readonly) NSInteger leftCapWidth;
@property (nonatomic, readonly) NSInteger topCapHeight;
@property (nonatomic, readonly) UIImageOrientation imageOrientation;	// not implemented

// note that these properties return always the 2x represention if it exists!
@property (nonatomic, readonly) CGImageRef CGImage;
@property (nonatomic, readonly) CGFloat scale;

@end

void UIImageWriteToSavedPhotosAlbum(UIImage *image, id completionTarget, SEL completionSelector, void *contextInfo);
void UISaveVideoAtPathToSavedPhotosAlbum(NSString *videoPath, id completionTarget, SEL completionSelector, void *contextInfo);
BOOL UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(NSString *videoPath);

// both of these use .CGImage to generate the image data - note what this means for multi-scale images!
NSData *UIImageJPEGRepresentation(UIImage *image, CGFloat compressionQuality);
NSData *UIImagePNGRepresentation(UIImage *image);
