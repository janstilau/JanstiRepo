#include <string.h>
#include <math.h>

#import <Foundation/NSArray.h>
#import <Foundation/NSBundle.h>
#import <Foundation/NSDebug.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>
#import <Foundation/NSFileManager.h>
#import <Foundation/NSKeyedArchiver.h>
#import <Foundation/NSLock.h>
#import <Foundation/NSNotification.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>

#import "AppKit/NSImage.h"
#import "GSTheme.h"

#import "AppKit/NSAffineTransform.h"
#import "AppKit/NSBitmapImageRep.h"
#import "AppKit/NSCachedImageRep.h"
#import "AppKit/NSColor.h"
#import "AppKit/NSPasteboard.h"
#import "AppKit/NSPrintOperation.h"
#import "AppKit/NSScreen.h"
#import "AppKit/NSView.h"
#import "AppKit/NSWindow.h"
#import "AppKit/DPSOperators.h"
#import "GNUstepGUI/GSDisplayServer.h"
#import "GSThemePrivate.h"

BOOL NSImageForceCaching = NO; /* use on missmatch */

static NSDictionary		*nsmapping = nil;

// OS_API_VERSION(MAC_OS_X_VERSION_10_5, GS_API_LATEST)
NSString *const NSImageNameQuickLookTemplate        = @"NSQuickLookTemplate";
NSString *const NSImageNameBluetooth                = @"NSBluetoothTemplate";
NSString *const NSImageNameIChatTheater             = @"NSIChatTheaterTemplate";
NSString *const NSImageNameSlideshow                = @"NSSlideshowTemplate";
NSString *const NSImageNameAction                   = @"NSActionTemplate";
NSString *const NSImageNameSmartBadge               = @"NSSmartBadgeTemplate";
NSString *const NSImageNameIconView                 = @"NSIconViewTemplate";
NSString *const NSImageNameListView                 = @"NSListViewTemplate";
NSString *const NSImageNameColumnView               = @"NSColumnViewTemplate";
NSString *const NSImageNameFlowView                 = @"NSFlowViewTemplate";
NSString *const NSImageNamePath                     = @"NSPathTemplate";
NSString *const NSImageNameInvalidDataFreestanding  = @"NSInvalidDataFreestandingTemplate";
NSString *const NSImageNameLockLocked               = @"NSLockLockedTemplate";
NSString *const NSImageNameLockUnlocked             = @"NSLockUnlockedTemplate";
NSString *const NSImageNameGoRight                  = @"NSGoRightTemplate";
NSString *const NSImageNameGoLeft                   = @"NSGoLeftTemplate";
NSString *const NSImageNameRightFacingTriangle      = @"NSRightFacingTriangleTemplate";
NSString *const NSImageNameLeftFacingTriangle       = @"NSLeftFacingTriangleTemplate";
NSString *const NSImageNameAdd                      = @"NSAddTemplate";
NSString *const NSImageNameRemove                   = @"NSRemoveTemplate";
NSString *const NSImageNameRevealFreestanding       = @"NSRevealFreestandingTemplate";
NSString *const NSImageNameFollowLinkFreestanding   = @"NSFollowLinkFreestandingTemplate";
NSString *const NSImageNameEnterFullScreen          = @"NSEnterFullScreenTemplate";
NSString *const NSImageNameExitFullScreen           = @"NSExitFullScreenTemplate";
NSString *const NSImageNameStopProgress             = @"NSStopProgressTemplate";
NSString *const NSImageNameStopProgressFreestanding = @"NSStopProgressFreestandingTemplate";
NSString *const NSImageNameRefresh                  = @"NSRefreshTemplate";
NSString *const NSImageNameRefreshFreestanding      = @"NSRefreshFreestandingTemplate";
NSString *const NSImageNameBonjour                  = @"NSBonjour";
NSString *const NSImageNameComputer                 = @"NSComputer";
NSString *const NSImageNameFolderBurnable           = @"NSFolderBurnable";
NSString *const NSImageNameFolderSmart              = @"NSFolderSmart";
NSString *const NSImageNameNetwork                  = @"NSNetwork";

@interface NSView (Private)
- (void) _lockFocusInContext: (NSGraphicsContext *)ctxt inRect: (NSRect)rect;
@end

@implementation NSBundle (NSImageAdditions)

static NSArray*
imageTypes()
{
    NSArray   *types;
    
    /* If the extension is one of the image types,
     * remove it from the name and place it in the
     * type argument.
     */
    types = [[[GSTheme theme] imageClass] imageUnfilteredFileTypes];
    if (nil == types)
    {
        types = [NSImage imageUnfilteredFileTypes];
    }
    return types;
}

static void
fixupImageNameAndType(NSString **name, NSString **type)
{
    NSString      *ext = [*name pathExtension];
    
    if ([ext length] > 0)
    {
        /* If the extension is one of the image types,
         * remove it from the name and place it in the
         * type argument.
         */
        if ([imageTypes() indexOfObject: ext] != NSNotFound)
        {
            *type = ext;
            *name = [*name stringByDeletingPathExtension];
        }
    }
}

- (NSString *) _pathForImageNamed: (NSString *)aName 
                           ofType: (NSString *)ext
                     subdirectory: (NSString *)aDir
                         inBundle: (NSBundle *)aBundle
{
    NSEnumerator  *e;
    id            o;
    
    if (ext != nil)
    {
        return [aBundle pathForResource: aName ofType: ext inDirectory: aDir];
    }
    
    e = [imageTypes() objectEnumerator];
    while ((o = [e nextObject]) != nil)
    {
        NSString  *path;
        
        path = [aBundle pathForResource: aName ofType: o inDirectory: aDir];
        if ([path length] > 0)
        {
            return path;
        }
    }
    return nil;
}

- (NSString *) _pathForLibraryImageNamed: (NSString *)aName 
                                  ofType: (NSString *)ext
                             inDirectory: (NSString *)aDir
{
    NSEnumerator *e;
    id            o;
    
    if (ext != nil)
    {
        return [NSBundle pathForLibraryResource: aName
                                         ofType: ext
                                    inDirectory: aDir];
    }
    
    e = [imageTypes() objectEnumerator];
    while ((o = [e nextObject]) != nil)
    {
        NSString *path;
        
        path = [NSBundle pathForLibraryResource: aName
                                         ofType: o
                                    inDirectory: aDir];
        if ([path length] > 0)
        {
            return path;
        }
    }
    
    return nil;
}

- (NSString *) _pathForSystemImageNamed: (NSString *)realName 
                                 ofType: (NSString *)ext
{
    NSString      *path;
    
    path = [self _pathForLibraryImageNamed: realName
                                    ofType: ext
                               inDirectory: @"Images"];
    
    /* If not found then search in system using the reverse NSImage nsmapping */
    if (nil == path)
    {
        NSEnumerator      *e;
        NSString          *aliasName;
        
        e = [[nsmapping allKeysForObject: realName] objectEnumerator];
        while ((aliasName = [e nextObject]) != nil)
        {
            path = [self _pathForLibraryImageNamed: aliasName
                                            ofType: ext
                                       inDirectory: @"Images"];
            
            if (path != nil)
            {
                break;
            }
        }
    }
    
    return path;
}

