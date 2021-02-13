#import <Foundation/Foundation.h>

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#endif

#if TARGET_OS_OSX
#import <AppKit/AppKit.h>
#endif

//! Project version number for EGOCache.
FOUNDATION_EXPORT double EGOCacheVersionNumber;

//! Project version string for EGOCache.
FOUNDATION_EXPORT const unsigned char EGOCacheVersionString[];

#if !__has_feature(nullability)
#	define nullable
#	define nonnull
#	define __nullable
#	define __nonnull
#endif

@interface EGOCache : NSObject

// Global cache for easy use
+ (nonnull instancetype)globalCache;

// Opitionally create a different EGOCache instance with it's own cache directory
- (nonnull instancetype)initWithCacheDirectory:(NSString* __nonnull)cacheDirectory;

- (void)clearCache;
- (void)removeCacheForKey:(NSString* __nonnull)key;

- (BOOL)hasCacheForKey:(NSString* __nonnull)key;

- (NSData* __nullable)dataForKey:(NSString* __nonnull)key;
- (void)setData:(NSData* __nonnull)data forKey:(NSString* __nonnull)key;
- (void)setData:(NSData* __nonnull)data forKey:(NSString* __nonnull)key withTimeoutInterval:(NSTimeInterval)timeoutInterval;

- (NSString* __nullable)stringForKey:(NSString* __nonnull)key;
- (void)setString:(NSString* __nonnull)aString forKey:(NSString* __nonnull)key;
- (void)setString:(NSString* __nonnull)aString forKey:(NSString* __nonnull)key withTimeoutInterval:(NSTimeInterval)timeoutInterval;

- (NSDate* __nullable)dateForKey:(NSString* __nonnull)key;
- (NSArray* __nonnull)allKeys;

#if TARGET_OS_IPHONE
- (UIImage* __nullable)imageForKey:(NSString* __nonnull)key;
- (void)setImage:(UIImage* __nonnull)anImage forKey:(NSString* __nonnull)key;
- (void)setImage:(UIImage* __nonnull)anImage forKey:(NSString* __nonnull)key withTimeoutInterval:(NSTimeInterval)timeoutInterval;
#else
- (NSImage* __nullable)imageForKey:(NSString* __nonnull)key;
- (void)setImage:(NSImage* __nonnull)anImage forKey:(NSString* __nonnull)key;
- (void)setImage:(NSImage* __nonnull)anImage forKey:(NSString* __nonnull)key withTimeoutInterval:(NSTimeInterval)timeoutInterval;
#endif

- (NSData* __nullable)plistForKey:(NSString* __nonnull)key;
- (void)setPlist:(nonnull id)plistObject forKey:(NSString* __nonnull)key;
- (void)setPlist:(nonnull id)plistObject forKey:(NSString* __nonnull)key withTimeoutInterval:(NSTimeInterval)timeoutInterval;

- (void)copyFilePath:(NSString* __nonnull)filePath asKey:(NSString* __nonnull)key;
- (void)copyFilePath:(NSString* __nonnull)filePath asKey:(NSString* __nonnull)key withTimeoutInterval:(NSTimeInterval)timeoutInterval;

- (nullable id<NSCoding>)objectForKey:(NSString* __nonnull)key;
- (void)setObject:(nonnull id<NSCoding>)anObject forKey:(NSString* __nonnull)key;
- (void)setObject:(nonnull id<NSCoding>)anObject forKey:(NSString* __nonnull)key withTimeoutInterval:(NSTimeInterval)timeoutInterval;

@property(nonatomic) NSTimeInterval defaultTimeoutInterval; // Default is 1 day
@end
