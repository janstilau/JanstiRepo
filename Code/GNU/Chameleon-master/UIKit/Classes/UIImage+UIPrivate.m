#import "UIImage+UIPrivate.h"
#import "UIImageAppKitIntegration.h"
#import "UIColor.h"
#import "UIGraphics.h"
#import "UIImageRep.h"
#import <AppKit/NSImage.h>

NSMutableDictionary *imageCache = nil; // UIImage 的缓存.

@implementation UIImage (UIPrivate)

+ (void)load
{
    imageCache = [[NSMutableDictionary alloc] init];
}

+ (void)_cacheImage:(UIImage *)image forName:(NSString *)name
{
    if (image && name) {
        [imageCache setObject:image forKey:name];
    }
}

+ (UIImage *)_cachedImageForName:(NSString *)name
{
    return [imageCache objectForKey:name];
}

+ (UIImage *)_frameworkImageWithName:(NSString *)name leftCapWidth:(NSUInteger)leftCapWidth topCapHeight:(NSUInteger)topCapHeight
{
    UIImage *image = [self _cachedImageForName:name];

    if (!image) {
        NSBundle *frameworkBundle = [NSBundle bundleWithIdentifier:@"org.chameleonproject.UIKit"];
        NSString *frameworkFile = [[frameworkBundle resourcePath] stringByAppendingPathComponent:name];
        image = [[self imageWithContentsOfFile:frameworkFile] stretchableImageWithLeftCapWidth:leftCapWidth topCapHeight:topCapHeight];
        [self _cacheImage:image forName:name];
    }

    return image;
}

// 类方法, 提供了可以最常用的图片.

+ (UIImage *)_backButtonImage
{
    return [self _frameworkImageWithName:@"<UINavigationBar> back.png" leftCapWidth:18 topCapHeight:0];
}

+ (UIImage *)_highlightedBackButtonImage
{
    return [self _frameworkImageWithName:@"<UINavigationBar> back-highlighted.png" leftCapWidth:18 topCapHeight:0];
}

+ (UIImage *)_toolbarButtonImage
{
    return [self _frameworkImageWithName:@"<UIToolbar> button.png" leftCapWidth:6 topCapHeight:0];
}

+ (UIImage *)_highlightedToolbarButtonImage
{
    return [self _frameworkImageWithName:@"<UIToolbar> button-highlighted.png" leftCapWidth:6 topCapHeight:0];
}

+ (UIImage *)_leftPopoverArrowImage
{
    return [self _frameworkImageWithName:@"<UIPopoverView> arrow-left.png" leftCapWidth:0 topCapHeight:0];
}

+ (UIImage *)_rightPopoverArrowImage
{
    return [self _frameworkImageWithName:@"<UIPopoverView> arrow-right.png" leftCapWidth:0 topCapHeight:0];
}

+ (UIImage *)_topPopoverArrowImage
{
    return [self _frameworkImageWithName:@"<UIPopoverView> arrow-top.png" leftCapWidth:0 topCapHeight:0];
}

+ (UIImage *)_bottomPopoverArrowImage
{
    return [self _frameworkImageWithName:@"<UIPopoverView> arrow-bottom.png" leftCapWidth:0 topCapHeight:0];
}

+ (UIImage *)_popoverBackgroundImage
{
    return [self _frameworkImageWithName:@"<UIPopoverView> background.png" leftCapWidth:23 topCapHeight:23];
}

+ (UIImage *)_roundedRectButtonImage
{
    return [self _frameworkImageWithName:@"<UIRoundedRectButton> normal.png" leftCapWidth:12 topCapHeight:9];
}

+ (UIImage *)_highlightedRoundedRectButtonImage
{
    return [self _frameworkImageWithName:@"<UIRoundedRectButton> highlighted.png" leftCapWidth:12 topCapHeight:9];
}

+ (UIImage *)_windowResizeGrabberImage
{
    return [self _frameworkImageWithName:@"<UIScreen> grabber.png" leftCapWidth:0 topCapHeight:0];
}

+ (UIImage *)_buttonBarSystemItemAdd
{
    return [self _frameworkImageWithName:@"<UIBarButtonSystemItem> add.png" leftCapWidth:0 topCapHeight:0];
}

+ (UIImage *)_buttonBarSystemItemReply
{
    return [self _frameworkImageWithName:@"<UIBarButtonSystemItem> reply.png" leftCapWidth:0 topCapHeight:0];
}

+ (UIImage *)_tabBarBackgroundImage
{
  return [self _frameworkImageWithName:@"<UITabBar> background.png" leftCapWidth:6 topCapHeight:0];
}

+ (UIImage *)_tabBarItemImage
{
  return [self _frameworkImageWithName:@"<UITabBar> item.png" leftCapWidth:8 topCapHeight:0];
}

- (id)_initWithRepresentations:(NSArray *)reps
{
    if ([reps count] == 0) {
        self = nil;
    } else if ((self=[super init])) {
        _representations = [reps copy];
    }
    
    return self;
}

- (NSArray *)_representations
{
    return _representations;
}

- (UIImageRep *)_bestRepresentationForProposedScale:(CGFloat)scale
{
    UIImageRep *bestRep = nil;
    
    for (UIImageRep *rep in [self _representations]) {
        if (rep.scale > scale) {
            break;
        } else {
            bestRep = rep;
        }
    }
    
    return bestRep ?: [[self _representations] lastObject];
}

- (BOOL)_isOpaque
{
    for (UIImageRep *rep in [self _representations]) {
        if (!rep.opaque) {
            return NO;
        }
    }
    return YES;
}

- (void)_drawRepresentation:(UIImageRep *)rep inRect:(CGRect)rect
{
    [rep drawInRect:rect fromRect:CGRectNull];
}

- (UIImage *)_toolbarImage
{
    // NOTE.. I don't know where to put this, really, but it seems like the real UIKit reduces image size by 75% if they are too
    // big for a toolbar. That seems funky, but I guess here is as good a place as any to do that? I don't really know...
    
    CGSize imageSize = self.size;
    CGSize size = CGSizeZero;
    
    if (imageSize.width > 24 || imageSize.height > 24) {
        size.height = imageSize.height * 0.75f;
        size.width = imageSize.width / imageSize.height * size.height;
    } else {
        size = imageSize;
    }
    
    CGRect rect = CGRectMake(0,0,size.width,size.height);
    
    UIGraphicsBeginImageContextWithOptions(size, NO, self.scale);
    [[UIColor colorWithRed:101/255.f green:104/255.f blue:121/255.f alpha:1] setFill];
    UIRectFill(rect);
    [self drawInRect:rect blendMode:kCGBlendModeDestinationIn alpha:1];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

@end