/*
 * nsmapping.strings maps alternative image naming schemes to the GSTheme
 * standard image naming scheme. For example, NSSwitch (from OpenStep) and
 * common_SwitchOff (from GNUstep) are mapped to GSSwitch. In nameDict that
 * tracks image instances, the keys are image names from GSTheme such as
 * GSSwitch or additional icon names such NSApplicationIcon or
 * NSToolbarShowColors. In the long run, it would be cleaner to move built-in
 * theme images into a GNUstep.theme bundle.
 *
 * If you pass NSSwitch to +imageNamed:, nsmapping is used to get GSSwitch as
 * the real name, then _pathForImageNamed: will look up the image first in the
 * theme and fall back on the Library images. For the library images, we do a
 * reverse lookup in nsmapping (using allKeysForObject:) to get the image file
 * name (e.g. from GSSwitch to common_SwitchOff). This reverse lookup is
 * similar to the one supported for getting image file names from the
 * bundle, this reverse lookup could be handled by GSTheme rather than being
 *
 * The type received in argument is meaningfull for searching image files
 * using the proposed image name, but useless otherwise.
 */
- (NSString *) _pathForThemeImageNamed: (NSString *)name 
                                ofType: (NSString *)ext
{
    GSTheme       *theme;
    NSDictionary  *themeMapping;
    NSString      *mappedName;
    NSString      *path = nil;
    
    theme = [GSTheme theme];
    themeMapping = [[theme infoDictionary] objectForKey: @"GSThemeImages"];
    mappedName = [themeMapping objectForKey: name];
    
    /* First search among the theme images using the GSTheme mapping */
    if (mappedName != nil)
    {
        NSString *extension = nil;
        NSString *proposedName = mappedName;
        
        fixupImageNameAndType(&proposedName, &extension);
        
        /* If the image file name from the theme mapping uses an extension,
         * this extension is used to look up the path. If the image file
         * cannot be found, _pathForImageNamed:ofType:subdirectory:inBundle:
         * searches an image file for the file extensions from -imageFileTypes.
         */
        path = [self _pathForImageNamed: proposedName
                                 ofType: extension
                           subdirectory: @"ThemeImages"
                               inBundle: [theme bundle]];
    }
    
    /* If not found, search among the theme images using the reverse NSImage
     * mapping (for GNUstep and OpenStep image names such as common_SwitchOff
     * or NSSwitch)
     */
    if (nil == path)
    {
        NSEnumerator      *e;
        NSString          *aliasName;
        
        e = [[nsmapping allKeysForObject: name] objectEnumerator];
        while (nil == path && (aliasName = [e nextObject]) != nil)
        {
            NSAssert([[aliasName pathExtension] length] == 0,
                     @"nsmapping.strings "
                     "must include no extensions in image file names");
            
            path = [self _pathForImageNamed: aliasName
                                     ofType: nil
                               subdirectory: @"ThemeImages"
                                   inBundle: [theme bundle]];
        }
    }
    
    /* If not found, search among the theme images using the image name directly
     */
    if (path == nil)
    {
        path = [self _pathForImageNamed: name
                                 ofType: ext
                           subdirectory: @"ThemeImages"
                               inBundle: [theme bundle]];
    }
    
    return path;
}

- (NSString*) pathForImageResource: (NSString*)name
{
    NSString      *ext = nil;
    NSString      *path = nil;
    NSString      *ident;
    
    fixupImageNameAndType(&name, &ext);
    if (nil != (ident = [self bundleIdentifier]))
    {
        NSString  *subdir;
        
        subdir = [@"ThemeImages" stringByAppendingPathComponent: ident];
        path = [self _pathForImageNamed: name
                                 ofType: ext
                           subdirectory: subdir
                               inBundle: [[GSTheme theme] bundle]];
    }
    if (nil == path)
    {
        path = [self _pathForImageNamed: name
                                 ofType: ext
                           subdirectory: nil
                               inBundle: self];
        if (nil == path)
        {
            path = [self _pathForThemeImageNamed: name ofType: ext];
            if (nil == path)
            {
                path = [self _pathForSystemImageNamed: name ofType: ext];
            }
        }
    }
    return path;
}

@end

@interface GSRepData : NSObject
{
@public
    NSImageRep *rep;
    NSImageRep *original;
    NSColor *bg;
}
@end

@implementation GSRepData
- (id) copyWithZone: (NSZone*)z
{
    GSRepData *c = (GSRepData*)NSCopyObject(self, 0, z);
    
    if (c->rep)
        c->rep = [c->rep copyWithZone: z];
    if (c->bg)
        c->bg = [c->bg copyWithZone: z];
    return c;
}

- (void) dealloc
{
    TEST_RELEASE(rep);
    TEST_RELEASE(bg);
    [super dealloc];
}
@end

/* Class variables and functions for class methods */
static NSRecursiveLock		*imageLock = nil;
static NSMutableDictionary	*nameImageCache = nil;
static NSColor			*clearColor = nil;
static Class cachedClass = 0;
static Class bitmapClass = 0;
// Cache for the supported file types
static NSArray *imageUnfilteredFileTypes = nil;
static NSArray *imageFileTypes = nil;
static NSArray *imageUnfilteredPasteboardTypes = nil;
static NSArray *imagePasteboardTypes = nil;

static NSArray *iterate_reps_for_types(NSArray *imageReps, SEL method);

/* Find the GSRepData object holding a representation */
static GSRepData*
repd_for_rep(NSArray *_reps, NSImageRep *rep)
{
    NSEnumerator *enumerator = [_reps objectEnumerator];
    IMP nextImp = [enumerator methodForSelector: @selector(nextObject)];
    GSRepData *repd;
    
    while ((repd = (*nextImp)(enumerator, @selector(nextObject))) != nil)
    {
        if (repd->rep == rep)
        {
            return repd;
        }
    }
    [NSException raise: NSInternalInconsistencyException
                format: @"Cannot find stored representation"];
    /* NOT REACHED */
    return nil;
}

@interface NSImage (Private)
+ (void) _clearFileTypeCaches: (NSNotification*)notif;
+ (void) _reloadCachedImages;
- (BOOL) _useFromFile: (NSString *)fileName;
- (BOOL) _loadFromData: (NSData *)data;
- (BOOL) _loadFromFile: (NSString *)fileName;
- (BOOL) _resetAndUseFromFile: (NSString *)fileName;
- (GSRepData*) _cacheForRep: (NSImageRep*)rep;
- (NSCachedImageRep*) _doImageCache: (NSImageRep *)rep;
@end

@implementation NSImage
{
    @public
    NSString    *_name; // 图片名, 仅仅在 ImageNamed 的时候才会有.
    NSString    *_fileName;
    NSSize    _size;
    struct __imageFlags {
        unsigned    archiveByName: 1; // 仅仅设置了 imagePath, 还没有进行二进制值得读取
        unsigned    dataRetained: 1; // 已经根据二进制的值, 读取到了 imageRep
        unsigned    scalable: 1;
        unsigned    flipDraw: 1;
        unsigned    sizeWasExplicitlySet: 1;
        unsigned    useEPSOnResolutionMismatch: 1;
        unsigned    colorMatchPreferred: 1;
        unsigned    multipleResolutionMatching: 1;
        unsigned    cacheSeparately: 1;
        unsigned    unboundedCacheDepth: 1;
        unsigned    syncLoad: 1;
    } _flags;
    NSMutableArray    *_reps; // 真正的二进制数据相关的类.
    NSColor        *_color;
    NSView                *_lockedView;
    NSImageCacheMode      _cacheMode;
}

+ (void) initialize
{
    if (imageLock == nil)
    {
        NSString *path;
        
        imageLock = [NSRecursiveLock new];
        [imageLock lock];
        
        // Initial version
        [self setVersion: 1];
        
        // initialize the class variables
        nameImageCache = [[NSMutableDictionary alloc] initWithCapacity: 10];
        path = [NSBundle pathForLibraryResource: @"nsmapping"
                                         ofType: @"strings"
                                    inDirectory: @"Images"];
        if (path)
            nsmapping = RETAIN([[NSString stringWithContentsOfFile: path]
                                propertyListFromStringsFileFormat]);
        clearColor = RETAIN([NSColor clearColor]);
        cachedClass = [NSCachedImageRep class];
        bitmapClass = [NSBitmapImageRep class];
        [[NSNotificationCenter defaultCenter]
         addObserver: self
         selector: @selector(_clearFileTypeCaches:)
         name: NSImageRepRegistryChangedNotification
         object: [NSImageRep class]];
        [imageLock unlock];
    }
}

