#import <Foundation/Foundation.h>

@interface UIImageRep : NSObject

+ (NSArray *)imageRepsWithContentsOfFile:(NSString *)file;

- (id)initWithCGImageSource:(CGImageSourceRef)source imageIndex:(NSUInteger)index scale:(CGFloat)scale;
- (id)initWithCGImage:(CGImageRef)image scale:(CGFloat)scale;
- (id)initWithData:(NSData *)data;

// note that the cordinates for fromRect are in the image's *scaled* coordinate system, not in raw pixels
// so for a 100x100px image with a scale of 2, the largest valid fromRect is of size 50x50.
- (void)drawInRect:(CGRect)rect fromRect:(CGRect)fromRect;

@property (nonatomic, readonly) CGSize imageSize;
@property (nonatomic, readonly) CGImageRef CGImage;
@property (nonatomic, readonly, getter=isLoaded) BOOL loaded;
@property (nonatomic, readonly) CGFloat scale;
@property (nonatomic, readonly, getter=isOpaque) BOOL opaque;

@end