// 通过这个方法, 仅仅设置了 filePath 的值.
+ (id) imageNamed: (NSString *)aName
{
    NSImage   *image;
    NSString  *realName;
    // 加锁, 因为这是一个可以在各个线程出现的方法.
    [imageLock lock];
    
    realName = [nsmapping objectForKey: aName];
    if (realName == nil)
    {
        realName = aName;
    }
    // 首先取得缓存数据
    image = (NSImage*)[nameImageCache objectForKey: realName];
    // 如果没有缓存数据, 那么就根据 NSBundle 的路径进行读取.
    if (image == nil && realName != nil)
    {
        NSString  *path = [[NSBundle mainBundle] pathForImageResource: realName];
        
        if ([path length] != 0)
        {
            image = [[NSImage alloc] initByReferencingFile: path];
            if (image != nil) { // 有可能加载不成功.
                [image setName: realName]; // 在这里, 修改了 nameDict 的内容.
                AUTORELEASE(image);
            }
        }
    }
    
    [[image retain] autorelease];
    [imageLock unlock];
    return image;
}

+ (NSImage *) _standardImageWithName: (NSString *)name
{
    return [NSImage imageNamed: name];
}

- (id) init
{
    return [self initWithSize: NSMakeSize(0, 0)];
}

- (id) initWithSize: (NSSize)aSize
{
    if (!(self = [super init]))
        return nil;
    
    {
        _size = aSize;
        _flags.sizeWasExplicitlySet = YES;
    }
    _flags.colorMatchPreferred = YES;
    _flags.multipleResolutionMatching = YES;
    _reps = [[NSMutableArray alloc] initWithCapacity: 2];
    ASSIGN(_color, clearColor);
    _cacheMode = NSImageCacheDefault;
    
    return self;
}

- (id) initByReferencingFile: (NSString *)fileName
{
    if (!(self = [self init]))
        return nil;
    
    if (![self _useFromFile: fileName])
    {
        RELEASE(self);
        return nil;
    }
    _flags.archiveByName = YES;
    
    return self;
}

- (id) initWithContentsOfFile: (NSString *)fileName
{
    if (!(self = [self init]))
        return nil;
    
    _flags.dataRetained = YES;
    if (![self _loadFromFile: fileName])
    {
        RELEASE(self);
        return nil;
    }
    
    return self;
}

- (id) initWithData: (NSData *)data
{
    if (!(self = [self init]))
        return nil;
    
    _flags.dataRetained = YES;
    if (![self _loadFromData: data])
    {
        RELEASE(self);
        return nil;
    }
    
    return self;
}

- (id) initWithContentsOfURL: (NSURL *)anURL
{
    NSArray *array;
    
    if (!(self = [self init]))
        return nil;
    
    array = [NSImageRep imageRepsWithContentsOfURL: anURL];
    if (!array)
    {
        RELEASE(self);
        return nil;
    }
    
    _flags.dataRetained = YES;
    [self addRepresentations: array];
    return self;
}

- (id) initWithPasteboard: (NSPasteboard *)pasteboard
{
    NSArray *reps;
    if (!(self = [self init]))
        return nil;
    
    reps = [NSImageRep imageRepsWithPasteboard: pasteboard];
    if (reps != nil)
        [self addRepresentations: reps];
    else
    {
        // 对于这种, 相当于剪贴板里面的就是一个文件路径字符串而已.
        NSArray *array = [pasteboard propertyListForType: NSFilenamesPboardType];
        NSString* file;
        
        if ((array == nil)
            || ([array count] == 0)
            || (file = [array objectAtIndex: 0]) == nil
            || ![self _loadFromFile: file])
        {
            RELEASE(self);
            return nil;
        }
    }
    _flags.dataRetained = YES;
    
    return self;
}

/* This methd sets the name of an image, updating the global name dictionary
 * to point to the image (or removing an image from the dictionary if the
 * new name is nil).
 */
// 相应的操作, 都加了加锁的处理.
- (BOOL) setName: (NSString *)aName
{
    [imageLock lock];
    
    /* The name is already set... nothing to do.
     */
    if (aName == _name || [aName isEqual: _name] == YES)
    {
        [imageLock unlock];
        return YES;
    }
    
    /* If the new name is already in use by another image,
     * we must do nothing.
     */
    if (aName != nil && [nameImageCache objectForKey: aName] != nil)
    {
        [imageLock unlock];
        return NO;
    }
    
    /* If this image had another name, we remove it.
     */
    if (_name != nil)
    {
        /* We retain self in case removing from the dictionary releases us */
        IF_NO_GC([[self retain] autorelease]);
        [nameImageCache removeObjectForKey: _name];
        DESTROY(_name);
    }
    
    /* If the new name is null, there is nothing more to do.
     */
    if (aName == nil)
    {
        [imageLock unlock];
        return NO;
    }
    
    ASSIGN(_name, aName);
    
    // 缓存, imageNamed 的缓存, 是根据 name 来进行的缓存.
    [nameImageCache setObject: self forKey: _name];
    
    [imageLock unlock];
    return YES;
}

- (NSString *) name
{
    NSString	*name;
    
    [imageLock lock];
    name = [[_name retain] autorelease];
    [imageLock unlock];
    return name;
}

- (void) setSize: (NSSize)aSize
{
    _size = aSize;
    _flags.sizeWasExplicitlySet = YES;
}

// 如果, size 没有被设置, 那么就根据图片的内容返回相关的 size.
- (NSSize) size
{
    if (_size.width == 0)
    {
        NSImageRep *rep = [self bestRepresentationForDevice: nil];
        
        if (rep)
            _size = [rep size];
        else
            _size = NSZeroSize;
    }
    return _size;
}

- (BOOL) isFlipped
{
    return _flags.flipDraw;
}

- (void) setFlipped: (BOOL)flag
{
    _flags.flipDraw = flag;
}

// Choosing Which Image Representation to Use 
- (void) setUsesEPSOnResolutionMismatch: (BOOL)flag
{
    _flags.useEPSOnResolutionMismatch = flag;
}

- (BOOL) usesEPSOnResolutionMismatch
{
    return _flags.useEPSOnResolutionMismatch;
}

- (void) setPrefersColorMatch: (BOOL)flag
{
    _flags.colorMatchPreferred = flag;
}

- (BOOL) prefersColorMatch
{
    return _flags.colorMatchPreferred;
}

- (void) setMatchesOnMultipleResolution: (BOOL)flag
{
    _flags.multipleResolutionMatching = flag;
}

- (BOOL) matchesOnMultipleResolution
{
    return _flags.multipleResolutionMatching;
}

// Determining How the Image is Stored 
- (void) setCachedSeparately: (BOOL)flag
{
    _flags.cacheSeparately = flag;
}

- (BOOL) isCachedSeparately
{
    return _flags.cacheSeparately;
}

- (void) setDataRetained: (BOOL)flag
{
    _flags.dataRetained = flag;
}

- (BOOL) isDataRetained
{
    return _flags.dataRetained;
}

- (void) setCacheDepthMatchesImageDepth: (BOOL)flag
{
    _flags.unboundedCacheDepth = flag;
}

- (BOOL) cacheDepthMatchesImageDepth
{
    return _flags.unboundedCacheDepth;
}

- (void) setCacheMode: (NSImageCacheMode)mode
{
    _cacheMode = mode;
}

- (NSImageCacheMode) cacheMode
{
    return _cacheMode;
}


// Determining How the Image is Drawn
// A Boolean value that indicates whether it is possible to draw an image representation.
- (BOOL) isValid
{
    BOOL valid = NO;
    NSUInteger i, count;
    
    if (_flags.syncLoad)
    {
        /* Make sure any images that were added with _useFromFile: are loaded
         in and added to the representation list. */
        if (![self _loadFromFile: _fileName])
            return NO;
        _flags.syncLoad = NO;
    }
    
    /* Go through all our representations and determine if at least one
     is a valid cache */
    // FIXME: Not sure if this is correct
    count = [_reps count];
    for (i = 0; i < count; i++)
    {
        GSRepData *repd = (GSRepData*)[_reps objectAtIndex: i];
        
        if (repd->bg != nil || [repd->rep isKindOfClass: cachedClass] == NO)
        {
            valid = YES;
            break;
        }
    }
    
    return valid;
}

- (void) recache
{
    NSUInteger i;
    
    i = [_reps count];
    while (i--)
    {
        GSRepData *repd;
        
        repd = (GSRepData*)[_reps objectAtIndex: i];
        if (repd->original != nil)
        {
            [_reps removeObjectAtIndex: i];
        }
    }
}

- (BOOL) scalesWhenResized
{
    return _flags.scalable;
}

- (void) setBackgroundColor: (NSColor *)aColor
{
    if (aColor == nil)
    {
        aColor = clearColor;
    }
    ASSIGN(_color, aColor);
}

- (NSColor *) backgroundColor
{
    return _color;
}

// Using the Image 
- (void) compositeToPoint: (NSPoint)aPoint 
                operation: (NSCompositingOperation)op
{
    [self compositeToPoint: aPoint
                  fromRect: NSZeroRect
                 operation: op
                  fraction: 1.0];
}

- (void) compositeToPoint: (NSPoint)aPoint
                 fromRect: (NSRect)aRect
                operation: (NSCompositingOperation)op
{
    [self compositeToPoint: aPoint
                  fromRect: aRect
                 operation: op
                  fraction: 1.0];
}

- (void) compositeToPoint: (NSPoint)aPoint
                operation: (NSCompositingOperation)op
                 fraction: (CGFloat)delta
{
    [self compositeToPoint: aPoint
                  fromRect: NSZeroRect
                 operation: op
                  fraction: delta];
}

- (void) compositeToPoint: (NSPoint)aPoint
                 fromRect: (NSRect)srcRect
                operation: (NSCompositingOperation)op
                 fraction: (CGFloat)delta
{
    NSGraphicsContext *ctxt = GSCurrentContext();
    
    // Calculate the user space scale factor of the current window
    NSView *focusView = [NSView focusView];
    CGFloat scaleFactor = 1.0;
    if (focusView != nil)
    {
        scaleFactor = [[focusView window] userSpaceScaleFactor];
    }
    
    // Set the CTM to the identity matrix with the current translation
    // and the user space scale factor
    {
        NSAffineTransform *backup = [[ctxt GSCurrentCTM] retain];
        NSAffineTransform *newTransform = [NSAffineTransform transform];
        NSPoint translation = [backup transformPoint: aPoint];
        [newTransform translateXBy: translation.x
                               yBy: translation.y];
        [newTransform scaleBy: scaleFactor];
        
        [ctxt GSSetCTM: newTransform];
        
        [self drawAtPoint: NSMakePoint(0, 0)
                 fromRect: srcRect
                operation: op
                 fraction: delta];
        
        [ctxt GSSetCTM: backup];
        
        [backup release];
    }
}

- (void) dissolveToPoint: (NSPoint)aPoint fraction: (CGFloat)aFloat
{
    [self dissolveToPoint: aPoint
                 fromRect: NSZeroRect
                 fraction: aFloat];
}

- (void) dissolveToPoint: (NSPoint)aPoint
                fromRect: (NSRect)aRect
                fraction: (CGFloat)aFloat
{
    [self compositeToPoint: aPoint
                  fromRect: aRect
                 operation: NSCompositeSourceOver
                  fraction: aFloat];
}

- (BOOL) drawRepresentation: (NSImageRep *)imageRep inRect: (NSRect)aRect
{
    BOOL r;
    NSGraphicsContext *ctxt = GSCurrentContext();
    
    DPSgsave(ctxt);
    
    if (_color != nil)
    {
        NSRect fillrect = aRect;
        
        [_color set];
        NSRectFill(fillrect);
        
        if ([GSCurrentContext() isDrawingToScreen] == NO)
        {
            /* Reset alpha for image drawing. */
            [[NSColor colorWithCalibratedWhite: 1.0 alpha: 1.0] set];
        }
    }
    
    if (!_flags.scalable)
        r = [imageRep drawAtPoint: aRect.origin];
    else
        r = [imageRep drawInRect: aRect];
    
    DPSgrestore(ctxt);
    
    return r;
}

- (void) drawAtPoint: (NSPoint)point
            fromRect: (NSRect)srcRect
           operation: (NSCompositingOperation)op
            fraction: (CGFloat)delta
{
    [self drawInRect: NSMakeRect(point.x, point.y, srcRect.size.width, srcRect.size.height)
            fromRect: srcRect
           operation: op
            fraction: delta
      respectFlipped: NO
               hints: nil];
}

- (void) drawInRect: (NSRect)rect
{
    [self drawInRect: rect
            fromRect: NSZeroRect
           operation: NSCompositeSourceOver
            fraction: 1.0];
}

- (void) drawInRect: (NSRect)dstRect
           fromRect: (NSRect)srcRect
          operation: (NSCompositingOperation)op
           fraction: (CGFloat)delta
{
    [self drawInRect: dstRect
            fromRect: srcRect
           operation: op
            fraction: delta
      respectFlipped: NO
               hints: nil];
}

/**
 * Base drawing method in NSImage; all other draw methods call this one
 * Image 的绘制方法.
 *
 */
- (void) drawInRect: (NSRect)dstRect // Negative width/height => Nothing draws.
           fromRect: (NSRect)srcRect
          operation: (NSCompositingOperation)op
           fraction: (CGFloat)delta
     respectFlipped: (BOOL)respectFlipped
              hints: (NSDictionary*)hints
{
    NSImageRep *rep;
    NSGraphicsContext *ctxt;
    NSSize imgSize, repSize;
    NSRect repSrcRect;
    
    ctxt = GSCurrentContext();
    imgSize = [self size];
    
    // Handle abbreviated parameters
    
    if (NSEqualRects(srcRect, NSZeroRect))
    {
        srcRect.size = imgSize;
    }
    if (NSEqualSizes(dstRect.size, NSZeroSize)) // For -drawAtPoint:fromRect:operation:fraction:
    {
        dstRect.size = imgSize;
    }
    
    if (imgSize.width <= 0 || imgSize.height <= 0)
        return;
    
    // Select a rep
    
    rep = [self bestRepresentationForRect: dstRect
                                  context: ctxt
                                    hints: hints];
    if (rep == nil)
        return;
    
    // Try to cache / get a cached version of the best rep
    
    /**
     * We only use caching on backends that can efficiently draw a rect from the cache
     * onto the current graphics context respecting the CTM, which is currently cairo.
     */
    if (_cacheMode != NSImageCacheNever &&
        [ctxt supportsDrawGState])
    {
        NSCachedImageRep *cache = [self _doImageCache: rep];
        if (cache != nil)
        {
            rep = cache;
        }
    }
    
    repSize = [rep size];
    
    // Convert srcRect from image coordinate space to rep coordinate space
    {
        const CGFloat imgToRepWidthScaleFactor = repSize.width / imgSize.width;
        const CGFloat imgToRepHeightScaleFactor = repSize.height / imgSize.height;
        
        repSrcRect = NSMakeRect(srcRect.origin.x * imgToRepWidthScaleFactor,
                                srcRect.origin.y * imgToRepHeightScaleFactor,
                                srcRect.size.width * imgToRepWidthScaleFactor,
                                srcRect.size.height * imgToRepHeightScaleFactor);
    }
    
    // FIXME: Draw background?
    
    [rep drawInRect: dstRect
           fromRect: repSrcRect
          operation: op
           fraction: delta
     respectFlipped: respectFlipped
              hints: hints];
}

- (void) addRepresentation: (NSImageRep *)imageRep
{
    GSRepData *repd;
    
    if (imageRep != nil)
    {
        repd = [GSRepData new];
        repd->rep = RETAIN(imageRep);
        [_reps addObject: repd];
        RELEASE(repd);
    }
}

- (void) addRepresentations: (NSArray *)imageRepArray
{
    NSUInteger i, count;
    GSRepData *repd;
    
    count = [imageRepArray count];
    for (i = 0; i < count; i++)
    {
        repd = [GSRepData new];
        repd->rep = RETAIN([imageRepArray objectAtIndex: i]);
        [_reps addObject: repd];
        RELEASE(repd);
    }
}

- (void) removeRepresentation: (NSImageRep *)imageRep
{
    NSUInteger i;
    GSRepData *repd;
    
    i = [_reps count];
    while (i-- > 0)
    {
        repd = (GSRepData*)[_reps objectAtIndex: i];
        if (repd->rep == imageRep)
        {
            [_reps removeObjectAtIndex: i];
        }
        else if (repd->original == imageRep)
        {
            // Remove cached representations for this representation
            // instead of turning them into real ones
            //repd->original = nil;
            [_reps removeObjectAtIndex: i];
        }
    }
}

- (void) lockFocus
{
    [self lockFocusOnRepresentation: nil];
}

- (void) lockFocusOnRepresentation: (NSImageRep *)imageRep
{
    if (_cacheMode != NSImageCacheNever)
    {
        NSWindow *window;
        GSRepData *repd;
        
        if (NSEqualSizes(NSZeroSize, [self size]))
            [NSException raise: NSImageCacheException
                        format: @"Cannot lock focus on image with size (0, 0)"];
        
        if (imageRep == nil)
            imageRep = [self bestRepresentationForDevice: nil];
        
        repd = [self _cacheForRep: imageRep];
        if (repd == nil)
            return;
        
        imageRep = repd->rep;
        
        window = [(NSCachedImageRep *)imageRep window];
        _lockedView = [window contentView];
        if (_lockedView == nil)
        {
            [NSException raise: NSImageCacheException
                        format: @"Cannot lock focus on nil rep"];
        }
        
        // FIXME: This is needed to get image caching working while printing. A better solution
        // needs to remove the viewIsPrinting variable from NSView.
        [_lockedView _lockFocusInContext: [window graphicsContext] inRect: [_lockedView bounds]];
        if (repd->bg == nil)
        {
            NSRect fillrect = NSMakeRect(0, 0, _size.width, _size.height);
            
            // Clear the background of the cached image, as it is not valid
            if ([_color alphaComponent] < 1.0)
            {
                /* With a Quartz-like alpha model, alpha can't be cleared
                 with a rectfill, so we need to clear the alpha channel
                 explictly. (A compositerect with NSCompositeCopy would
                 be more efficient, but it doesn't seem like it's
                 implemented correctly in all backends yet (as of
                 2002-08-23). Also, this will work with both the Quartz-
                 and DPS-model.) */
                NSRectFillUsingOperation(fillrect, NSCompositeClear);
            }
            
            repd->bg = [_color copy];
            
            if ([repd->bg alphaComponent] == 1.0)
            {
                [imageRep setOpaque: YES];
            }
            else
            {
                [imageRep setOpaque: [repd->original isOpaque]];
            }
            
            // Fill with background colour and draw repesentation
            [self drawRepresentation: repd->original
                              inRect: fillrect];
        }
    }
}

- (void) unlockFocus
{
    if (_lockedView != nil)
    {
        [_lockedView unlockFocus];
        _lockedView = nil;
    }
}

/* Determine the number of color components in the device and
 filter out reps with a different number of color components.
 
 If the device lacks a color space name, all reps are treated
 as matching.
 
 If a rep lacks a color space name, it is assumed to match the
 device.
 
 WARNING: Be careful not to inadvertently mix greyscale and color
 representations in a TIFF. The greyscale representations
 will never be selected as a best rep unless you are drawing on
 a greyscale surface, or all reps in the TIFF are greyscale.
 */
- (NSMutableArray *) _bestRep: (NSArray *)reps 
               withColorMatch: (NSDictionary*)deviceDescription
{
    NSMutableArray *breps = [NSMutableArray array];
    NSString *deviceColorSpace = [deviceDescription objectForKey: NSDeviceColorSpaceName];
    
    if (deviceColorSpace != nil)
    {
        NSUInteger deviceColors = NSNumberOfColorComponents(deviceColorSpace);
        NSEnumerator *enumerator = [reps objectEnumerator];
        NSImageRep *rep;
        while ((rep = [enumerator nextObject]) != nil)
        {
            if ([rep colorSpaceName] == nil ||
                NSNumberOfColorComponents([rep colorSpaceName]) == deviceColors)
            {
                [breps addObject: rep];
            }
        }
    }
    
    /* If there are no matches, pass all the reps */
    if ([breps count] == 0)
    {
        [breps setArray: reps];
    }
    
    return breps;
}

/**
 * Returns YES if x in an integer multiple of y
 */
static BOOL GSIsMultiple(CGFloat x, CGFloat y)
{
    // FIXME: Test when CGFloat is float and make sure this test isn't
    // too strict due to floating point rounding errors.
    return (x/y) == floor(x/y);
}

/**
 * Returns YES if there exist integers p and q such that
 * (baseSize.width * p == size.width) && (baseSize.height * q == size.height)
 */
static BOOL GSSizeIsIntegerMultipleOfSize(NSSize size, NSSize baseSize)
{
    return NSEqualSizes(size, baseSize) ||
    (GSIsMultiple(size.width, baseSize.width) &&
     GSIsMultiple(size.height, baseSize.height));
}

/**
 * Returns {0, 0} if the image rep doesn't have a size set,
 * or the pixelsWide or pixelsHigh are NSImageRepMatchesDevice
 */
static NSSize GSResolutionOfImageRep(NSImageRep *rep)
{
    const int pixelsWide = [rep pixelsWide];
    const int pixelsHigh = [rep pixelsHigh];
    const NSSize repSize = [rep size];
    
    if (repSize.width == 0 || repSize.height == 0)
    {
        return NSMakeSize(0, 0);
    }
    else if (pixelsWide == NSImageRepMatchesDevice ||
             pixelsHigh == NSImageRepMatchesDevice)
    {
        return NSMakeSize(0, 0);
    }
    else
    {
        return NSMakeSize(72.0 * (CGFloat)pixelsWide / repSize.width,
                          72.0 * (CGFloat)pixelsHigh / repSize.height);
    }
}

/* Find reps that match the resolution (DPI) of the device (including integer
 multiples of the device resplition if [self multipleResolutionMatching]
 is YES).
 
 If there are no DPI matches, use any available vector reps if
 [self usesEPSOnResolutionMismatch] is YES. Otherwise, use the bitmap reps
 that have the highest DPI.
 */
- (NSMutableArray *) _bestRep: (NSArray *)reps 
          withResolutionMatch: (NSDictionary*)deviceDescription
{
    NSMutableArray *breps = [NSMutableArray array];
    
    NSValue *resolution = [deviceDescription objectForKey: NSDeviceResolution];
    
    // 1. Look for exact resolution matches, or integer multiples if permitted.
    
    if (nil != resolution)
    {
        const NSSize dres = [resolution sizeValue];
        
        if (![self matchesOnMultipleResolution])
        {
            NSImageRep *rep;
            NSEnumerator *enumerator = [reps objectEnumerator];
            
            while ((rep = [enumerator nextObject]) != nil)
            {
                if (NSEqualSizes(GSResolutionOfImageRep(rep), dres))
                {
                    [breps addObject: rep];
                }
            }
        }
        else // [self matchesOnMultipleResolution]
        {
            NSMutableArray *integerMultiples = [NSMutableArray array];
            NSSize closestRes = NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX);
            NSImageRep *rep;
            NSEnumerator *enumerator;
            
            // Iterate through the reps, keeping track of which ones
            // have a resolution which is an integer multiple of the device
            // res, and keep track of the cloest resolution
            
            enumerator = [reps objectEnumerator];
            while ((rep = [enumerator nextObject]) != nil)
            {
                const NSSize repRes = GSResolutionOfImageRep(rep);
                if (GSSizeIsIntegerMultipleOfSize(repRes, dres))
                {
                    const NSSize repResDifference
                    = NSMakeSize(fabs(repRes.width - dres.width),
                                 fabs(repRes.height - dres.height));
                    const NSSize closestResolutionDifference
                    = NSMakeSize(fabs(closestRes.width - dres.width),
                                 fabs(closestRes.height - dres.height));
                    if (repResDifference.width
                        < closestResolutionDifference.width
                        && repResDifference.height
                        < closestResolutionDifference.height)
                    {
                        closestRes = repRes;
                    }
                    [integerMultiples addObject: rep];
                }
            }
            
            enumerator = [integerMultiples objectEnumerator];
            while ((rep = [enumerator nextObject]) != nil)
            {
                const NSSize repRes = GSResolutionOfImageRep(rep);
                if (NSEqualSizes(repRes, closestRes))
                {
                    [breps addObject: rep];
                }
            }
        }
    }
    
    // 2. If no exact matches found, use vector reps, if they are preferred
    
    if ([breps count] == 0 && [self usesEPSOnResolutionMismatch])
    {
        NSImageRep *rep;
        NSEnumerator *enumerator = [reps objectEnumerator];
        while ((rep = [enumerator nextObject]) != nil)
        {
            if ([rep pixelsWide] == NSImageRepMatchesDevice &&
                [rep pixelsHigh] == NSImageRepMatchesDevice)
            {
                [breps addObject: rep];
            }
        }
    }
    
    // 3. If there are still no matches, use all of the bitmaps with the highest
    // resolution (DPI)
    
    if ([breps count] == 0)
    {
        NSSize maxRes = NSMakeSize(0,0);
        NSImageRep *rep;
        NSEnumerator *enumerator;
        
        // Determine maxRes
        
        enumerator = [reps objectEnumerator];
        while ((rep = [enumerator nextObject]) != nil)
        {
            const NSSize res = GSResolutionOfImageRep(rep);
            if (res.width > maxRes.width &&
                res.height > maxRes.height)
            {
                maxRes = res;
            }
        }
        
        // Use all reps with maxRes
        enumerator = [reps objectEnumerator];
        while ((rep = [enumerator nextObject]) != nil)
        {
            const NSSize res = GSResolutionOfImageRep(rep);
            if (NSEqualSizes(res, maxRes))
            {
                [breps addObject: rep];
            }
        }
    }
    
    // 4. If there are still none, use all available reps.
    // Note that this handles using vector reps in the case where there are
    // no bitmap reps, but [self usesEPSOnResolutionMismatch] is NO.
    
    if ([breps count] == 0)
    {
        [breps setArray: reps];
    }
    
    return breps;
}

/* Find the reps that match the bitsPerSample of the device,
 or if none match exactly, return all that have the highest bitsPerSample.
 
 If the device lacks a bps, all reps are treated as matching.
 
 If a rep has NSImageRepMatchesDevice as its bps, it is treated as matching.
 */
- (NSMutableArray *) _bestRep: (NSArray *)reps 
                 withBpsMatch: (NSDictionary*)deviceDescription
{
    NSMutableArray *breps = [NSMutableArray array];
    NSNumber *bpsValue = [deviceDescription objectForKey: NSDeviceBitsPerSample];
    
    if (bpsValue != nil)
    {
        NSInteger deviceBps = [bpsValue integerValue];
        NSInteger maxBps = -1;
        BOOL haveDeviceBps = NO;
        NSImageRep *rep;
        NSEnumerator *enumerator;
        
        // Determine maxBps
        
        enumerator = [reps objectEnumerator];
        while ((rep = [enumerator nextObject]) != nil)
        {
            if ([rep bitsPerSample] > maxBps)
            {
                maxBps = [rep bitsPerSample];
            }
            if ([rep bitsPerSample] == deviceBps)
            {
                haveDeviceBps = YES;
            }
        }
        
        // Use all reps with deviceBps if haveDeviceBps is YES,
        // otherwise use all reps with maxBps
        enumerator = [reps objectEnumerator];
        while ((rep = [enumerator nextObject]) != nil)
        {
            if ([rep bitsPerSample] == NSImageRepMatchesDevice ||
                (!haveDeviceBps && [rep bitsPerSample] == maxBps) ||
                (haveDeviceBps && [rep bitsPerSample] == deviceBps))
            {
                [breps addObject: rep];
            }
        }
    }
    
    /* If there are no matches, pass all the reps */
    if ([breps count] == 0)
    {
        [breps setArray: reps];
    }
    
    return breps;
}

- (NSMutableArray *) _representationsWithCachedImages: (BOOL)flag
{
    NSUInteger count;
    
    if (_flags.syncLoad)
    {
        /* Make sure any images that were added with _useFromFile: are loaded
         in and added to the representation list. */
        [self _loadFromFile: _fileName];
        _flags.syncLoad = NO;
    }
    
    count = [_reps count];
    if (count == 0)
    {
        return [NSMutableArray array];
    }
    else
    {
        id repList[count];
        NSUInteger i, j;
        
        [_reps getObjects: repList];
        j = 0;
        for (i = 0; i < count; i++)
        {
            if (flag || ((GSRepData*)repList[i])->original == nil)
            {
                repList[j] = ((GSRepData*)repList[i])->rep;
                j++;
            }
        }
        return [NSMutableArray arrayWithObjects: repList count: j];
    }
}

- (NSArray *) _bestRepresentationsForDevice: (NSDictionary*)deviceDescription
{
    NSMutableArray *reps = [self _representationsWithCachedImages: NO];
    
    if (deviceDescription == nil)
    {
        if ([GSCurrentContext() isDrawingToScreen] == YES)
        {
            // Take the device description from the current context.
            deviceDescription = [[[GSCurrentContext() attributes] objectForKey:
                                  NSGraphicsContextDestinationAttributeName]
                                 deviceDescription];
        }
        else if ([NSPrintOperation currentOperation])
        {
            /* FIXME: We could try to use the current printer,
             but there are many cases where might
             not be printing (EPS, PDF, etc) to a specific device */
        }
    }
    
    if (_flags.colorMatchPreferred == YES)
    {
        reps = [self _bestRep: reps withColorMatch: deviceDescription];
        reps = [self _bestRep: reps withResolutionMatch: deviceDescription];
    }
    else
    {
        reps = [self _bestRep: reps withResolutionMatch: deviceDescription];
        reps = [self _bestRep: reps withColorMatch: deviceDescription];
    }
    reps = [self _bestRep: reps withBpsMatch: deviceDescription];
    
    return reps;
}

- (NSImageRep *) bestRepresentationForDevice: (NSDictionary*)deviceDescription
{
    NSArray *reps = [self _bestRepresentationsForDevice: deviceDescription];
    
    /* If we have more than one match check for a representation whose size
     * matches the image size exactly. Otherwise, arbitrarily choose the first
     * representation. */
    if ([reps count] > 1)
    {
        NSImageRep *rep;
        NSEnumerator *enumerator = [reps objectEnumerator];
        
        while ((rep = [enumerator nextObject]) != nil)
        {
            if (NSEqualSizes(_size, [rep size]) == YES)
            {
                return rep;
            }
        }
    }
    
    
    if ([reps count] > 0)
    {
        return [reps objectAtIndex: 0];
    }
    else
    {
        return nil;
    }
}

- (NSImageRep *) bestRepresentationForRect: (NSRect)rect
                                   context: (NSGraphicsContext *)context
                                     hints: (NSDictionary *)deviceDescription
{
    NSArray *reps = [self _bestRepresentationsForDevice: deviceDescription];
    const NSSize desiredSize = rect.size;
    NSImageRep *bestRep = nil;
    
    // Pick the smallest rep that is greater than or equal to the
    // desired size.
    
    {
        NSSize bestSize = NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX);
        NSImageRep *rep;
        NSEnumerator *enumerator = [reps objectEnumerator];
        while ((rep = [enumerator nextObject]) != nil)
        {
            const NSSize repSize = [rep size];
            if ((repSize.width >= desiredSize.width)
                && (repSize.height >= desiredSize.height)
                && (repSize.width < bestSize.width)
                && (repSize.height < bestSize.height))
            {
                bestSize = repSize;
                bestRep = rep;
            }
        }
    }
    
    if (bestRep == nil)
    {
        bestRep = [reps lastObject];
    }
    
    return bestRep;
}

- (NSArray *) representations
{
    return [self _representationsWithCachedImages: YES];
}

// Producing TIFF Data for the Image 
- (NSData *) TIFFRepresentation
{
    NSArray       *reps;
    NSData        *data;
    
    /* As a result of using bitmap representations,
     * new drawing wont show on the tiff data.
     */
    reps = [self _representationsWithCachedImages: NO];
    data = [bitmapClass TIFFRepresentationOfImageRepsInArray: reps];
    
    if (!data)
    {
        NSBitmapImageRep *rep;
        NSSize size = [self size];
        
        // If there isn't a bitmap representation to output, create one and store it.
        [self lockFocus];
        rep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:
               NSMakeRect(0.0, 0.0, size.width, size.height)];
        [self unlockFocus];
        if (nil != rep)
        {
            [self addRepresentation: rep];
            data = [rep TIFFRepresentation];
            RELEASE(rep);
        }
    }
    
    return data;
}

- (NSData *) TIFFRepresentationUsingCompression: (NSTIFFCompression)comp
                                         factor: (float)aFloat
{
    NSArray       *reps;
    NSData        *data;
    
    /* As a result of using bitmap representations,
     * new drawing wont show on the tiff data.
     */
    reps = [self _representationsWithCachedImages: NO];
    data = [bitmapClass TIFFRepresentationOfImageRepsInArray: reps
                                            usingCompression: comp
                                                      factor: aFloat];
    
    if (!data)
    {
        NSBitmapImageRep *rep;
        NSSize size = [self size];
        
        /* If there isn't a bitmap representation to output,
         * create one and store it.
         */
        [self lockFocus];
        rep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:
               NSMakeRect(0.0, 0.0, size.width, size.height)];
        [self unlockFocus];
        if (nil != rep)
        {
            [self addRepresentation: rep];
            data = [rep TIFFRepresentationUsingCompression: comp factor: aFloat];
            RELEASE(rep);
        }
    }
    
    return data;
}

+ (BOOL) canInitWithPasteboard: (NSPasteboard *)pasteboard
{
    int i, count;
    NSArray* array = [NSImageRep registeredImageRepClasses];
    
    count = [array count];
    for (i = 0; i < count; i++)
        if ([[array objectAtIndex: i] canInitWithPasteboard: pasteboard])
            return YES;
    
    return NO;
}

+ (NSArray *) imageUnfilteredFileTypes
{
    if (nil == imageUnfilteredFileTypes)
    {
        ASSIGN(imageUnfilteredFileTypes,
               iterate_reps_for_types([NSImageRep registeredImageRepClasses],
                                      @selector(imageUnfilteredFileTypes)));
    }
    return imageUnfilteredFileTypes;
}

+ (NSArray *) imageFileTypes
{
    if (nil == imageFileTypes)
    {
        ASSIGN(imageFileTypes,
               iterate_reps_for_types([NSImageRep registeredImageRepClasses],
                                      @selector(imageFileTypes)));
    }
    return imageFileTypes;
}

+ (NSArray *) imageUnfilteredPasteboardTypes
{
    if (nil == imageUnfilteredPasteboardTypes)
    {
        ASSIGN(imageUnfilteredPasteboardTypes,
               iterate_reps_for_types([NSImageRep registeredImageRepClasses],
                                      @selector(imageUnfilteredPasteboardTypes)));
    }
    return imageUnfilteredPasteboardTypes;
}

+ (NSArray *) imagePasteboardTypes
{
    if (nil == imagePasteboardTypes)
    {
        ASSIGN(imagePasteboardTypes,
               iterate_reps_for_types([NSImageRep registeredImageRepClasses],
                                      @selector(imagePasteboardTypes)));
    }
    return imagePasteboardTypes;
}

@end

/* For every image rep, call the specified method to obtain an
 array of objects.  Add these together, with duplicates
 weeded out.  Used by imageUnfilteredPasteboardTypes,
 imageUnfilteredFileTypes, etc. */
static NSArray *
iterate_reps_for_types(NSArray* imageReps, SEL method)
{
    NSImageRep *rep;
    NSEnumerator *e;
    NSMutableArray *types;
    
    types = [NSMutableArray arrayWithCapacity: 2];
    
    // Iterate through all the image reps
    e = [imageReps objectEnumerator];
    rep = [e nextObject];
    while (rep)
    {
        id e1;
        id obj;
        NSArray* pb_list;
        
        // Have the image rep perform the operation
        pb_list = [rep performSelector: method];
        
        // Iterate through the returned array
        // and add elements to types list, duplicates weeded.
        e1 = [pb_list objectEnumerator];
        obj = [e1 nextObject];
        while (obj)
        {
            if ([types indexOfObject: obj] == NSNotFound)
                [types addObject: obj];
            obj = [e1 nextObject];
        }
        
        rep = [e nextObject];
    }
    
    return (NSArray *)types;
}

@implementation NSImage (Private)

+ (void) _clearFileTypeCaches: (NSNotification*)notif
{
    DESTROY(imageUnfilteredFileTypes);
    DESTROY(imageFileTypes);
    DESTROY(imageUnfilteredPasteboardTypes);
    DESTROY(imagePasteboardTypes);
}

/**
 * For all NSImage instances cached in nameDict, recompute the
 * path using +_pathForImageNamed: and if it has changed,
 * reload the image contents using the new path.
 */
+ (void) _reloadCachedImages
{
    NSString *name;
    NSEnumerator *e = [nameImageCache keyEnumerator];
    
    [imageLock lock];
    while ((name = [e nextObject]) != nil)
    {
        NSImage *image = [nameImageCache objectForKey: name];
        NSString *path = [[NSBundle mainBundle] pathForImageResource: name];
        
        //NSLog(@"Loaded image %@ from %@", name, path);
        
        if (path != nil && ![path isEqual: image->_fileName])
        {
            /* Reset the existing image to use the contents of
             * the specified file.
             */
            [image _resetAndUseFromFile: path];
        }
    }
    [imageLock unlock];
}

// 根据二进制值, 生成 ImageRep
- (BOOL) _loadFromData: (NSData *)data
{
    BOOL ok;
    Class rep;
    
    ok = NO;
    rep = [NSImageRep imageRepClassForData: data];
    if (rep && [rep respondsToSelector: @selector(imageRepsWithData:)])
    {
        NSArray* array;
        
        array = [rep imageRepsWithData: data];
        if (array && ([array count] > 0))
            ok = YES;
        [self addRepresentations: array];
    }
    else if (rep)
    {
        NSImageRep* image;
        
        image = [rep imageRepWithData: data];
        if (image)
            ok = YES;
        [self addRepresentation: image];
    }
    return ok;
}

// 根据file的路径, 生成 ImageRep
- (BOOL) _loadFromFile: (NSString *)fileName
{
    NSArray *array;
    
    array = [NSImageRep imageRepsWithContentsOfFile: fileName];
    if (array)
        [self addRepresentations: array];
    
    return (array && ([array count] > 0)) ? YES : NO;
}

- (BOOL) _useFromFile: (NSString *)fileName
{
    NSArray *array;
    NSString *ext;
    NSFileManager *manager = [NSFileManager defaultManager];
    
    if ([manager fileExistsAtPath: fileName] == NO)
    {
        return NO;
    }
    
    ext = [[fileName pathExtension] lowercaseString]; // 这里, bundle 里面的进行了后缀的验证.
    if (!ext)
        return NO;
    array = [object_getClass(self) imageFileTypes]; // 验证目前支持的图片类型, 和后缀进行了验证.
    if ([array indexOfObject: ext] == NSNotFound)
        return NO;
    // 所以, 这里通过 fileName 进行读取的操作, 不会真正进行读取, 而是进行 filePath 的设置. 真正的图片在什么时候进行读取呢, 应该是在绘制的时候. 也就是真正的在进行展示的时候.
    ASSIGN(_fileName, fileName);
    _flags.syncLoad = YES;
    return YES;
}

- (BOOL) _resetAndUseFromFile: (NSString *)fileName
{
    [_reps removeAllObjects];
    
    if (!_flags.sizeWasExplicitlySet)
    {
        _size = NSZeroSize;
    }
    return [self _useFromFile: fileName];
}

// Cache the bestRepresentation.  If the bestRepresentation is not itself
// a cache and no cache exists, create one and draw the representation in it
// If a cache exists, but is not valid, redraw the cache from the original
// image (if there is one).
- (NSCachedImageRep *) _doImageCache: (NSImageRep *)rep
{
    GSRepData *repd;
    NSCachedImageRep *cache;
    
    repd = [self _cacheForRep: rep];
    if (repd == nil)
        return nil;
    
    cache = (NSCachedImageRep*)(repd->rep);
    if ([cache isKindOfClass: cachedClass] == NO)
        return nil;
    
    NSDebugLLog(@"NSImage", @"Cached image rep is %p", cache);
    /*
     * if the cache is not valid, it's background color will not exist
     * and we must draw the background then render from the original
     * image rep into the cache.
     */
    if (repd->bg == nil)
    {
        [self lockFocusOnRepresentation: cache];
        [self unlockFocus];
        
        NSDebugLLog(@"NSImage", @"Rendered rep %p on background %@",
                    cache, repd->bg);
    }
    
    return cache;
}

- (GSRepData*) _cacheForRep: (NSImageRep*)rep
{
    if ([rep isKindOfClass: cachedClass] == YES)
    {
        return repd_for_rep(_reps, rep);
    }
    else
    {
        /*
         * If this is not a cached image rep - try to find the cache rep
         * for this image rep. If none is found create a cache to be used to
         * render the image rep into, and switch to the cached rep.
         */
        NSUInteger count = [_reps count];
        
        if (count > 0)
        {
            GSRepData *invalidCache = nil;
            GSRepData *partialCache = nil;
            GSRepData *reps[count];
            NSUInteger partialCount = 0;
            NSUInteger i;
            BOOL opaque = [rep isOpaque];
            
            [_reps getObjects: reps];
            
            /*
             * Search the cached image reps for any whose original is our
             * 'best' image rep.  See if we can notice any invalidated
             * cache as we go - if we don't find a valid cache, we want to
             * re-use an invalidated one rather than creating a new one.
             * NB. If the image rep is opaque, then any cached rep is valid
             * irrespective of the background color it was drawn with.
             */
            for (i = 0; i < count; i++)
            {
                GSRepData *repd = reps[i];
                
                if (repd->original == rep && repd->rep != nil)
                {
                    if (repd->bg == nil)
                    {
                        NSDebugLLog(@"NSImage", @"Invalid %@ ... %@ %@",
                                    repd->bg, _color, repd->rep);
                        invalidCache = repd;
                    }
                    else if (opaque == YES || [repd->bg isEqual: _color] == YES)
                    {
                        NSDebugLLog(@"NSImage", @"Exact %@ ... %@ %@",
                                    repd->bg, _color, repd->rep);
                        return repd;
                    }
                    else
                    {
                        NSDebugLLog(@"NSImage", @"Partial %@ ... %@ %@",
                                    repd->bg, _color, repd->rep);
                        partialCache = repd;
                        partialCount++;
                    }
                }
            }
            
            if (invalidCache != nil)
            {
                /*
                 * If there is an unused cache - use it rather than
                 * re-using this one, since we might get a request
                 * to draw with this color again.
                 */
                return invalidCache;
            }
            else if (partialCache != nil && partialCount > 2)
            {
                /*
                 * Only re-use partially correct caches if there are already
                 * a few partial matches - otherwise we fall default to
                 * creating a new cache.
                 */
                if (NSImageForceCaching == NO && opaque == NO)
                {
                    DESTROY(partialCache->bg);
                }
                return partialCache;
            }
        }
        
        // We end here, when no representation are there or no match is found.
        {
            NSImageRep *cacheRep = nil;
            GSRepData *repd;
            NSSize imageSize = [self size];
            NSSize repSize;
            NSInteger pixelsWide, pixelsHigh;
            
            if (rep != nil)
            {
                repSize = [rep size];
                
                if (repSize.width <= 0 || repSize.height <= 0)
                    repSize = imageSize;
                
                pixelsWide = [rep pixelsWide];
                pixelsHigh = [rep pixelsHigh];
                
                if (pixelsWide == NSImageRepMatchesDevice ||
                    pixelsHigh == NSImageRepMatchesDevice)
                {
                    /* FIXME: Since the cached rep must be a bitmap,
                     * we must rasterize vector reps at a particular DPI.
                     * Here we hardcode 72, but we should choose the DPI
                     * more intelligently.
                     */
                    pixelsWide = repSize.width;
                    pixelsHigh = repSize.height;
                }
            }
            else // e.g. when there are no representations at all
            {
                repSize = imageSize;
                /* FIXME: assumes 72 DPI. Also truncates,
                 * not sure if that is a problem.
                 */
                pixelsWide = imageSize.width;
                pixelsHigh = imageSize.height;
            }
            
            if (repSize.width <= 0 || repSize.height <= 0 ||
                pixelsWide <= 0 || pixelsHigh <= 0)
                return nil;
            
            // Create a new cached image rep without any contents.
            cacheRep = [[cachedClass alloc]
                        initWithSize: repSize
                        pixelsWide: pixelsWide
                        pixelsHigh: pixelsHigh
                        depth: [[NSScreen mainScreen] depth]
                        separate: _flags.cacheSeparately
                        alpha: [rep hasAlpha]];
            if (cacheRep == nil)
            {
                return nil;
            }
            
            repd = [GSRepData new];
            repd->rep = cacheRep;
            repd->original = rep; // may be nil!
            [_reps addObject: repd];
            RELEASE(repd); /* Retained in _reps array. */
            
            return repd;
        }
    }
}

@end
